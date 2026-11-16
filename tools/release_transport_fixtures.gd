extends SceneTree
func store(path: String,value: String) -> void:
    var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(value);file.close()
func _initialize() -> void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=3: quit(1);return
    var folder: String=args[0]
    DirAccess.make_dir_recursive_absolute(folder)
    var signing:=CryptoKey.new()
    if signing.load(args[2])!=OK: quit(1);return
    signing.save(folder.path_join("update_public.pem"),true)
    var tls_key:=Crypto.new().generate_rsa(2048)
    var cert:=Crypto.new().generate_self_signed_certificate(tls_key,"CN=127.0.0.1,O=Release Test,C=CN","20260101000000","20360101000000")
    tls_key.save(folder.path_join("tls.key"));cert.save(folder.path_join("tls.crt"))
    store(folder.path_join("probe.gd"),"extends \"res://src/main.gd\"\nfunc _ready() -> void:\n    super._ready()\n    print(\"CONTENT_PATCH_EXECUTED\")\n")
    store(folder.path_join("probe.tscn"),"[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://release_probe.gd\" id=\"1\"]\n\n[node name=\"PatchedGame\" type=\"Node2D\"]\nscript = ExtResource(\"1\")\n")
    store(folder.path_join("probe.remap"),"[remap]\npath=\"res://probe_main.tscn\"\n")
    var pack:=PCKPacker.new()
    var target: String=folder.path_join("probe.pck")
    if pack.pck_start(target)!=OK: quit(1);return
    pack.add_file("res://release_probe.gd",folder.path_join("probe.gd"))
    pack.add_file("res://probe_main.tscn",folder.path_join("probe.tscn"))
    pack.add_file("res://main.tscn.remap",folder.path_join("probe.remap"))
    if pack.flush()!=OK: quit(1);return
    var url: String="https://127.0.0.1:"+args[1]
    var package: Dictionary={"url":url+"/probe.pck","bytes":FileAccess.get_file_as_bytes(target).size(),"sha256":FileAccess.get_sha256(target)}
    var payload: Dictionary={"schema":1,"game":"primitive_wildfrontier","build":2026111602,"version":"0.23.1-test","engine":"4.7.2","launcher_api":1,"packages":{"windows":package,"linux":package,"android":package}}
    var raw:=JSON.stringify(payload)
    var signature:=Crypto.new().sign(HashingContext.HASH_SHA256,raw.sha256_buffer(),signing)
    store(folder.path_join("manifest.json"),JSON.stringify({"payload":raw,"signature":Marshalls.raw_to_base64(signature)}))
    store(folder.path_join("fixture.json"),JSON.stringify({"feed_url":url+"/manifest.json"}))
    print("Prepared isolated signed-update HTTPS fixtures")
    quit()
