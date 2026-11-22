extends SceneTree

var checks: int = 0
var failures: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func _initialize() -> void:
    call_deferred("run_checks")

func prepare_world(suffix: String):
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/boss_clear_" + suffix + "_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.settings.autosave = false
    world.start_run(false)
    world.invulnerable = 999.0
    world.spawn_clock = 999.0
    world.xp_needed = 99999
    world.chest_queue = 0
    for runtime in world.weapon_runtime.values():
        runtime["cooldown"] = 99.0
    return world

func begin_live_boss(world) -> Dictionary:
    world.clear_enemies()
    world.pickups.clear()
    world.chest_marks.clear()
    world.demo = false
    world.begin_round(5)
    world.invulnerable = 999.0
    world.xp_needed = 99999
    world.chest_queue = 0
    for runtime in world.weapon_runtime.values():
        runtime["cooldown"] = 99.0
    world.simulate(0.56, Vector2.ZERO)
    world.spawn_clock = 999.0
    var boss: Dictionary = {}
    for enemy in world.enemies:
        if enemy["kind"] == "boss":
            boss = enemy
            break
    expect(world.boss_round and not boss.is_empty() and not world.boss_defeated, "Boss round has a living Boss")
    return boss

func advance_live(world, seconds: float, movement: Vector2 = Vector2.ZERO) -> void:
    var left: float = seconds
    var guard: int = 0
    while left > 0.000001 and guard < 200:
        guard += 1
        if world.upgrade_pending:
            world.on_choice(world.upgrade_choices[0])
            continue
        if world.shop_open or not world.running:
            break
        var step: float = minf(0.5, left)
        world.simulate(step, movement)
        left -= step

