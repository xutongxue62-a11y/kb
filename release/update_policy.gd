extends RefCounted
const GAME: String="primitive_wildfrontier"
const MAX_PACKAGE_BYTES: int=512*1024*1024

static func fail(reason: String) -> Dictionary:
    return {"ok":false,"error":reason}
static func integer(value: Variant,minimum: int,maximum: int) -> bool:
    return (typeof(value)==TYPE_INT or typeof(value)==TYPE_FLOAT) and is_finite(float(value)) and value==floor(float(value)) and value>=minimum and value<=maximum
static func valid_url(url: String,allow_local: bool=false) -> bool:
    if url.length()>2048 or url.strip_edges()!=url or url.contains("\n") or url.contains("\r") or url.contains("\t"): return false
    if allow_local and (url.begins_with("http://127.0.0.1:") or url.begins_with("http://localhost:")): return true
    if not url.begins_with("https://"): return false
    var authority: String=url.trim_prefix("https://").get_slice("/",0)
    return not authority.is_empty() and not authority.contains("@") and not authority.contains(" ") and not authority.contains("\\")
static func validate(envelope: Dictionary,key: CryptoKey,platform: String,current_build: int,engine: String,api: int,allow_local: bool=false) -> Dictionary:
    if typeof(envelope.get("payload"))!=TYPE_STRING or typeof(envelope.get("signature"))!=TYPE_STRING: return fail("清单格式无效")
    var raw: String=envelope.payload
    if raw.to_utf8_buffer().size()>65536 or envelope.signature.length()>4096: return fail("清单过大")
    var signature: PackedByteArray=Marshalls.base64_to_raw(envelope.signature)
    if signature.size()!=256 or key==null or not Crypto.new().verify(HashingContext.HASH_SHA256,raw.sha256_buffer(),signature,key): return fail("清单签名校验失败")
    var parsed: Variant=JSON.parse_string(raw)
    if typeof(parsed)!=TYPE_DICTIONARY: return fail("清单内容无效")
    var payload: Dictionary=parsed
    if payload.get("schema")!=1 or payload.get("game")!=GAME: return fail("不适用的清单")
    if not integer(payload.get("build"),1,9007199254740991) or int(payload.build)<=current_build: return fail("没有更新的版本")
    if payload.get("engine")!=engine or payload.get("launcher_api")!=api: return fail("此更新需要升级程序本身")
    if typeof(payload.get("version"))!=TYPE_STRING or payload.version.is_empty() or payload.version.length()>48: return fail("版本信息无效")
    if typeof(payload.get("packages"))!=TYPE_DICTIONARY or typeof(payload.packages.get(platform))!=TYPE_DICTIONARY: return fail("此更新不适用于当前平台")
    var package: Dictionary=payload.packages[platform]
    if typeof(package.get("url"))!=TYPE_STRING or not valid_url(package.url,allow_local): return fail("更新地址无效")
    if not integer(package.get("bytes"),1,MAX_PACKAGE_BYTES): return fail("更新文件大小无效")
    if typeof(package.get("sha256"))!=TYPE_STRING: return fail("缺少更新校验值")
    var pattern:=RegEx.new();pattern.compile("^[0-9a-f]{64}$")
    if pattern.search(package.sha256)==null: return fail("更新校验值无效")
    return {"ok":true,"error":"","payload":payload,"package":package}
static func file_matches(path: String,package: Dictionary) -> bool:
    if not FileAccess.file_exists(path): return false
    var file:=FileAccess.open(path,FileAccess.READ)
    if file==null: return false
    var length: int=file.get_length();file.close()
    return length==int(package.get("bytes",-1)) and FileAccess.get_sha256(path)==str(package.get("sha256",""))
static func commit_download(temp: String,envelope: Dictionary,key: CryptoKey,folder: String,platform: String,current_build: int,engine: String,api: int,allow_local: bool=false) -> Dictionary:
    var result: Dictionary=validate(envelope,key,platform,current_build,engine,api,allow_local)
    if not result.ok: return result
    if not file_matches(temp,result.package): return fail("更新文件不完整或校验失败")
    if DirAccess.make_dir_recursive_absolute(folder)!=OK: return fail("无法创建更新目录")
    var target: String=folder.path_join(str(result.package.sha256)+".pck")
    if FileAccess.file_exists(target):
        if not file_matches(target,result.package):
            if DirAccess.rename_absolute(target,target+".invalid_"+str(Time.get_ticks_usec()))!=OK: return fail("无法修复旧缓存")
        else:
            if temp!=target and DirAccess.remove_absolute(temp)!=OK: return fail("无法清理下载临时文件")
    if not FileAccess.file_exists(target) and DirAccess.rename_absolute(temp,target)!=OK: return fail("无法保存更新文件")
    var active: String=folder.path_join("active.json")
    var previous: String=folder.path_join("previous.json")
    var next: String=folder.path_join("active.next")
    var output:=FileAccess.open(next,FileAccess.WRITE)
    if output==null: return fail("无法写入更新记录")
    output.store_string(JSON.stringify(envelope));output.flush()
    var error: Error=output.get_error();output.close()
    if error!=OK: return fail("更新记录未写完")
    var had_active: bool=FileAccess.file_exists(active)
    if had_active:
        if FileAccess.file_exists(previous) and DirAccess.remove_absolute(previous)!=OK: return fail("无法保存上一版本记录")
        if DirAccess.rename_absolute(active,previous)!=OK: return fail("无法备份当前版本记录")
    if DirAccess.rename_absolute(next,active)!=OK:
        if had_active: DirAccess.rename_absolute(previous,active)
        return fail("无法启用下次启动更新")
    result.path=target
    return result
