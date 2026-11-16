extends SceneTree
var checks:=0
var failures:=0
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var Client=load("res://release/update_client.gd")
    var offline=Client.new();root.add_child(offline)
    var result: Dictionary=await offline.check_for_updates()
    expect(result.ok and result.offline and offline.requests_started==0,"unconfigured updater enters offline mode without any network request")
    var supported:=false
    for property in offline.get_property_list():
        if property.name=="tls_options": supported=true
    expect(supported,"real HTTPS update test can trust a test-only local certificate")
    if supported:
        var folder: String=OS.get_environment("RELEASE_TRANSPORT_FIXTURES")
        expect(not folder.is_empty(),"real HTTPS fixture directory is provided")
        if not folder.is_empty():
            var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("fixture.json")))
            var cert:=X509Certificate.new();expect(cert.load(folder.path_join("tls.crt"))==OK,"local test certificate loads")
            var public_key:=CryptoKey.new();expect(public_key.load(folder.path_join("update_public.pem"),true)==OK,"test uses the actual release public key")
            var client=Client.new();client.feed_url=fixture.feed_url;client.public_key=public_key
            client.platform="windows";client.current_build=2026111601
            client.tls_options=TLSOptions.client(cert)
            root.add_child(client)
            result=await client.check_for_updates()
            if not result.ok: print("HTTPS_UPDATE_DIAGNOSTIC "+JSON.stringify(result))
            expect(result.ok and result.get("updated",false),"real HTTPS download completes and registers the signed update")
            expect(client.requests_started==2,"only manifest and content are requested")
            expect(FileAccess.file_exists("user://content_updates/v1/active.json"),"complete update is staged for next startup")
            expect(not FileAccess.file_exists("res://release_probe.gd"),"download never swaps live game code during the running session")
            var Policy=load("res://release/update_policy.gd")
            if result.ok: expect(Policy.file_matches(result.path,result.package),"downloaded package retains its signed length and hash")
            var again=Client.new();again.feed_url=fixture.feed_url;again.public_key=public_key
            again.platform="windows";again.current_build=2026111602;again.tls_options=TLSOptions.client(cert)
            root.add_child(again)
            var repeated: Dictionary=await again.check_for_updates()
            expect(not repeated.ok and again.requests_started==1,"already current build does not download content again")
    print("RELEASE TRANSPORT RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