func run_checks() -> void:
    check_living_boss_does_not_advance()
    check_death_keeps_combat_open()
    check_cleanup_keeps_spawns_and_allows_contact_loot()
    check_settlement_after_window_discards_leftovers()
    check_mid_cleanup_save_restores_timer()
    check_normal_waves_unchanged()
    print("BOSS CLEAR RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)

func check_living_boss_does_not_advance() -> void:
    var world = prepare_world("living")
    var boss: Dictionary = begin_live_boss(world)
    if boss.is_empty():
        world.queue_free()
        return
    boss["hp"] = 10000.0
    boss["max_hp"] = 10000.0
    advance_live(world, 31.0)
    expect(world.wave == 5 and world.boss_round and not world.boss_defeated and not world.shop_open and not world.wave_closing, "a living Boss does not end the wave after thirty-plus seconds")
    expect(world.wave_elapsed > 30.0, "Boss fight time can exceed a normal wave clock")
    expect(world.hud.timer_label.text.contains("Boss "), "the HUD shows the 3-minute Boss countdown while the Boss lives")
    world.queue_free()

func check_death_keeps_combat_open() -> void:
    var world = prepare_world("death")
    var boss: Dictionary = begin_live_boss(world)
    if boss.is_empty():
        world.queue_free()
        return
    world.hurt_enemy(boss, 20000.0, "powder", true, Vector2.RIGHT)
    expect(world.boss_defeated and is_equal_approx(world.boss_clear_left, world.BOSS_CLEAR_SECONDS), "Boss death arms a thirty-second cleanup timer")
    world.simulate(0.01, Vector2.ZERO)
    expect(not world.wave_closing and not world.shop_open and world.running and not world.player_frozen, "the death frame and a short simulate do not start settlement")
    expect(world.boss_clear_left > 29.0, "cleanup time is almost fully remaining immediately after death")
    world.update_hud()
    expect(not world.hud.timer_label.text.contains("Boss ") and world.hud.timer_label.text.contains("00:"), "cleanup uses a normal countdown instead of the Boss timer label")
    expect(not world.hud.boss_bar.visible, "the Boss bar hides once the Boss is dead")
    world.queue_free()

func check_cleanup_keeps_spawns_and_allows_contact_loot() -> void:
    var world = prepare_world("spawns")
    var boss: Dictionary = begin_live_boss(world)
    if boss.is_empty():
        world.queue_free()
        return
    world.spawn_enemy("hunter", world.player_position + Vector2(80, 0))
    var minion_id: int = int(world.enemies.back()["id"])
    world.hurt_enemy(boss, 20000.0, "powder", true, Vector2.RIGHT)
    world.simulate(0.01, Vector2.ZERO)
    expect(not world.enemies.any(func(enemy): return enemy["kind"] == "boss" and enemy["hp"] > 0.0), "the defeated Boss is gone")
    expect(world.enemies.any(func(enemy): return int(enemy["id"]) == minion_id and enemy["hp"] > 0.0), "existing minions stay during the cleanup window")
    var after_death: int = world.enemies.size()
    world.spawn_clock = 0.0
    world.simulate(0.25, Vector2.ZERO)
    expect(world.enemies.size() > after_death, "minions keep spawning during the cleanup window")
    expect(not world.enemies.any(func(enemy): return enemy["kind"] == "boss" and enemy["hp"] > 0.0), "cleanup spawns regular minions, not another Boss")
    var minion: Dictionary = {}
    for enemy in world.enemies:
        if int(enemy["id"]) == minion_id:
            minion = enemy
            break
    expect(not minion.is_empty(), "the surviving minion can still be found")
    if not minion.is_empty():
        world.hurt_enemy(minion, 1000.0, "powder", true, Vector2.RIGHT)
        world.simulate(0.01, Vector2.ZERO)
        expect(not world.enemies.any(func(enemy): return int(enemy["id"]) == minion_id and enemy["hp"] > 0.0), "existing minions can still be killed in the cleanup window")
    world.coins = 10
    world.xp = 0.0
    world.player_hp = 6.0
    world.pickups.clear()
    world.pickups.append({"kind": "coin", "position": world.player_position, "value": 4})
    world.pickups.append({"kind": "xp", "position": world.player_position, "value": 3})
    world.pickups.append({"kind": "blood", "position": world.player_position, "value": 2})
    var coins_before: int = world.coins
    var xp_before: float = world.xp
    var hp_before: float = world.player_hp
    world.simulate(0.2, Vector2.ZERO)
    expect(world.coins > coins_before and world.xp > xp_before and world.player_hp > hp_before, "contact pickups still work during the cleanup window")
    expect(not world.wave_closing and not world.shop_open, "collecting drops during cleanup does not end the wave")
    world.queue_free()

func check_settlement_after_window_discards_leftovers() -> void:
    var world = prepare_world("settle")
    var boss: Dictionary = begin_live_boss(world)
    if boss.is_empty():
        world.queue_free()
        return
    world.hurt_enemy(boss, 20000.0, "powder", true, Vector2.RIGHT)
    world.clear_enemies()
    world.coins = 7
    world.xp = 1.0
    world.pickups.clear()
    world.chest_marks.clear()
    world.spawn_loot({"coin": 5, "xp": 4}, world.player_position + Vector2(420, 80))
    world.chest_marks = [{"position": world.player_position + Vector2(-360, 140), "age": 0.0}]
    var leftover: int = world.pickups.size()
    expect(leftover > 0, "far leftover drops exist before the cleanup window ends")
    advance_live(world, 29.9)
    expect(not world.wave_closing and not world.shop_open and world.pickups.size() == leftover and world.chest_marks.size() == 1, "the field stays live and uncollected until the full thirty seconds elapse")
    expect(world.hud.timer_label.text.contains("最后"), "the last ten seconds of cleanup use the urgent countdown")
    world.simulate(0.2, Vector2.ZERO)
    expect(world.wave_closing and not world.shop_open and world.pickups.size() == leftover and world.chest_marks.size() == 1, "settlement pause still does not vacuum leftover drops")
    world.simulate(world.WAVE_BUFFER + 0.01, Vector2.ZERO)
    expect(world.shop_open and not world.wave_closing and world.pickups.is_empty() and world.chest_marks.is_empty(), "after the cleanup window and finish pause, leftover pickups and chests are discarded")
    expect(world.coins == 7 and is_equal_approx(world.xp, 1.0), "discarded leftovers never enter the wallet or experience total")
    world.queue_free()

func check_mid_cleanup_save_restores_timer() -> void:
    var world = prepare_world("save")
    var boss: Dictionary = begin_live_boss(world)
    if boss.is_empty():
        world.queue_free()
        return
    world.hurt_enemy(boss, 20000.0, "powder", true, Vector2.RIGHT)
    world.simulate(8.0, Vector2.ZERO)
    expect(not world.wave_closing and not world.shop_open and world.boss_clear_left < 23.0 and world.boss_clear_left > 21.0, "eight seconds of cleanup leaves about twenty-two seconds")
    var remaining: float = world.boss_clear_left
    var saved: Dictionary = world.SessionState.capture(world)
    expect(saved.has("boss_clear_left") and is_equal_approx(float(saved["boss_clear_left"]), remaining), "mid-cleanup captures the remaining timer")
    expect(world.save_store.write_run(saved).ok, "mid-cleanup state can be written")
    world.boss_clear_left = 30.0
    world.coins = 0
    expect(world.continue_game(), "a mid-cleanup run can be continued")
    expect(world.boss_defeated and not world.wave_closing and not world.shop_open, "continue stays in live cleanup combat")
    expect(is_equal_approx(world.boss_clear_left, remaining), "continue restores the remaining cleanup time rather than restarting or skipping it")
    world.xp_needed = 99999
    world.invulnerable = 999.0
    world.chest_queue = 0
    for runtime in world.weapon_runtime.values():
        runtime["cooldown"] = 99.0
    advance_live(world, remaining - 0.05)
    expect(not world.wave_closing and not world.shop_open, "restored leftover time is not consumed twice")
    world.simulate(0.2, Vector2.ZERO)
    world.simulate(world.WAVE_BUFFER + 0.01, Vector2.ZERO)
    expect(world.shop_open and not world.wave_closing, "settlement proceeds after the restored remainder plus the finish pause")

    # Old saves that already marked the Boss dead but have no cleanup field close immediately.
    var world_old = prepare_world("oldsave")
    var old_boss: Dictionary = begin_live_boss(world_old)
    if old_boss.is_empty():
        world.queue_free()
        world_old.queue_free()
        return
    var old_state: Dictionary = world_old.SessionState.capture(world_old)
    old_state["boss_defeated"] = true
    old_state.erase("boss_clear_left")
    expect(world_old.SessionState.apply(world_old, old_state), "an old Boss-defeated save can still be applied")
    expect(world_old.boss_defeated and is_zero_approx(world_old.boss_clear_left), "missing cleanup time is treated as already expired")
    world_old.simulate(0.01, Vector2.ZERO)
    expect(world_old.wave_closing or world_old.shop_open, "an old mid-combat Boss-defeated save closes on the next frame")
    world.queue_free()
    world_old.queue_free()

func check_normal_waves_unchanged() -> void:
    var world = prepare_world("normal")
    world.clear_enemies()
    world.coins = 4
    world.xp = 2.0
    world.spawn_loot({"coin": 6, "xp": 5}, world.player_position + Vector2(400, 0))
    world.chest_marks = [{"position": world.player_position + Vector2(0, 260), "age": 0.0}]
    world.wave_elapsed = 29.99
    world.spawn_clock = 999.0
    world.simulate(0.02, Vector2.ZERO)
    expect(world.wave_closing and not world.shop_open and not world.boss_round, "normal waves still end at the thirty-second mark")
    expect(world.pickups.size() > 0 and world.chest_marks.size() == 1 and world.coins == 4, "normal wave end does not vacuum leftover drops")
    world.simulate(world.WAVE_BUFFER + 0.01, Vector2.ZERO)
    expect(world.shop_open and world.pickups.is_empty() and world.chest_marks.is_empty() and world.coins == 4 and is_equal_approx(world.xp, 2.0), "uncollected normal-wave leftovers are still discarded with no absorb")
    world.queue_free()
