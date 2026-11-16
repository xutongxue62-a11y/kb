extends SceneTree
var world
var failures := 0
var folder := "res://previews/battle_v10_native_v1"
var markers: Array = []
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-folder="): folder = "res://previews/" + arg.trim_prefix("--capture-folder=")
    call_deferred("record")
func expect(value: bool, message: String) -> void:
    if not value:
        failures += 1
        print("FAIL: " + message)
func frames(count: int) -> void:
    for i in range(count): await process_frame
func ticks(count: int, movement: Vector2 = Vector2.ZERO) -> void:
    for i in range(count):
        world.simulate(1.0/30.0,movement)
        await process_frame
func mark(value: String) -> void:
    markers.append({"name":value,"frame":Engine.get_frames_drawn(),"world":[world.player_position.x,world.player_position.y]})
    print("BATTLE NATIVE: ",value," frame=",Engine.get_frames_drawn())
func shot(value: String) -> void:
    await RenderingServer.frame_post_draw
    expect(root.get_texture().get_image().save_png(folder+"/"+value+".png") == OK,"save "+value)
func target(key: String) -> BaseButton:
    return world.hud.overlay.find_child(key,true,false) as BaseButton
func click(button: BaseButton) -> void:
    var waited := 0
    while world.hud.ui_busy() and waited < 300:
        await process_frame
        waited += 1
    if button == null or button.disabled or world.hud.ui_busy():
        failures += 1
        print("FAIL: missing/locked native button")
        return
    var at: Vector2 = button.get_global_rect().get_center()
    var move := InputEventMouseMotion.new()
    move.position = at
    move.global_position = at
    Input.parse_input_event(move)
    for down in [true,false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.global_position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        Input.parse_input_event(event)
        await process_frame
func key(code: int, pressed: bool) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.pressed = pressed
    Input.parse_input_event(event)
    await process_frame
func dummy(kind: String, at: Vector2, elite: bool = false) -> void:
    world.spawn_enemy(kind,at)
    var enemy: Dictionary = world.enemies.back()
    enemy["hp"] = 10000
    enemy["max_hp"] = 10000
    enemy["elite"] = elite
    enemy["view"].elite = elite
func record() -> void:
    root.size = Vector2i(1280,800)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/battle_native_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    mark("animated_home_music_on")
    await frames(85)
    await shot("01_home_attack_rhythm")
    await click(target("Settings"))
    await frames(15)
    await shot("02_settings_music")
    await click(target("MusicEnabled"))
    mark("music_disabled")
    await frames(38)
    expect(not world.music.is_enabled() and not world.save_store.read_settings().music_enabled,"music off persists independently")
    await click(target("MusicEnabled"))
    mark("music_enabled_again")
    await frames(25)
    expect(world.music.is_enabled() and world.save_store.read_settings().music_enabled,"music can resume and persist")
    await click(target("Back"))
    await frames(14)
    await click(target("EnterCamp"))
    await click(target("StartSling"))
    world.set_physics_process(true)
    await frames(78)
    world.set_physics_process(false)
    world.start_run(true,"base")
    world.clear_enemies()
    world.spawn_clock = 999
    world.invulnerable = 999
    dummy("hunter",world.player_position+Vector2(-278,-94),true)
    dummy("charger",world.player_position+Vector2(262,-90))
    dummy("spitter",world.player_position+Vector2(-241,152))
    dummy("tank",world.player_position+Vector2(269,157),true)
    mark("paper_hud_and_complete_silhouettes")
    await frames(20)
    await shot("03_hud_and_dinosaur_edges")
    world.clear_enemies()
    mark("shift_dodge")
    await key(KEY_D,true)
    world.set_physics_process(true)
    await frames(2)
    await key(KEY_SHIFT,true)
    await frames(2)
    await shot("04_shift_afterimage")
    await key(KEY_SHIFT,false)
    mark("real_walk_beyond_original_screen")
    await frames(115)
    await key(KEY_D,false)
    world.set_physics_process(false)
    expect(world.player_position.x > 1400,"normal walking reveals terrain beyond the original arena")
    expect(world.world_camera.position.distance_to(world.player_position)<0.1,"world camera tracks actual movement")
    await shot("05_far_world_new_terrain")
    world.wave = 6
    world.wave_elapsed = 3
    world.boss_round = false
    world.update_hud()
    mark("fern_grove_chunks")
    await ticks(42,Vector2(0.5,0.25))
    await shot("06_grove_interior_props")
    world.wave = 9
    world.wave_elapsed = 0
    world.update_hud()
    var pit_at: Vector2 = world.player_position+Vector2(160,0)
    var found := false
    for chunk_key in world.map_view.visible_chunks():
        for prop in world.map_view.chunk_content(chunk_key):
            if prop.kind == "lava":
                pit_at = prop.point
                found = true
                break
        if found: break
    expect(found,"volcano has a real interior lava pit")
    world.player_position = pit_at-Vector2(170,20)
    world.update_hud()
    mark("volcano_bubbling_interior")
    await ticks(30)
    await shot("07_volcano_pits")
    dummy("tank",world.player_position+Vector2(159,0),true)
    await key(KEY_Q,true)
    await key(KEY_Q,false)
    expect(world.active_link.kind == "rune","real Q selects an owned rune recipe")
    mark("rune_transfer_and_fire")
    await ticks(24)
    await shot("08_rune_ignition")
    await ticks(33)
    await shot("09_enchanted_fire")
    world.clear_enemies()
    dummy("tank",world.player_position+Vector2(136,0),true)
    await key(KEY_Q,true)
    await key(KEY_Q,false)
    expect(world.active_link.kind == "chain","real Q selects the next chain recipe")
    mark("visible_chain_attack")
    await ticks(12)
    await shot("10_chain_links")
    await ticks(65)
    await shot("11_volcano_combat")
    var file := FileAccess.open(folder+"/timeline.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"fps":30,"markers":markers,"failures":failures,"note":"isolated save; six-weapon trial, durable enemies and invulnerability are presentation fixtures; Shift and world walk use actual input events; map-stage preview set explicitly"},"  "))
    world.music.set_enabled(false)
    await frames(18)
    world.queue_free()
    await frames(3)
    print("BATTLE NATIVE RESULT: ",failures," failures")
    quit(1 if failures else 0)
