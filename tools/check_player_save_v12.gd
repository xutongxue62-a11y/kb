extends SceneTree
func _initialize() -> void:
    var path:=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--save-file="): path=arg.trim_prefix("--save-file=")
    var data=JSON.parse_string(FileAccess.get_file_as_string(path))
    var store=load("res://src/save_store.gd").new("res://runtime/tests/read_only_player_compat")
    var error: String=store._validate_run(data)
    print("LATEST SAVE COMPATIBILITY RESULT: ","1 checks, 0 failures" if error.is_empty() else error)
    quit(0 if error.is_empty() else 1)
