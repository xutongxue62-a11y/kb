extends SceneTree

var failures: int = 0
var checks: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func labels_under(node: Node) -> Array:
    var result: Array = []
    if node is Label:
        result.append(node.text)
    for child in node.get_children():
        result.append_array(labels_under(child))
    return result

func key_event(code: int, pressed: bool) -> void:
    var event: InputEventKey = InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.pressed = pressed
    Input.parse_input_event(event)

func tap(code: int) -> void:
    key_event(code, true)
    await process_frame
    key_event(code, false)
    await process_frame

func _initialize() -> void:
    call_deferred("run_checks")

func run_checks() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/controls_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.debug_cheats = true
    if world.hud != null:
        world.hud.debug_cheats = true
        world.hud.refresh_debug_controls()
    await tap(KEY_F2)
    expect(world.inventory.size() == 6 and world.running, "F2 event opens the six-weapon trial through the actual input route")
    await tap(KEY_SPACE)
    expect(world.collapsed, "space key switches formation through the scene input handler")
    await tap(KEY_Q)
    expect(world.link_pack_open and world.active_link["id"] == "none" and world.hud.screen == "link_pack", "Q opens the weapon pack and does not cycle recipes")
    await tap(KEY_ESCAPE)
    expect(not world.link_pack_open and not world.paused, "Escape closes the pack without pausing")
    await tap(KEY_ESCAPE)
    expect(world.paused and world.hud.overlay.visible, "Escape key opens the pause menu")
    await tap(KEY_ESCAPE)
    expect(not world.paused and not world.hud.overlay.visible, "Escape resumes from the real menu")
    var before: Vector2 = world.player_position
    key_event(KEY_D, true)
    await process_frame
    world._physics_process(0.1)
    expect(world.player_position.x > before.x, "physical D state drives movement in the real physics input path")
    key_event(KEY_D, false)
    await process_frame
    await tap(KEY_R)
    expect(world.elapsed == 0.0 and world.player_hp == 8 and world.inventory.size() == 6, "R resets the current trial loadout")
    world.demo = true
    world.start_run(true)
    # Ninety combat seconds plus the three intentional settlement freezes.
    for index in range(5402+ceili(world.WAVE_BUFFER*3*60)):
        world._physics_process(1.0 / 60.0)
    expect(world.running and world.wave >= 4 and not world.hud.overlay.visible, "a full simulated ninety-second battle continues into endless wave four")
    expect(world.kills > 10 and world.inventory.size() == 6, "full-round combat actually defeats enemies while preserving six weapons")
    expect(world.hero.phase > 0.0, "full-round movement advances the real hero gait")
    world.queue_free()
    await process_frame
    print("CONTROL/ROUND RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
