extends SceneTree

var world
var folder := "res://previews/home_v09_native_v1"
var failures := 0
var markers: Array = []

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-folder="):
            folder = "res://previews/" + arg.trim_prefix("--capture-folder=")
    call_deferred("record")

func expect(value: bool, message: String) -> void:
    if not value:
        failures += 1
        print("FAIL: " + message)

func frames(count: int) -> void:
    for i in range(count): await process_frame

func mark(text_value: String) -> void:
    markers.append({"name":text_value,"frame":Engine.get_frames_drawn()})
    print("HOME NATIVE: ", text_value, " frame=", Engine.get_frames_drawn())

func shot(name_value: String) -> void:
    await RenderingServer.frame_post_draw
    expect(root.get_texture().get_image().save_png(folder + "/" + name_value + ".png") == OK, "save " + name_value)

func target(key: String) -> BaseButton:
    return world.hud.overlay.find_child(key, true, false) as BaseButton

func hover(button: BaseButton) -> void:
    if button == null:
        failures += 1
        return
    var event := InputEventMouseMotion.new()
    event.position = button.get_global_rect().get_center()
    event.global_position = event.position
    Input.parse_input_event(event)
    await process_frame

func click(button: BaseButton) -> void:
    var wait_frames := 0
    while world.hud.ui_busy() and wait_frames < 300:
        await process_frame
        wait_frames += 1
    if button == null or button.disabled or world.hud.ui_busy():
        failures += 1
        print("FAIL: native input target unavailable")
        return
    await hover(button)
    for down in [true, false]:
        var event := InputEventMouseButton.new()
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        event.position = button.get_global_rect().get_center()
        event.global_position = event.position
        Input.parse_input_event(event)
        await process_frame

func record() -> void:
    root.size = Vector2i(1280, 800)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/home_native_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    await frames(20)
    mark("home_idle_animation")
    await shot("01_home_idle")
    await frames(65)
    await shot("02_home_orbit_later")
    mark("quiet_paper_hover")
    await hover(target("EnterCamp"))
    await frames(15)
    await shot("03_home_hover")
    mark("enter_character")
    await click(target("EnterCamp"))
    await frames(24)
    mark("soft_return")
    await click(target("Back"))
    await frames(7)
    await shot("04_return_bend")
    await frames(20)
    await click(target("Settings"))
    await frames(17)
    await click(target("Back"))
    await frames(14)
    await click(target("EnterCamp"))
    await frames(20)
    mark("richer_parchment_burn")
    world.set_physics_process(true)
    await click(target("StartSling"))
    await frames(6)
    await shot("05_burn_flare")
    await frames(8)
    await shot("06_burn_layers")
    await frames(8)
    await shot("07_burn_embers")
    await frames(70)
    world.set_physics_process(false)
    expect(world.departure_left <= 0, "readiness finishes before chest demonstration")
    world.clear_enemies()
    world.spawn_clock = 999
    world.invulnerable = 999
    var drop_at: Vector2 = world.player_position + Vector2(255, 0)
    world.spawn_enemy("hunter", drop_at)
    var elite: Dictionary = world.enemies.back()
    elite["elite"] = true
    elite["view"].elite = true
    world.hatch_enemy(elite, false)
    world.spawn_enemy("tank", drop_at + Vector2(120, -96), false, "egg")
    var egg: Dictionary = world.enemies.back()
    egg["elite"] = true
    egg["view"].elite = true
    mark("elite_silhouette_only")
    await frames(22)
    await shot("08_elite_outline")
    world.hurt_enemy(elite, 100000, "powder", true, Vector2.ZERO)
    world.clear_enemies()
    world.pickups.clear()
    world.simulate(0.01, Vector2.ZERO)
    expect(world.chest_marks.size() == 1 and not world.upgrade_pending, "far chest stays on ground without reward")
    mark("dropped_chest_awaits_pickup")
    for i in range(22):
        world.simulate(1.0 / 30.0, Vector2.ZERO)
        await process_frame
    await shot("09_chest_far")
    mark("walk_to_collect")
    for i in range(50):
        world.simulate(1.0 / 30.0, Vector2.RIGHT)
        await process_frame
        if world.upgrade_pending: break
    expect(world.chest_marks.is_empty() and world.upgrade_pending and world.upgrade_reason == "chest", "walking onto chest removes it and opens one reward")
    mark("chest_removed_reward_open")
    await frames(24)
    await shot("10_chest_reward_after_pickup")
    var cards: Array = []
    for node in world.hud.overlay.find_children("*", "Button", true, false):
        if node.text.is_empty(): cards.append(node)
    if not cards.is_empty(): await click(cards[0])
    else: failures += 1
    await frames(18)
    expect(world.chest_marks.is_empty() and world.chest_queue == 0 and not world.upgrade_pending, "picked chest does not remain or reward twice")
    await shot("11_ground_clear")
    var file := FileAccess.open(folder + "/timeline.json", FileAccess.WRITE)
    file.store_string(JSON.stringify({"fps":30,"markers":markers,"failures":failures,"note":"isolated save; invulnerable gameplay demonstration; walking uses normal simulate movement"}, "  "))
    print("HOME NATIVE RESULT: ", failures, " failures")
    quit(1 if failures else 0)
