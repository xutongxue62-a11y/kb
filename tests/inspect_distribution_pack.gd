extends SceneTree
var paths: Array=[]
func scan(path: String) -> void:
    var directory:=DirAccess.open(path)
    if directory==null: return
    directory.include_hidden=true;directory.include_navigational=false
    directory.list_dir_begin()
    var name:=directory.get_next()
    while not name.is_empty():
        var full: String=path.path_join(name)
        if directory.current_is_dir(): scan(full)
        else: paths.append(full)
        name=directory.get_next()
    directory.list_dir_end()
func _initialize() -> void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1: quit(1);return
    scan("res://");paths.sort()
    var output:=FileAccess.open(args[0],FileAccess.WRITE)
    if output==null: quit(1);return
    output.store_string(JSON.stringify({"files":paths,"font_available":ResourceLoader.exists("res://assets/fonts/NotoSansSC-Variable.ttf"),"regions_available":FileAccess.file_exists("res://assets/regions.json"),"license_available":FileAccess.file_exists("res://assets/licenses/Godot-third-party.txt")},"  "))
    output.close();print("INSPECTED_PACK_FILES "+str(paths.size()));quit()
