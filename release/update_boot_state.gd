extends RefCounted
static func read_json(path: String) -> Dictionary:
    var file:=FileAccess.open(path,FileAccess.READ)
    if file==null or file.get_length()>65536: return {}
    var value: Variant=JSON.parse_string(file.get_as_text());file.close()
    return value if typeof(value)==TYPE_DICTIONARY else {}
static func write_json(path: String,value: Dictionary) -> bool:
    var next: String=path+".next"
    var file:=FileAccess.open(next,FileAccess.WRITE)
    if file==null: return false
    file.store_string(JSON.stringify(value));file.flush()
    var ok: bool=file.get_error()==OK;file.close()
    if not ok: return false
    if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK: return false
    return DirAccess.rename_absolute(next,path)==OK
static func begin(folder: String,pointer: String,build: int) -> bool:
    if pointer not in ["active.json","previous.json"]: return false
    return write_json(folder.path_join("starting.json"),{"build":build,"pointer":pointer})
static func confirm(folder: String) -> void:
    if FileAccess.file_exists(folder.path_join("starting.json")): DirAccess.remove_absolute(folder.path_join("starting.json"))
static func recover(folder: String,recover_interrupted: bool=true) -> Dictionary:
    var stored: Dictionary=read_json(folder.path_join("failed.json"))
    var failed: Array=[]
    if typeof(stored.get("builds"))==TYPE_ARRAY:
        for value in stored.builds:
            if (typeof(value)==TYPE_INT or typeof(value)==TYPE_FLOAT) and value>0 and not failed.has(int(value)): failed.append(int(value))
    var highest: int=int(stored.get("build",0))
    if highest>0 and not failed.has(highest): failed.append(highest)
    var disabled:=false
    if recover_interrupted and FileAccess.file_exists(folder.path_join("starting.json")):
        var attempt: Dictionary=read_json(folder.path_join("starting.json"))
        var build: int=int(attempt.get("build",0))
        if build>0 and not failed.has(build): failed.append(build)
        highest=maxi(highest,build)
        if not write_json(folder.path_join("failed.json"),{"build":highest,"builds":failed}):
            disabled=true
        else:
            var pointer: String=str(attempt.get("pointer","active.json"))
            if pointer in ["active.json","previous.json"] and FileAccess.file_exists(folder.path_join(pointer)):
                DirAccess.rename_absolute(folder.path_join(pointer),folder.path_join("rejected_%d.json" % Time.get_ticks_usec()))
            confirm(folder)
    return {"highest_failure":highest,"failed_builds":failed,"disable_cache":disabled}
static func ready_for_play(world: Node) -> bool:
    return world!=null and world.get("game_ready")==true and is_instance_valid(world.get("hud")) and is_instance_valid(world.get("hero"))
static func dispose_world(world: Node) -> void:
    if not is_instance_valid(world): return
    world.process_mode=Node.PROCESS_MODE_DISABLED
    if world.get_parent()!=null: world.get_parent().remove_child(world)
    world.free()
