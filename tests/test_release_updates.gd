extends SceneTree
var checks:=0
var failures:=0
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func envelope(payload: Dictionary,key: CryptoKey) -> Dictionary:
    var raw:=JSON.stringify(payload)
    return {"payload":raw,"signature":Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256,raw.sha256_buffer(),key))}
func _initialize() -> void:
    var path: String="res://release/update_policy.gd"
    expect(FileAccess.file_exists(path),"release validates signed updates before activating content")
    if FileAccess.file_exists(path):
        var policy=load(path)
        var key:=Crypto.new().generate_rsa(2048)
        var other:=Crypto.new().generate_rsa(2048)
        var payload: Dictionary={"schema":1,"game":"primitive_wildfrontier","build":2026111602,"version":"0.23.1","engine":"4.7.2","launcher_api":1,"packages":{"windows":{"url":"https://updates.example.test/content.pck","bytes":4,"sha256":"a".repeat(64)}}}
        var signed: Dictionary=envelope(payload,key)
        expect(policy.validate(signed,key,"windows",2026111601,"4.7.2",1).ok,"authentic compatible newer package is accepted")
        expect(not policy.validate(signed,other,"windows",2026111601,"4.7.2",1).ok,"a different signing key is rejected")
        var tampered:=signed.duplicate(true);tampered.payload+=" "
        expect(not policy.validate(tampered,key,"windows",2026111601,"4.7.2",1).ok,"changing one signed byte is rejected")
        expect(not policy.validate(signed,key,"linux",2026111601,"4.7.2",1).ok,"another platform cannot use the Windows package")
        expect(not policy.validate(signed,key,"windows",2026111602,"4.7.2",1).ok,"the same build cannot be installed repeatedly")
        expect(not policy.validate(signed,key,"windows",2026111603,"4.7.2",1).ok,"rollback to an older build is rejected")
        expect(not policy.validate(signed,key,"windows",2026111601,"4.8.0",1).ok,"engine mismatch requires a full application update")
        expect(not policy.validate(signed,key,"windows",2026111601,"4.7.2",2).ok,"launcher API mismatch is rejected")
        for field in ["schema","game","build","engine","launcher_api"]:
            var invalid:=payload.duplicate(true);invalid.erase(field)
            expect(not policy.validate(envelope(invalid,key),key,"windows",2026111601,"4.7.2",1).ok,"missing "+field+" is rejected")
        for url in ["http://updates.example.test/p.pck","file:///private.pck","https://user:pass@host/p.pck","https://host/p.pck\nheader"]:
            var invalid:=payload.duplicate(true);invalid.packages.windows.url=url
            expect(not policy.validate(envelope(invalid,key),key,"windows",2026111601,"4.7.2",1).ok,"unsafe update URL is rejected")
        var folder: String="res://runtime/tests/update_policy_"+str(Time.get_ticks_usec())
        DirAccess.make_dir_recursive_absolute(folder)
        var temp: String=folder.path_join("download.part")
        var file:=FileAccess.open(temp,FileAccess.WRITE);file.store_string("PCK-fixture-content");file.close()
        var actual:=payload.duplicate(true)
        actual.packages.windows.bytes=FileAccess.get_file_as_bytes(temp).size()
        actual.packages.windows.sha256=FileAccess.get_sha256(temp)
        var authentic:=envelope(actual,key)
        expect(policy.file_matches(temp,actual.packages.windows),"complete download matches length and SHA-256")
        var mismatch: Dictionary=actual.packages.windows.duplicate();mismatch.bytes+=1
        expect(not policy.file_matches(temp,mismatch),"truncated download is rejected")
        mismatch=actual.packages.windows.duplicate();mismatch.sha256="0".repeat(64)
        expect(not policy.file_matches(temp,mismatch),"same-size altered content is rejected")
        var first: Dictionary=policy.commit_download(temp,authentic,key,folder,"windows",2026111601,"4.7.2",1)
        expect(first.ok and FileAccess.file_exists(folder.path_join("active.json")),"only verified complete content gets an active pointer")
        expect(policy.file_matches(first.path,actual.packages.windows),"registered immutable package remains intact")
        var pointer_before:=FileAccess.get_file_as_bytes(folder.path_join("active.json"))
        file=FileAccess.open(temp,FileAccess.WRITE);file.store_string("bad");file.close()
        expect(not policy.commit_download(temp,authentic,key,folder,"windows",2026111601,"4.7.2",1).ok,"partial replacement never becomes active")
        expect(FileAccess.get_file_as_bytes(folder.path_join("active.json"))==pointer_before,"interrupted/bad update preserves the previous active pointer")
        expect(not policy.valid_url("http://127.0.0.1:9999/manifest.json"),"release mode rejects non-HTTPS feeds")
        expect(policy.valid_url("http://127.0.0.1:9999/manifest.json",true),"test-only loopback transport can exercise real HTTP")
    print("RELEASE UPDATES RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
