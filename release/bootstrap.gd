extends Node
const Policy=preload("res://release/update_policy.gd")
const Client=preload("res://release/update_client.gd")
const BootState=preload("res://release/update_boot_state.gd")
const CACHE: String="user://content_updates/v1"
var config: Dictionary={}
var key: CryptoKey
var platform: String=""
var loaded_build: int=0
var rejected_build: int=0
var loaded_version: String=""
var loaded_cached:=false
var safe_mode:=false

func read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var file:=FileAccess.open(path,FileAccess.READ)
    if file==null or file.get_length()>65536: return {}
    var value: Variant=JSON.parse_string(file.get_as_text());file.close()
    return value if typeof(value)==TYPE_DICTIONARY else {}
func write_json(path: String,value: Dictionary) -> bool:
    var file:=FileAccess.open(path,FileAccess.WRITE)
    if file==null: return false
    file.store_string(JSON.stringify(value));file.flush()
    var ok: bool=file.get_error()==OK;file.close();return ok
func _init() -> void:
    config=read_json("res://release/update_config.json")
    platform=OS.get_name().to_lower()
    loaded_build=int(config.get("build",2026111601));loaded_version=str(config.get("version","0.23.0"))
    safe_mode=OS.get_cmdline_user_args().has("--safe-mode")
    key=CryptoKey.new()
    if key.load("res://release/update_public.pem",true)!=OK: key=null
    DirAccess.make_dir_recursive_absolute(CACHE)
    var startup: Dictionary=BootState.recover(CACHE,not safe_mode)
    rejected_build=int(startup.highest_failure)
    if not safe_mode and key!=null and not startup.disable_cache:
        for filename in ["active.json","previous.json"]:
            var envelope: Dictionary=read_json(CACHE.path_join(filename))
            var result: Dictionary=Policy.validate(envelope,key,platform,loaded_build,str(config.get("engine","4.7.2")),int(config.get("launcher_api",1)))
            if not result.ok or startup.failed_builds.has(int(result.payload.build)): continue
            var pack: String=CACHE.path_join(str(result.package.sha256)+".pck")
            if not Policy.file_matches(pack,result.package): continue
            if not BootState.begin(CACHE,filename,int(result.payload.build)): continue
            if ProjectSettings.load_resource_pack(pack,true):
                loaded_build=int(result.payload.build);loaded_version=str(result.payload.version);loaded_cached=true
                break
            startup=BootState.recover(CACHE)
            rejected_build=int(startup.highest_failure)
func _ready() -> void:
    # Loading is intentionally dynamic: no game preload may happen before pack mounting.
    var scene=load("res://main.tscn")
    if scene==null or not scene is PackedScene:
        abort_startup()
        return
    var world=scene.instantiate()
    var smoke_dir: String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--verify-release="): smoke_dir=argument.trim_prefix("--verify-release=")
    if not smoke_dir.is_empty(): world.save_store=load("res://src/save_store.gd").new("user://release_smoke")
    add_child(world)
    get_window().set_deferred("title","原始人大作战 · 荒野交锋 v"+loaded_version)
    print("RELEASE_BOOT build=%d version=%s platform=%s cached=%s" % [loaded_build,loaded_version,platform,loaded_cached])
    await get_tree().process_frame
    await get_tree().process_frame
    if not BootState.ready_for_play(world):
        abort_startup(world)
        return
    if loaded_cached: BootState.confirm(CACHE)
    var settings_path: String="user://updates.json" if platform=="android" else OS.get_executable_path().get_base_dir().path_join("updates.json")
    var settings: Dictionary=read_json(settings_path)
    var updater:=Client.new()
    updater.feed_url="" if safe_mode else str(settings.get("feed_url",config.get("feed_url","")))
    updater.public_key=key;updater.platform=platform
    updater.current_build=maxi(loaded_build,rejected_build)
    updater.engine_version=str(config.get("engine","4.7.2"));updater.launcher_api=int(config.get("launcher_api",1))
    add_child(updater)
    updater.call_deferred("check_for_updates")
    if not smoke_dir.is_empty():
        DirAccess.make_dir_recursive_absolute(smoke_dir)
        world.settings.autosave=false;world.music.set_enabled(false)
        for _i in range(50): await get_tree().process_frame
        if DisplayServer.get_name()!="headless":
            await RenderingServer.frame_post_draw
            get_viewport().get_texture().get_image().save_png(smoke_dir.path_join("home.png"))
        world.start_run(true);world.set_physics_process(false)
        # Diagnostic movement must not queue combat voices on a dummy audio driver.
        world.audio.stop_all();world.audio.streams.clear()
        for _i in range(30): await get_tree().process_frame
        var control=world.find_child("MobileControls",false,false)
        var touch_checks: Dictionary={}
        if control!=null:
            var begin:=InputEventScreenTouch.new();begin.index=3;begin.pressed=true;begin.position=control.stick_center
            get_viewport().push_input(begin,true)
            var drag:=InputEventScreenDrag.new();drag.index=3;drag.position=control.stick_center+Vector2(65,0)
            get_viewport().push_input(drag,true)
            touch_checks.movement=world.read_movement().x>0.9
            var dodge:=InputEventScreenTouch.new();dodge.index=8;dodge.pressed=true;dodge.position=control.dodge_center
            get_viewport().push_input(dodge,true)
            touch_checks.dodge=world.dodge_left>0
            var old_position: Vector2=world.player_position
            world.simulate(0.04,world.read_movement())
            touch_checks.player_moved=world.player_position.x>old_position.x
            for index in [3,8]:
                var end:=InputEventScreenTouch.new();end.index=index;end.pressed=false;end.position=control.stick_center
                get_viewport().push_input(end,true)
                end=null
            touch_checks.released=world.touch_input==Vector2.ZERO
            begin=null;drag=null;dodge=null
        if DisplayServer.get_name()!="headless":
            await RenderingServer.frame_post_draw
            get_viewport().get_texture().get_image().save_png(smoke_dir.path_join("battle.png"))
        write_json(smoke_dir.path_join("smoke.json"),{"build":loaded_build,"version":loaded_version,"platform":platform,"cached":loaded_cached,"game_ready":is_instance_valid(world.hud),"touch_controls":control!=null,"touch_checks":touch_checks,"updater_requests":updater.requests_started,"real_player_storage_used":false})
        control=null;scene=null
        world.queue_free();world=null
        await get_tree().process_frame
        await get_tree().process_frame
        get_tree().quit()

func abort_startup(world: Node=null) -> void:
    BootState.dispose_world(world)
    get_tree().paused=false
    get_tree().auto_accept_quit=true
    get_tree().quit_on_go_back=true
    push_error("Game startup did not complete. Reopen to recover previous content.")
    if DisplayServer.get_name()=="headless":
        get_tree().quit(1)
        return
    var message:=Label.new()
    message.text="更新未能启动，请关闭后重新打开游戏，以恢复之前版本。\nUpdate failed to start. Reopen the game to restore previous content."
    message.position=Vector2(80,330);message.size=Vector2(1120,150)
    message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    message.add_theme_font_size_override("font_size",22)
    message.add_theme_color_override("font_color",Color("#402c1a"))
    var layer:=CanvasLayer.new();layer.layer=999;add_child(layer)
    var backdrop:=ColorRect.new();backdrop.color=Color("#eddfc2");backdrop.size=get_viewport().get_visible_rect().size
    layer.add_child(backdrop);layer.add_child(message)
    var close:=Button.new();close.text="关闭 / Close";close.position=Vector2(540,510);close.size=Vector2(200,50)
    close.pressed.connect(func():get_tree().quit())
    layer.add_child(close)
