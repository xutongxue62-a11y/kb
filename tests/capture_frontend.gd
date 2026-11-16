extends SceneTree

var world
var folder := "res://previews/ui_v07_verified"
var failures := 0

func _initialize() -> void:
    call_deferred("run_capture")

func shot(name_value: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var path: String = folder + "/" + name_value + ".png"
    var image: Image = root.get_texture().get_image()
    var result: Error = image.save_png(path)
    if result != OK:
        failures += 1
    print("CAPTURE: ", name_value, " ", image.get_size(), " error=", result)

func click(key: String) -> bool:
    var button: BaseButton = world.hud.overlay.find_child(key, true, false) as BaseButton
    if button == null or button.disabled:
        failures += 1
        print("FAIL: native target unavailable ", key)
        return false
    var point: Vector2 = button.get_global_rect().get_center()
    var move := InputEventMouseMotion.new()
    move.position = point
    move.global_position = point
    Input.parse_input_event(move)
    await process_frame
    for down in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = point
        event.global_position = point
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        Input.parse_input_event(event)
        await process_frame
    return true

func wait_settle(seconds: float = 0.58) -> void:
    await create_timer(seconds).timeout

func run_capture() -> void:
    root.size = Vector2i(1280, 800)
    root.title = "原始人大作战 · UI原生核验（隔离测试存档）"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/ui_capture_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.start_run(false)
    world.wave = 3
    world.coins = 28
    world.player_hp = 6
    world.player_level = 4
    world.save_game()
    world.go_home()
    await wait_settle()
    await shot("01_home")
    await click("EnterCamp")
    await wait_settle(0.10)
    await shot("02_cast_unrolling")
    await wait_settle()
    await shot("03_cast")
    await click("Settings")
    await wait_settle()
    await shot("04_settings_from_cast")
    await click("Back")
    await wait_settle()
    await click("Back")
    await wait_settle()
    await click("ContinueSave")
    await wait_settle()
    await shot("05_continue")
    await click("Back")
    await wait_settle()
    await click("EnterCamp")
    await wait_settle()
    world.set_physics_process(true)
    await click("StartSling")
    await wait_settle(0.12)
    await shot("06_departure_burn")
    await wait_settle(0.48)
    await shot("07_departure_ready")
    var before: float = world.elapsed
    await wait_settle(0.65)
    if world.elapsed != before:
        failures += 1
        print("FAIL: battle clock advanced during native countdown")
    await wait_settle(1.4)
    world.set_physics_process(false)
    await shot("08_combat")
    world.hud.show_choices(["club", "power", "pet"], world.inventory, {}, "xp", 1)
    await wait_settle(0.12)
    await shot("09_growth_unrolling")
    await wait_settle()
    await shot("10_growth")
    world.hud.hide_menu()
    world.paused = false
    world.toggle_pause()
    await wait_settle()
    await shot("11_pause")
    world.hud.show_shop([{ "id":"sling", "price":18, "sold":false }, {"id":"power","price":14,"sold":false}, {"id":"pet","price":24,"sold":false}, {"id":"heal","price":10,"sold":false}], 28, 3, world.inventory, {}, 6, 8)
    await wait_settle()
    await shot("12_shop")
    print("NATIVE UI RESULT: ", failures, " failures")
    world.queue_free()
    await process_frame
    quit(1 if failures else 0)
