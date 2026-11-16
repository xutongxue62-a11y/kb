extends SceneTree
func store(path: String,text: String) -> void:
    var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()
func _initialize() -> void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=2: quit(1);return
    var folder: String=args[0];DirAccess.make_dir_recursive_absolute(folder)
    var key:=CryptoKey.new()
    if key.load(args[1])!=OK: quit(1);return
    for name in ["A","B"]:
        var build: int=2026111602 if name=="A" else 2026111603
        var script: String=folder.path_join(name+".gd")
        var scene: String=folder.path_join(name+".tscn")
        var remap: String=folder.path_join(name+".remap")
        store(script,"extends Node2D\nvar game_ready: bool=false\nfunc _ready() -> void:\n    print(\"UNREADY_"+name+"_EXECUTED\")\n")
        store(scene,"[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://unready_"+name+".gd\" id=\"1\"]\n[node name=\"Unready\" type=\"Node2D\"]\nscript = ExtResource(\"1\")\n")
        store(remap,"[remap]\npath=\"res://unready_"+name+".tscn\"\n")
        var pack_path: String=folder.path_join(name+".pck")
        var pack:=PCKPacker.new();pack.pck_start(pack_path)
        pack.add_file("res://unready_"+name+".gd",script)
        pack.add_file("res://unready_"+name+".tscn",scene)
        pack.add_file("res://main.tscn.remap",remap)
        if pack.flush()!=OK: quit(1);return
        var package: Dictionary={"url":"https://updates.example.test/recovery/"+name+".pck","bytes":FileAccess.get_file_as_bytes(pack_path).size(),"sha256":FileAccess.get_sha256(pack_path)}
        var raw:=JSON.stringify({"schema":1,"game":"primitive_wildfrontier","build":build,"version":"0.23.1-recovery-test","engine":"4.7.2","launcher_api":1,"packages":{"windows":package}})
        var signature:=Crypto.new().sign(HashingContext.HASH_SHA256,raw.sha256_buffer(),key)
        store(folder.path_join(name+".json"),JSON.stringify({"payload":raw,"signature":Marshalls.raw_to_base64(signature)}))
    print("Prepared two validly signed but uninitialized game fixtures")
    quit()
