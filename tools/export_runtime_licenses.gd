extends SceneTree
func _initialize() -> void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1: quit(1);return
    var output:=FileAccess.open(args[0],FileAccess.WRITE)
    if output==null: quit(1);return
    output.store_string("Godot Engine\n\n"+Engine.get_license_text()+"\n\nThird-party copyright notices\n\n")
    output.store_string(JSON.stringify(Engine.get_copyright_info(),"  "))
    output.store_string("\n\nThird-party license texts\n\n")
    output.store_string(JSON.stringify(Engine.get_license_info(),"  "))
    output.close();print("Stored engine and third-party license notices");quit()
