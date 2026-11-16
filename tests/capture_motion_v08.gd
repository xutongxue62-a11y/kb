extends SceneTree

var world
var failures := 0
var folder := "res://previews/ui_v08_motion_v1"
var markers: Array = []

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--motion-folder="):
            folder = "res://previews/" + arg.trim_prefix("--motion-folder=")
    call_deferred("record")

func frames(count: int) -> void:
    for i in range(count):
        await process_frame

func mark(label_value: String) -> void:
    markers.append({"name":label_value,"frame":Engine.get_frames_drawn()})
    print("MOTION: ", label_value, " frame=", Engine.get_frames_drawn())

func shot(name_value: String) -> void:
    await RenderingServer.frame_post_draw
    var result: Error = root.get_texture().get_image().save_png(folder + "/" + name_value + ".png")
    if result != OK: failures += 1

func target(key: String) -> BaseButton:
    return world.hud.overlay.find_child(key, true, false) as BaseButton

func hover(button: BaseButton) -> void:
    if button == null:
        failures += 1
        return
    var move := InputEventMouseMotion.new()
    move.position = button.get_global_rect().get_center()
    move.global_position = move.position
    Input.parse_input_event(move)
    await process_frame

func click(button: BaseButton) -> void:
    var waited := 0
    while world.hud.ui_busy() and waited < 300:
        await process_frame
        waited += 1
    if button == null or button.disabled or world.hud.ui_busy():
        failures += 1
        print("FAIL: motion input target unavailable")
        return
    await hover(button)
    for down in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = button.get_global_rect().get_center()
        event.global_position = event.position
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        Input.parse_input_event(event)
        await process_frame

func record() -> void:
    root.size = Vector2i(1280, 800)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/motion_v08_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    await frames(24)
    mark("button_hover")
    await hover(target("EnterCamp"))
    await frames(14)
    await shot("01_button_ink_hover")
    mark("staged_character_page")
    await click(target("EnterCamp"))
    await frames(24)
    await shot("02_character_arrows")
    mark("folded_modal")
    await click(target("Settings"))
    await frames(4)
    await shot("03_modal_fold_mid")
    await frames(17)
    await shot("04_modal_open")
    mark("modal_close")
    await click(target("Back"))
    await frames(22)
    mark("radial_parchment_burn")
    world.set_physics_process(true)
    await click(target("StartSling"))
    await frames(7)
    await shot("05_burn_early")
    await frames(8)
    await shot("06_burn_middle")
    await frames(8)
    await shot("07_burn_late")
    await frames(15)
    await shot("08_ready")
    await frames(45)
    world.set_physics_process(false)
    world.clear_enemies()
    world.upgrade_pending = true
    world.upgrade_choices = ["club", "power", "pet"]
    world.upgrade_reason = "xp"
    mark("physical_buff_scroll")
    world.hud.show_choices(world.upgrade_choices, world.inventory, {}, "xp", 1)
    await frames(6)
    await shot("09_scroll_rolling")
    await frames(19)
    await shot("10_scroll_open")
    var cards: Array = []
    for node in world.hud.overlay.find_children("*", "Button", true, false):
        if node.text.is_empty(): cards.append(node)
    if cards.size() >= 2:
        await hover(cards[1])
        await frames(10)
        await shot("11_choice_hover")
        mark("choice_confirmation")
        await click(cards[1])
    else:
        failures += 1
    await frames(18)
    mark("return_page_turn")
    world.go_home()
    await frames(18)
    await click(target("EnterCamp"))
    await frames(20)
    await click(target("Back"))
    await frames(18)
    mark("weapon_clearance_demo")
    world.start_run(true)
    world.clear_enemies()
    world.invulnerable = 999
    world.spawn_enemy("tank", world.player_position + Vector2(155, -5))
    world.enemies.back()["hp"] = 10000
    world.enemies.back()["max_hp"] = 10000
    world.set_physics_process(true)
    await frames(42)
    await shot("12_weapon_spacing")
    world.set_physics_process(false)
    await frames(12)
    var file := FileAccess.open(folder + "/timeline.json", FileAccess.WRITE)
    file.store_string(JSON.stringify({"fps":30,"markers":markers,"failures":failures,"note":"isolated test save; final tank has artificial durability for weapon visibility"}, "  "))
    print("MOTION CAPTURE RESULT: ", failures, " failures")
    quit(1 if failures else 0)
