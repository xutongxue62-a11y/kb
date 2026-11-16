extends SceneTree
func _initialize() -> void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:
        push_error("Expected one private release-key directory");quit(1);return
    var folder: String=args[0]
    DirAccess.make_dir_recursive_absolute(folder)
    var private: String=folder.path_join("update_private.pem")
    if FileAccess.file_exists(private):
        print("Existing update signing key preserved");quit();return
    var key:=Crypto.new().generate_rsa(2048)
    if key.save(private)!=OK or key.save(folder.path_join("update_public.pem"),true)!=OK:
        push_error("Could not save release keys");quit(1);return
    print("Generated release update keys outside distributable resources")
    quit()
