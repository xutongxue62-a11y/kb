extends SceneTree

var checks: int = 0
var failures: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func _initialize() -> void:
    var script = load("res://src/main.gd")
    var methods: Array = []
    for method in script.get_script_method_list():
        methods.append(method["name"])
    expect(methods.has("end_round") and methods.has("buy_shop_item") and methods.has("leave_shop") and methods.has("begin_round") and methods.has("save_game") and methods.has("continue_game"), "coin shops, untimed Boss rounds and real save/continue integration are not implemented")
    if failures > 0:
        finish()
        return
    call_deferred("run_checks")

func run_checks() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/campaign_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.start_run(false)
    expect(world.xp_needed >= 8, "opening experience growth is slower than the three-kill prototype")
    world.toggle_pause()
    world.toggle_stats()
    expect(world.stats_open and world.paused,"character stats can open from the pause menu")
    world.toggle_stats()
    expect(world.paused and world.hud.screen=="pause","closing pause-opened stats returns to pause instead of unexpectedly resuming combat")
    world.toggle_pause()
    world.clear_enemies()
    world.pickups.append({"kind":"coin", "position":world.player_position, "value":5})
    world.update_pickups(1.0)
    expect(world.coins == 5 and is_zero_approx(world.xp), "collecting a gold drop changes wallet without granting experience")
    world.spawn_enemy("hunter", world.player_position + Vector2(70, 0))
    world.stats["crit_chance"] = 0.0
    world.hurt_enemy(world.enemies[0], 100.0, "sling", false, Vector2.RIGHT)
    expect(world.pickups.any(func(item): return item.get("kind", "xp") == "coin") and world.pickups.any(func(item): return item.get("kind", "xp") == "xp"), "actual kills produce both gold and experience drops")
    world.clear_enemies()
    world.pickups.clear()
    world.coins = 0
    world.xp = 2.0
    for runtime in world.weapon_runtime.values():
        runtime["cooldown"] = 99.0
    world.spawn_enemy("hunter", world.player_position + Vector2(220, -40))
    world.wave_elapsed = 29.99
    world.spawn_clock = 999.0
    var loadout: Array = world.inventory.duplicate(true)
    world.simulate(0.02, Vector2.ZERO)
    world.simulate(world.WAVE_BUFFER+0.01,Vector2.ZERO)
    expect(world.shop_open and not world.upgrade_pending and world.wave == 1, "ordinary round end opens a shop instead of giving a free growth choice")
    expect(world.enemies.is_empty(), "remaining field enemies vanish before the camp shop opens")
    expect(is_equal_approx(world.xp, 2.0) and world.coins == 0, "dismissed leftover enemies grant no automatic rewards")
    expect(world.effects.particles.is_empty(), "wave-end combat effects are cleared before the camp shop opens")
    expect(not world.is_loadout_visible(), "orbiting weapons are hidden before the camp shop opens")
    expect(world.player_frozen, "the survivor stops moving when the wave ends")
    expect(world.projectiles.is_empty() and world.burning_fields.is_empty(), "world projectiles and fields do not linger into the camp shop")
    expect(not world.wave_closing and is_zero_approx(world.wave_buffer), "completed settlement enters camp after consuming its freeze buffer")
    expect(world.inventory == loadout and world.buff_levels.is_empty(), "round completion itself grants no equipment or passive upgrades")
    var clock: float = world.elapsed
    world.simulate(2.0, Vector2.RIGHT)
    expect(world.elapsed == clock, "shop freezes battle and movement time")
    # Random stock may start with healing while the hero is already at full HP.
    # Select an actually usable offer before asserting the purchase contract.
    var purchase_index: int = -1
    for index in range(world.shop_stock.size()):
        if world.shop_stock[index]["id"] != "heal":
            purchase_index = index
            break
    expect(purchase_index >= 0, "the six-item shop has a usable non-healing offer")
    expect(not world.buy_shop_item(purchase_index) and world.coins == 0, "unaffordable purchase cannot charge gold or grant an item")
    world.coins = 100
    var cost: int = world.shop_stock[purchase_index]["price"]
    expect(world.buy_shop_item(purchase_index) and world.coins == 100 - cost and world.shop_stock[purchase_index]["sold"], "buying a valid offer grants it once and charges its displayed price")
    var wallet: int = world.coins
    expect(not world.buy_shop_item(purchase_index) and world.coins == wallet, "sold offers cannot charge or grant twice")
    expect(world.shop_stock.size() == 6, "camp generates six distinct random legal offers")
    # Healing now competes in the random pool; inject a concrete offer to test its purchase rules.
    var heal_index: int = world.shop_stock.size()
    world.shop_stock.append({"id":"heal", "price":10, "sold":false})
    world.player_hp = world.stats["max_hp"]
    expect(not world.buy_shop_item(heal_index), "full-health treatment cannot waste coins")
    world.player_hp = 7.0
    expect(world.buy_shop_item(heal_index) and world.player_hp <= world.stats["max_hp"], "paid healing never exceeds maximum health")
    world.leave_shop()
    expect(world.wave == 2 and not world.shop_open and is_zero_approx(world.wave_elapsed) and is_equal_approx(world.xp, 2.0), "leaving camp starts the next timed round and preserves earned XP")
    expect(world.effects.particles.is_empty(), "the next wave starts without leftover combat effects")
    expect(world.is_loadout_visible() and not world.player_frozen, "the next wave shows weapons again and unfreezes the survivor")
    world.demo = true
    world.begin_round(5)
    world.simulate(0.56,Vector2.ZERO)
    var boss: Dictionary = {}
    for enemy in world.enemies:
        if enemy["kind"] == "boss":
            boss = enemy
    expect(world.boss_round and not boss.is_empty(), "every fifth round creates an actual Boss encounter")
    boss["hp"] = 10000.0
    boss["max_hp"] = 10000.0
    for index in range(400):
        world.simulate(0.1, Vector2.ZERO)
    expect(world.wave == 5 and world.boss_round and not world.shop_open and world.wave_elapsed > 30.0, "a living Boss prevents timed advancement even after thirty seconds")
    world.hurt_enemy(boss, 20000.0, "powder", true, Vector2.RIGHT)
    world.demo = false
    world.invulnerable = 999.0
    world.simulate(0.01, Vector2.ZERO)
    expect(world.boss_defeated and not world.wave_closing and not world.shop_open and world.running, "Boss death does not immediately close the wave or open the shop")
    expect(world.boss_clear_left > 29.0, "Boss death starts a thirty-second cleanup window")
    world.xp_needed = 99999
    var cleanup_guard: int = 0
    while world.boss_clear_left > 0.05 and not world.wave_closing and not world.shop_open and cleanup_guard < 80:
        cleanup_guard += 1
        if world.upgrade_pending:
            world.on_choice(world.upgrade_choices[0])
            continue
        world.chest_queue = 0
        world.simulate(minf(0.5, world.boss_clear_left - 0.05), Vector2.ZERO)
    expect(not world.wave_closing and not world.shop_open and world.boss_defeated, "cleanup combat continues until the thirty-second window ends")
    if world.upgrade_pending:
        world.on_choice(world.upgrade_choices[0])
    world.simulate(0.2, Vector2.ZERO)
    expect(world.wave_closing and not world.shop_open, "settlement starts only after the cleanup window")
    world.simulate(world.WAVE_BUFFER+0.01,Vector2.ZERO)
    var choices_resolved: int=0
    while world.upgrade_pending and choices_resolved<32:
        world.on_choice(world.upgrade_choices[0])
        choices_resolved+=1
    expect(world.shop_open and world.wave == 5 and not world.upgrade_pending, "defeating Boss resolves earned XP/chest rewards before opening its paid shop")
    expect(world.coins >= wallet, "gold already collected before settlement remains in the shop wallet")
    world.start_run(false)
    world.coins = 37
    world.apply_buff("armor")
    world.player_hp = 6.5
    world.wave_elapsed = 12.25
    world.grant_weapon("spear")
    var saved = world.save_game()
    expect(saved, "manual saving reports actual success")
    world.coins = 0
    world.player_hp = 1.0
    world.buff_levels.clear()
    expect(world.continue_game(), "a real saved run can be continued")
    expect(world.coins == 37 and is_equal_approx(world.player_hp, 6.5) and world.buff_levels.get("armor", 0) == 1 and is_equal_approx(world.wave_elapsed, 12.25), "continue restores gold, health, Buffs and round clock")
    expect(world.inventory.any(func(item): return item["id"] == "spear") and world.weapon_views.has("spear"), "continue rebuilds saved new-weapon nodes")
    world.end_round()
    world.coins = 100
    world.buy_shop_item(0)
    var sold: Array = world.shop_stock.duplicate(true)
    world.set_autosave(false)
    world.save_game()
    world.leave_shop()
    world.continue_game()
    expect(world.shop_open and same_stock(world.shop_stock, sold), "manual camp save with autosave disabled preserves stock and sold-state without free rerolls")
    world.go_home()
    world.toggle_stats()
    expect(world.hud.screen=="stats","returning home from a shop leaves the character-attributes entry usable")
    if world.stats_open:
        world.toggle_stats()
    world.continue_game()
    world.set_autosave(true)
    var saved_stage: int = world.wave + 1
    world.leave_shop()
    world.coins = 0
    world.continue_game()
    expect(world.wave==saved_stage and not world.shop_open,"autosave-enabled departure correctly continues from the latest round rather than an older manual camp save")
    var working_store = world.save_store
    var blocked_path: String = "res://runtime/tests/blocked_home_"+str(Time.get_ticks_usec())
    var blocker: FileAccess = FileAccess.open(blocked_path,FileAccess.WRITE)
    blocker.store_string("owned test fixture")
    blocker.close()
    world.save_store = load("res://src/save_store.gd").new(blocked_path)
    var normal_inventory: Array = world.inventory.duplicate(true)
    var normal_wave: int = world.wave
    world.start_run(true,"new")
    expect(not world.trial_mode and world.running and world.inventory==normal_inventory and world.wave==normal_wave,"failed campaign save aborts F2/F3 trial entry without clearing the normal run")
    if world.trial_mode:
        world.start_run(false)
    world.go_home()
    expect(world.running,"an actual save failure keeps the current run alive instead of discarding it on return home")
    world.save_store = working_store
    world.running = true
    world.finish_run(false)
    expect(not world.save_store.has_run() and not world.continue_game(),"completed run records cannot revive an unfinished backup")
    world.start_run(false)
    world.set_autosave(false)
    world.save_game()
    world.finish_run(false)
    expect(not world.save_store.has_run() and not world.continue_game(),"death records the end of a run even when automatic progress saving is disabled")
    world.queue_free()
    await process_frame
    finish()

func finish() -> void:
    print("CAMPAIGN RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)

func same_stock(actual: Array, expected: Array) -> bool:
    if actual.size() != expected.size():
        return false
    for index in range(actual.size()):
        for key in ["id", "price", "sold"]:
            if actual[index][key] != expected[index][key]:
                return false
        if not is_equal_approx(float(actual[index].get("probability", 0.0)), float(expected[index].get("probability", 0.0))):
            return false
    return true
