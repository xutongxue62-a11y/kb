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
    if node is Label or node is Button:
        result.append(node.text)
    for child in node.get_children():
        result.append_array(labels_under(child))
    return result

func clear_enemies(world: Node) -> void:
    for enemy in world.enemies:
        enemy["view"].queue_free()
    world.enemies.clear()
    world.projectiles.clear()
    world.effects.particles.clear()

func _initialize() -> void:
    var script = load("res://src/main.gd")
    var methods: Array = []
    for method in script.get_script_method_list():
        methods.append(method["name"])
    expect(methods.has("apply_buff") and methods.has("set_start_weapon") and methods.has("toggle_stats") and methods.has("update_companions") and methods.has("update_pickups"), "playtest Buffs, starter selection and follower integration are not implemented")
    if failures > 0:
        finish()
        return
    call_deferred("run_checks")

func run_checks() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/feedback_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    expect(world.hud.screen == "title", "boot opens the title page before the camp homepage")
    world.hud.show_menu("start", 0)
    expect(world.hud.screen == "start" and world.hud.overlay.find_child("EnterCamp", true, false) != null, "home uses Enter Camp to open character select directly")
    world.hud.show_cast()
    expect(labels_under(world.hud.overlay).any(func(text): return "弹弓" in text) and world.hud.overlay.find_child("PrevCharacter", true, false) != null and world.hud.overlay.find_child("NextCharacter", true, false) != null, "single hunter shows its sling and future character navigation")
    world.start_run(false)
    expect(world.inventory.size() == 1 and world.inventory[0]["id"] == "sling", "normal play defaults to one ranged sling")
    world.set_start_weapon("club")
    world.start_run(false)
    expect(world.inventory[0]["id"] == "club", "choosing club changes the actual starter")
    world.set_start_weapon("staff")
    world.start_run(false)
    expect(world.inventory[0]["id"] == "club", "only the two offered basic starters can be selected")
    world.start_run(true)
    var slots_before: int = world.inventory.size()
    expect(world.apply_buff("power") and world.apply_buff("crit_power"), "passive growth applies through the real scene")
    expect(world.inventory.size() == slots_before, "passive growth never consumes or changes a weapon slot")
    clear_enemies(world)
    world.spawn_enemy("tank", world.player_position + Vector2(90, 0))
    world.enemies[0]["hp"] = 100.0
    world.enemies[0]["max_hp"] = 100.0
    world.rng.seed = 12345
    var before: float = world.enemies[0]["hp"]
    world.hurt_enemy(world.enemies[0], 10.0, "sling", false, Vector2.RIGHT)
    var amount: float = before - world.enemies[0]["hp"]
    expect(is_equal_approx(amount, 11.8) or is_equal_approx(amount, 21.83), "generic damage and critical-power Buffs change actual enemy HP")
    expect(world.effects.particles.any(func(item): return item["kind"] == "number" and is_equal_approx(item.get("value", 0.0), amount)), "floating number contains the actual dealt damage")
    world.apply_buff("armor")
    world.invulnerable = 0.0
    world.player_hp = 8.0
    world.hurt_player(Vector2.ZERO)
    expect(is_equal_approx(world.player_hp, 7.12), "12 percent reduction prevents fractional damage from being rounded away")
    world.apply_buff("vitality")
    expect(is_equal_approx(world.stats["max_hp"], 10.0) and world.player_hp > 8.0, "vitality both raises the cap and restores health")
    world.start_run(false)
    clear_enemies(world)
    world.spawn_clock = 999.0
    world.apply_buff("speed")
    var start: Vector2 = world.player_position
    world.simulate(0.1, Vector2.RIGHT)
    expect(is_equal_approx(world.player_position.x - start.x, 24.2), "movement speed Buff changes real displacement")
    world.apply_buff("regen")
    world.player_hp = 5.0
    world.simulate(0.5, Vector2.ZERO)
    expect(is_equal_approx(world.player_hp, 5.06), "regeneration restores health during live battle")
    world.toggle_stats()
    var clock: float = world.elapsed
    start = world.player_position
    world.simulate(0.5, Vector2.RIGHT)
    expect(world.stats_open and world.paused and world.elapsed == clock and world.player_position == start and is_equal_approx(world.player_hp, 5.06), "B panel pauses movement, combat, regeneration and the wave clock")
    expect(labels_under(world.hud.overlay).any(func(text): return "暴击" in text) and labels_under(world.hud.overlay).any(func(text): return "轻盈步伐" in text), "attribute panel shows stats and selected Buff names")
    world.toggle_stats()
    expect(not world.paused and not world.stats_open, "closing attributes resumes combat")
    world.apply_buff("pet")
    world.apply_buff("drone")
    clear_enemies(world)
    world.spawn_enemy("tank", world.player_position + Vector2(100, 20))
    world.enemies[0]["hp"] = 100.0
    before = world.enemies[0]["hp"]
    for index in range(90):
        world.update_companions(1.0 / 60.0)
    expect(world.companions.states.size() == 2 and world.enemies[0]["hp"] < before, "two real followers are present and attack without being weapons")
    var pet_point: Vector2 = world.companions.states["pet"]["position"]
    world.player_position += Vector2(200, 0)
    world.enemies.clear()
    world.update_companions(0.5)
    expect(world.companions.states["pet"]["position"].distance_to(world.player_position) < pet_point.distance_to(world.player_position), "pet follows when the player moves away")
    world.start_run(false)
    expect(world.buff_levels.is_empty() and world.companions.states.is_empty() and world.pickups.is_empty(), "restart removes all run-specific Buffs, followers and experience stones")
    clear_enemies(world)
    world.apply_buff("pet")
    world.prefer_elite = true
    world.spawn_enemy("hunter", world.player_position + Vector2(100, 0))
    world.spawn_enemy("spitter", world.player_position + Vector2(420, 0))
    world.enemies[0]["hp"] = 100.0
    world.enemies[1]["hp"] = 100.0
    world.enemies[1]["elite"] = true
    for index in range(180):
        world.update_companions(1.0 / 60.0)
    expect(world.enemies[0]["hp"] < 100.0, "elite preference cannot starve reachable pet attacks by targeting an elite outside leash-plus-bite reach")
    world.start_run(false)
    clear_enemies(world)
    world.apply_buff("explorer")
    world.pickups.append({"position": world.player_position + Vector2(130, 0), "value": 1.0})
    world.update_pickups(1.0)
    expect(world.pickups.is_empty() and float(world.stats["xp_multiplier"]) >= 1.15 and is_equal_approx(world.xp, float(world.stats["xp_multiplier"])), "explorer collects a stone outside the base radius and grants bonus XP")
    world.present_upgrade()
    var buff_choice: String = ""
    for key in world.upgrade_choices:
        if world.Growth.BUFFS.has(key):
            buff_choice = key
            break
    expect(not buff_choice.is_empty(), "real upgrade screen always offers non-weapon growth")
    slots_before = world.inventory.size()
    world.on_choice(buff_choice)
    expect(not world.upgrade_pending and world.buff_levels.has(buff_choice) and world.inventory.size() == slots_before, "choosing an offered Buff resumes the real game and keeps the loadout")
    world.start_run(false)
    clear_enemies(world)
    world.spawn_clock = 999.0
    world.elapsed = 29.99
    world.wave_elapsed = 29.99
    world.xp = 2.0
    world.simulate(0.02, Vector2.ZERO)
    world.simulate(world.WAVE_BUFFER+0.01,Vector2.ZERO)
    expect(world.wave == 1 and world.shop_open and not world.upgrade_pending, "thirty-second boundary opens a paid shop without a free growth choice")
    world.leave_shop()
    expect(world.wave == 2 and is_equal_approx(world.xp, 2.0), "entering next round from shop preserves earned XP")
    clear_enemies(world)
    world.elapsed = 89.99
    world.invulnerable = 0.0
    world.player_hp = 1.0
    world.projectiles.append({"position": world.player_position, "velocity": Vector2.ZERO, "damage": 1.0, "kind": "hostile", "life": 1.0, "radius": 6.5, "weapon_id": "", "from_combo": false})
    world.simulate(0.02, Vector2.ZERO)
    expect(not world.running and labels_under(world.hud.overlay).has("再来一局"), "fatal hostile projectile on the new ninety-second deadline still beats victory")
    world.start_run(true)
    world.demo = true
    clear_enemies(world)
    world.apply_buff("pierce")
    world.apply_buff("ricochet")
    world.spawn_enemy("tank", world.player_position + Vector2(60, 0))
    world.spawn_enemy("tank", world.player_position + Vector2(140, 0))
    for enemy in world.enemies:
        enemy["hp"] = 100.0
    world.fire_projectile(world.player_position, Vector2.RIGHT, "sling", 2.0, 360.0)
    for index in range(30):
        world.update_projectiles(1.0 / 60.0)
    expect(world.enemies[0]["hp"] < 100.0 and world.enemies[1]["hp"] < 100.0, "pierce/ricochet can damage a second real target")
    expect(world.enemies[0]["hp"] >= 97.0 and world.enemies[1]["hp"] >= 97.0, "one projectile never damages the same target twice")
    world.start_run(true)
    world.demo = false
    world.present_upgrade("trial")
    expect(world.upgrade_pending and world.upgrade_choices.size() == 3, "trial can request mixed growth immediately")
    world.queue_free()
    await process_frame
    finish()

func finish() -> void:
    print("FEEDBACK RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
