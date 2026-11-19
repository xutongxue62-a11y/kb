extends SceneTree
var checks: int = 0
var failures: int = 0
func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)
func _initialize() -> void:
    call_deferred("run_checks")
func run_checks() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/chest_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.force_elite_chests = true
    world.start_run(false)
    world.clear_enemies()
    world.spawn_clock = 999.0
    var drop_at: Vector2 = world.player_position + Vector2(300, 0)
    world.spawn_enemy("hunter", drop_at)
    var enemy: Dictionary = world.enemies.back()
    enemy["elite"] = true
    enemy["view"].elite = true
    world.hurt_enemy(enemy, 1000.0, "powder", true, Vector2.ZERO)
    expect(world.chest_marks.size() == 1 and world.chest_queue == 0, "elite kill drops ground chest without collecting reward")
    world.simulate(0.01, Vector2.ZERO)
    expect(not world.upgrade_pending and world.chest_marks.size() == 1, "distant chest cannot open growth or attract toward hero")
    # Leave a distant chest for persistence, then walk over the first one.
    world.offer_elite_chest(world.player_position + Vector2(-200, 0))
    world.player_position = drop_at
    world.pickups.clear()
    world.simulate(0.01, Vector2.ZERO)
    expect(world.chest_marks.size() == 1 and world.upgrade_pending and world.upgrade_reason == "chest", "contact removes only nearby chest and opens reward")
    if world.upgrade_pending:
        world.on_choice(world.upgrade_choices[0])
    world.simulate(0.01, Vector2.ZERO)
    expect(not world.upgrade_pending, "collected chest grants exactly one reward")
    world.chest_marks.clear()
    world.chest_queue = 0
    for flag in ["paused", "upgrade_pending", "shop_open"]:
        world.offer_elite_chest(world.player_position)
        world.set(flag, true)
        world.simulate(0.01, Vector2.ZERO)
        expect(world.chest_marks.size() == 1 and world.chest_queue == 0, flag + " prevents collection")
        world.set(flag, false)
        world.chest_marks.clear()
        world.chest_queue = 0
    world.offer_elite_chest(world.player_position)
    world.departure_left = 1.0
    world.simulate(0.01, Vector2.ZERO)
    expect(world.chest_marks.size() == 1 and world.chest_queue == 0, "departure prevents collection")
    world.departure_left = 0.0
    world.offer_elite_chest(world.player_position)
    world.offer_elite_chest(world.player_position + Vector2(250, 0))
    world.simulate(0.01, Vector2.ZERO)
    expect(world.chest_marks.size() == 1 and world.chest_queue == 1 and world.upgrade_pending, "simultaneous nearby boxes are removed without skipping and queued once each")
    expect(world.save_game(), "save accepts ground and collected chest state")
    expect(world.continue_game(), "load restores chest state")
    expect(world.chest_marks.size() == 1 and world.chest_queue + int(world.upgrade_pending and world.upgrade_reason == "chest") == 2, "load preserves ground box and both collected rewards including open choice")
    world.try_present_chest()
    if world.upgrade_pending:
        world.on_choice(world.upgrade_choices[0])
    expect(world.upgrade_pending and world.upgrade_reason == "chest", "second collected reward follows first after reload")
    if world.upgrade_pending:
        world.on_choice(world.upgrade_choices[0])
    expect(not world.upgrade_pending and world.chest_queue == 0, "reloaded rewards finish exactly once")
    world.end_round()
    expect(world.chest_marks.is_empty() and world.chest_queue==0 and world.shop_open and not world.upgrade_pending,"uncollected ground chest is discarded at round end")
    world.leave_shop()
    expect(world.chest_marks.is_empty() and world.chest_queue==0 and not world.upgrade_pending, "discarded end-round chest cannot carry into the next round")
    world.start_run(false)
    world.clear_enemies()
    world.spawn_clock = 999.0
    world.xp = world.xp_needed
    world.offer_elite_chest(world.player_position)
    world.offer_elite_chest(world.player_position)
    world.simulate(0.01, Vector2.ZERO)
    expect(world.upgrade_pending and world.upgrade_reason == "xp" and world.chest_queue == 2 and world.chest_marks.is_empty(), "XP choice defers collected rewards without leaving boxes behind")
    expect(world.save_game() and world.continue_game(), "collected queue survives saving while XP choice is open")
    expect(world.chest_queue == 2, "XP choice is not miscounted as an extra chest reward on reload")
    world.simulate(0.01, Vector2.ZERO)
    if world.upgrade_pending:
        world.on_choice(world.upgrade_choices[0])
    var disk: Dictionary = world.save_store.read_run()
    expect(disk["ok"] and disk["state"]["chest_queue"] == 2, "automatic save after XP reward retains both collected chest rewards")
    if world.upgrade_pending:
        world.on_choice(world.upgrade_choices[0])
    if world.upgrade_pending:
        world.on_choice(world.upgrade_choices[0])
    expect(not world.upgrade_pending and world.chest_queue == 0, "XP plus two chest rewards resolve without duplication")
    var saved: Dictionary = world.SessionState.capture(world)
    var legacy: Dictionary = saved.duplicate(true)
    legacy.erase("chest_marks")
    legacy.erase("chest_queue")
    expect(world.save_store.write_run(legacy)["ok"], "old saves without chest fields remain valid")
    world.offer_elite_chest(world.player_position)
    expect(world.continue_game() and world.chest_marks.is_empty() and world.chest_queue == 0, "loading old save defaults chest fields to empty")
    for bad in [-1, 0.5, "1"]:
        saved["chest_queue"] = bad
        expect(not world.save_store.write_run(saved)["ok"], "invalid chest queue rejected: " + str(bad))
    saved["chest_queue"] = 0
    saved["chest_marks"] = [{"position":[0, 0], "age":-1}]
    expect(not world.save_store.write_run(saved)["ok"], "invalid chest age rejected")
    var view = load("res://src/dino_view.gd").new()
    view.setup(world.library, "hunter", 60.0, false)
    root.add_child(view)
    view.elite = true
    expect(view.sprite.material.get_shader_parameter("team_color") == Color("#e31b28"), "elite changes after setup update silhouette outline material")
    view.elite = false
    expect(view.sprite.material.get_shader_parameter("team_color") != Color("#e31b28"), "clearing elite restores normal enemy outline")
    view.queue_free()
    # Real enemy deaths retain their actual world coordinates, all now reachable.
    var edge_cases: Array = [
        [Vector2(50,400), Vector2(50,400)],
        [Vector2(1230,400), Vector2(1230,400)],
        [Vector2(640,157), Vector2(640,157)],
        [Vector2(640,651), Vector2(640,651)],
        [Vector2(50,157), Vector2(50,157)],
        [Vector2(1230,157), Vector2(1230,157)],
        [Vector2(50,651), Vector2(50,651)],
        [Vector2(1230,651), Vector2(1230,651)],
        [Vector2(-80,-20), Vector2(-80,-20)],
        [Vector2(1360,-20), Vector2(1360,-20)],
        [Vector2(-80,900), Vector2(-80,900)],
        [Vector2(1360,900), Vector2(1360,900)],
    ]
    for fixture in edge_cases:
        world.start_run(false)
        world.clear_enemies()
        world.spawn_clock = 999.0
        world.spawn_enemy("hunter", fixture[0])
        var edge_enemy: Dictionary = world.enemies.back()
        edge_enemy["position"] = fixture[0]
        edge_enemy["elite"] = true
        world.hurt_enemy(edge_enemy, 1000.0, "powder", true, Vector2.ZERO)
        expect(world.chest_marks.size() == 1 and world.chest_marks[0]["position"] == fixture[1], "edge kill drops at actual reachable world position: " + str(fixture[0]))
        world.pickups.clear()
        world.player_position = fixture[1]
        world.simulate(0.01, Vector2.ZERO)
        expect(world.chest_marks.is_empty() and world.upgrade_pending and world.upgrade_reason == "chest", "edge kill chest can actually be collected: " + str(fixture[0]))
        if world.upgrade_pending:
            world.on_choice(world.upgrade_choices[0])
        world.simulate(0.01, Vector2.ZERO)
        expect(not world.upgrade_pending and world.chest_queue == 0, "edge chest grants once: " + str(fixture[0]))
        var raw_state: Dictionary = world.SessionState.capture(world)
        raw_state["chest_marks"] = [{"position":[fixture[0].x,fixture[0].y], "age":2.0}]
        expect(world.save_store.write_run(raw_state)["ok"] and world.continue_game() and world.chest_marks.size() == 1 and world.chest_marks[0]["position"] == fixture[1], "legacy raw chest retains reachable world position: " + str(fixture[0]))
        world.clear_enemies()
        world.spawn_clock = 999.0
        world.simulate(0.01, Vector2.ZERO)
        expect(world.chest_marks.is_empty() and world.upgrade_pending and world.upgrade_reason == "chest", "restored edge chest can actually be collected: " + str(fixture[0]))
    world.queue_free()
    await process_frame
    print("CHEST_PICKUP RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
