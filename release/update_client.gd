extends Node
const Policy=preload("res://release/update_policy.gd")
var feed_url: String=""
var public_key: CryptoKey
var platform: String=""
var current_build: int=0
var engine_version: String="4.7.2"
var launcher_api: int=1
var cache_folder: String="user://content_updates/v1"
var allow_loopback_for_tests:=false
var tls_options: TLSOptions
var requests_started:=0
signal finished(result: Dictionary)

func check_for_updates() -> Dictionary:
    if feed_url.is_empty():
        var offline: Dictionary={"ok":true,"updated":false,"offline":true}
        finished.emit(offline);return offline
    if not Policy.valid_url(feed_url,allow_loopback_for_tests):
        var invalid: Dictionary=Policy.fail("更新地址无效")
        finished.emit(invalid);return invalid
    var http:=HTTPRequest.new();http.timeout=5;http.body_size_limit=65536
    if tls_options!=null: http.set_tls_options(tls_options)
    add_child(http);requests_started+=1
    var error: Error=http.request(feed_url,PackedStringArray(["Cache-Control: no-cache"]))
    if error!=OK:
        http.queue_free();var failed: Dictionary=Policy.fail("无法检查更新")
        finished.emit(failed);return failed
    var response: Array=await http.request_completed
    http.queue_free()
    if response[0]!=HTTPRequest.RESULT_SUCCESS or response[1]!=200:
        var failed: Dictionary=Policy.fail("更新服务暂不可用")
        failed.transport_result=int(response[0]);failed.http_status=int(response[1])
        finished.emit(failed);return failed
    var decoded: Variant=JSON.parse_string(response[3].get_string_from_utf8())
    if typeof(decoded)!=TYPE_DICTIONARY:
        var failed: Dictionary=Policy.fail("更新清单格式无效")
        finished.emit(failed);return failed
    var validated: Dictionary=Policy.validate(decoded,public_key,platform,current_build,engine_version,launcher_api,allow_loopback_for_tests)
    if not validated.ok:
        finished.emit(validated);return validated
    if DirAccess.make_dir_recursive_absolute(cache_folder)!=OK:
        var failed: Dictionary=Policy.fail("更新目录不可写")
        finished.emit(failed);return failed
    var temp: String=cache_folder.path_join("download.part")
    http=HTTPRequest.new();http.timeout=180
    if tls_options!=null: http.set_tls_options(tls_options)
    http.body_size_limit=int(validated.package.bytes)
    http.download_file=temp
    add_child(http);requests_started+=1
    error=http.request(str(validated.package.url))
    if error!=OK:
        http.queue_free();var failed: Dictionary=Policy.fail("无法下载更新")
        finished.emit(failed);return failed
    response=await http.request_completed
    http.queue_free()
    if response[0]!=HTTPRequest.RESULT_SUCCESS or response[1]!=200:
        var failed: Dictionary=Policy.fail("更新下载未完成，保留现有版本")
        finished.emit(failed);return failed
    var installed: Dictionary=Policy.commit_download(temp,decoded,public_key,cache_folder,platform,current_build,engine_version,launcher_api,allow_loopback_for_tests)
    installed.updated=bool(installed.ok)
    if installed.ok: print("CONTENT_UPDATE_READY next_boot_build=%d" % int(installed.payload.build))
    finished.emit(installed)
    return installed
