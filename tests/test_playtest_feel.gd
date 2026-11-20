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
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/playtest_feel_" + suffix + "_" + str(Time.get_ticks_usec()))
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

func clear_field(world) -> void:
    for enemy in world.enemies:
        if enemy.has("view") and is_instance_valid(enemy["view"]):
            enemy["view"].queue_free()
    world.enemies.clear()
    world.projectiles.clear()
    if world.effects != null:
        world.effects.particles.clear()

func set_level(world, weapon_id: String, level: int) -> void:
    for item in world.inventory:
        if str(item.get("id", "")) == weapon_id:
            item["level"] = level
            return
    world.inventory.append({"id": weapon_id, "level": level})

func freeze_weapons(world) -> void:
    for runtime in world.weapon_runtime.values():
        runtime["cooldown"] = 99.0
    world.spawn_clock = 999.0

func clear_push_lane(world, distance: float = 90.0) -> Dictionary:
    var directions: Array = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]
    for direction in directions:
        var at: Vector2 = world.player_position + direction * distance
        var along: Vector2 = world.map_view.move_body(at, at + direction * 70.0, 22.0)
        if along.distance_to(at) >= 55.0:
            return {"point": at, "direction": direction}
    return {"point": world.player_position + Vector2(0, -120), "direction": Vector2.UP}


func run_checks() -> void:
    check_attack_feel()
    check_pickup_radius()
    check_staff_ward()
    check_thunder_ward()
    check_spawns()
    check_vfx_helpers()
    await check_rope_layout()
    print("PLAYTEST FEEL RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)

func check_attack_feel() -> void:
    var catalog = load("res://src/catalog.gd")
    var expected := {
        "club": [7.0, 0.28],
        "axe": [12.0, 0.38],
        "blade": [7.0, 0.14],
        "sling": [2.6, 0.30],
        "powder": [4.2, 0.82],
        "staff": [1.6, 0.54],
        "spear": [7.4, 0.52],
        "hammer": [13.0, 0.90],
        "boomerang": [3.6, 0.76],
        "totem": [2.8, 0.68],
        "bonebow": [4.0, 0.64],
        "firepot": [2.2, 1.60],
        "wardrum": [3.2, 1.26],
        "crystal": [5.8, 1.66]
    }
    for key in expected.keys():
        var data: Dictionary = catalog.WEAPONS[key]
        expect(is_equal_approx(float(data["damage"]), expected[key][0]), key + " base damage matches the snappier cadence")
        expect(is_equal_approx(float(data["cooldown"]), expected[key][1]), key + " base interval matches the snappier cadence")
    expect(float(catalog.WEAPONS["hammer"]["cooldown"]) > float(catalog.WEAPONS["blade"]["cooldown"]), "hammer stays slower than blade")
    expect(float(catalog.WEAPONS["axe"]["cooldown"]) > float(catalog.WEAPONS["club"]["cooldown"]), "axe stays slower than club")
    expect(float(catalog.WEAPONS["powder"]["cooldown"]) > float(catalog.WEAPONS["sling"]["cooldown"]), "cannon stays slower than sling")
    expect(is_equal_approx(load("res://src/progression.gd").HIT_CAP_RATIO, 0.70), "incoming combat damage cap stays at 70 percent")

func check_pickup_radius() -> void:
    var growth = load("res://src/growth.gd")
    var rules = load("res://src/rules.gd")
    expect(str(growth.BUFFS["explorer"]["description"]).contains("拾取范围 +30"), "explorer card quotes the reduced +30 radius")
    var levels := {"explorer": 1}
    expect(is_equal_approx(growth.stats(levels)["pickup_radius"], 130.0), "one explorer stack is +30, not +50")
    expect(is_equal_approx(rules.magnet_wave_bonus(1), 0.0), "wave 1 has no extra magnet bonus")
    expect(is_equal_approx(rules.magnet_wave_bonus(9), 60.0), "wave 9 magnet bonus is 10 per step, not 18")
    expect(is_equal_approx(rules.magnet_wave_bonus(20), 100.0), "magnet wave bonus still caps after ten steps")
    var world = prepare_world("magnet")
    world.wave = 1
    expect(is_equal_approx(world.pickup_magnet_radius(), float(world.stats["pickup_radius"])), "early magnet equals the explorer/base radius")
    world.wave = 9
    expect(is_equal_approx(world.pickup_magnet_radius(), float(world.stats["pickup_radius"]) + 60.0), "later waves still extend magnet range, but less than before")
    world.queue_free()

func check_staff_ward() -> void:
    var rules = load("res://src/rules.gd")
    var profile: Dictionary = rules.ward_profile("staff", 1)
    expect(is_equal_approx(float(profile["distance"]), 54.0) and is_equal_approx(float(profile["duration"]), 0.20), "staff 喝退 is a short, fixed shove")
    expect(is_equal_approx(float(profile["interval"]), 0.70) and is_equal_approx(float(profile["target_cooldown"]), 1.55), "staff 喝退 has an interval and a per-target cooldown")
    var world = prepare_world("staff_ward")
    clear_field(world)
    if not world.grant_weapon("staff") and not load("res://src/catalog.gd").inventory_ids(world.inventory).has("staff"):
        expect(false, "staff ward fixture can own a staff")
        world.queue_free()
        return
    freeze_weapons(world)
    var lane: Dictionary = clear_push_lane(world)
    world.spawn_enemy("hunter", lane["point"])
    var enemy: Dictionary = world.enemies.back()
    enemy["hp"] = 200.0
    enemy["max_hp"] = 200.0
    enemy["speed_multiplier"] = 0.0
    var start: Vector2 = enemy["position"]
    world.hurt_enemy(enemy, 0.2, "staff", false, lane["direction"])
    expect(bool(enemy.get("ward_moving", false)) or float(enemy.get("ward_left", 0.0)) > 0.0, "a staff hit applies 喝退 instead of a long flee")
    world.simulate(0.22, Vector2.ZERO)
    var travelled: float = enemy["position"].distance_to(start)
    expect(travelled > 24.0 and travelled < 80.0, "staff 喝退 travels a short distance only, not off-screen")
    expect(world.visible_world_rect().grow(8.0).has_point(enemy["position"]), "staff 喝退 keeps the monster on-screen")
    var after_first: Vector2 = enemy["position"]
    var ready_at: float = float(enemy.get("ward_ready", 0.0))
    world.hurt_enemy(enemy, 0.2, "staff", false, Vector2.RIGHT)
    expect(is_equal_approx(float(enemy.get("ward_ready", 0.0)), ready_at), "the same monster cannot be 喝退 again before its cooldown")
    world.simulate(0.22, Vector2.ZERO)
    expect(enemy["position"].distance_to(after_first) < 20.0, "a repeated staff hit during cooldown does not shove the same monster again")
    world.spawn_enemy("hunter", world.player_position + Vector2(0, 90))
    var other: Dictionary = world.enemies.back()
    other["hp"] = 200.0
    other["max_hp"] = 200.0
    other["speed_multiplier"] = 0.0
    var other_start: Vector2 = other["position"]
    world.hurt_enemy(other, 0.2, "staff", false, Vector2.DOWN)
    expect(is_equal_approx(float(other.get("ward_left", 0.0)), 0.0), "global 喝退 interval blocks a second target immediately")
    world.elapsed = float(world.ward_ready.get("staff", 0.0)) + 0.01
    world.hurt_enemy(other, 0.2, "staff", false, Vector2.DOWN)
    expect(float(other.get("ward_left", 0.0)) > 0.0, "a new target can be 喝退 after the interval")
    world.queue_free()

func check_thunder_ward() -> void:
    var rules = load("res://src/rules.gd")
    expect(is_equal_approx(float(rules.ward_profile("thunder", 1)["distance"]), 0.0), "base totem tiers do not yet 喝退 enchanted hits")
    expect(is_equal_approx(float(rules.ward_profile("thunder", 3)["distance"]), 28.0), "advanced thunder 喝退 is milder than staff")
    expect(is_equal_approx(float(rules.ward_profile("thunder", 5)["distance"]), 40.0), "awakened thunder 喝退 is stronger than advanced, still shorter than staff")
    expect(float(rules.ward_profile("thunder", 5)["distance"]) < float(rules.ward_profile("staff", 1)["distance"]), "even awakened thunder stays milder than staff 喝退")
    var world = prepare_world("thunder_ward")
    clear_field(world)
    var catalog = load("res://src/catalog.gd")
    expect(world.grant_weapon("totem") or catalog.inventory_ids(world.inventory).has("totem"), "thunder ward fixture owns a totem")
    expect(world.grant_weapon("axe") or catalog.inventory_ids(world.inventory).has("axe"), "thunder ward fixture owns an axe")
    world.select_link("thunder_axe")
    expect(world.has_active_link("thunder_axe"), "axe can be thunder-enchanted for 喝退")
    set_level(world, "totem", 3)
    freeze_weapons(world)
    var lane: Dictionary = clear_push_lane(world)
    world.spawn_enemy("hunter", lane["point"])
    var enemy: Dictionary = world.enemies.back()
    enemy["hp"] = 200.0
    enemy["max_hp"] = 200.0
    enemy["speed_multiplier"] = 0.0
    var start: Vector2 = enemy["position"]
    world.hurt_enemy(enemy, 0.2, "axe", false, lane["direction"])
    world.simulate(0.18, Vector2.ZERO)
    var advanced: float = enemy["position"].distance_to(start)
    expect(advanced > 12.0 and advanced < 50.0, "advanced thunder 喝退 is a short shove")
    world.queue_free()

    var late = prepare_world("thunder_wake")
    clear_field(late)
    expect(late.grant_weapon("totem") or catalog.inventory_ids(late.inventory).has("totem"), "awakened thunder fixture owns a totem")
    expect(late.grant_weapon("axe") or catalog.inventory_ids(late.inventory).has("axe"), "awakened thunder fixture owns an axe")
    late.select_link("thunder_axe")
    set_level(late, "totem", 5)
    freeze_weapons(late)
    var late_lane: Dictionary = clear_push_lane(late)
    late.spawn_enemy("hunter", late_lane["point"])
    var target: Dictionary = late.enemies.back()
    target["hp"] = 200.0
    target["max_hp"] = 200.0
    target["speed_multiplier"] = 0.0
    var late_start: Vector2 = target["position"]
    late.hurt_enemy(target, 0.2, "axe", false, late_lane["direction"])
    late.simulate(0.18, Vector2.ZERO)
    var awakened: float = target["position"].distance_to(late_start)
    expect(awakened > advanced and awakened < 70.0, "awakened thunder 喝退 travels farther than advanced, still a short distance")
    late.queue_free()

func check_spawns() -> void:
    var rules = load("res://src/rules.gd")
    expect(is_equal_approx(rules.spawn_interval(1), 0.46), "wave 1 spawns faster than the old 0.62 cadence")
    expect(is_equal_approx(rules.spawn_interval(3), 0.32), "wave 3 interval is 0.32")
    expect(is_equal_approx(rules.spawn_interval(10), maxf(0.14, 0.32 - 7.0 * 0.008)), "mid-game interval keeps falling")
    expect(is_equal_approx(rules.spawn_interval(40), 0.14), "late-game interval floors at 0.14")
    expect(is_equal_approx(rules.spawn_interval_for(5, true, false), rules.spawn_interval(5)), "a live Boss stage uses the same spawn interval as a normal stage")
    expect(rules.spawn_interval_for(5, true, true) < rules.spawn_interval(5), "after the Boss dies, spawning is a bit denser, not frozen")
    expect(rules.enemy_limit_for(1) == 50, "early alive cap starts at 50")
    expect(rules.enemy_limit_for(10) == 66, "wave 10 alive cap is 66")
    expect(rules.enemy_limit_for(26) == 106, "late-game alive cap keeps growing past the old wave-26 plateau")
    expect(rules.enemy_limit_for(40) == 156, "wave 40 alive cap reaches 156")
    var world = prepare_world("spawns")
    world.begin_round(5)
    world.invulnerable = 999.0
    world.xp_needed = 99999
    world.simulate(0.56, Vector2.ZERO)
    expect(world.boss_round and not world.boss_defeated, "spawn check is on a live Boss stage")
    expect(is_equal_approx(Rules_from_world_interval(world), rules.spawn_interval(5)), "world Boss-stage cadence matches the normal stage formula")
    var boss: Dictionary = {}
    for enemy in world.enemies:
        if enemy["kind"] == "boss":
            boss = enemy
            break
    expect(not boss.is_empty(), "Boss is present for the continuation check")
    if not boss.is_empty():
        world.hurt_enemy(boss, 20000.0, "powder", true, Vector2.RIGHT)
        world.simulate(0.01, Vector2.ZERO)
        var after_death: int = world.enemies.size()
        world.spawn_clock = 0.0
        world.simulate(0.3, Vector2.ZERO)
        expect(world.boss_defeated and not world.wave_closing, "cleanup window stays live")
        expect(world.enemies.size() > after_death, "the pipeline keeps brushing after the Boss dies")
    world.queue_free()

func Rules_from_world_interval(world) -> float:
    return world.Rules.spawn_interval_for(world.wave, world.boss_round, world.boss_defeated)

func check_vfx_helpers() -> void:
    var visuals = load("res://src/battle_visuals.gd")
    var base: Color = visuals.staff_tint(0)
    var advanced: Color = visuals.staff_tint(1)
    var awakened: Color = visuals.staff_tint(2)
    expect(base.b > base.r and awakened.r > base.r + 0.2 and awakened.g < base.g, "awakened staff shots shift from cyan toward purple")
    expect(advanced.b > base.b * 0.5 and advanced.r > base.r, "advanced staff shots already pick up violet")
    expect(visuals.staff_tint(2) != visuals.staff_tint(0), "staff combat VFX changes with evolution tier")

func check_rope_layout() -> void:
    var world = prepare_world("ropes")
    var catalog = load("res://src/catalog.gd")
    for weapon_id in ["staff", "powder", "sling", "axe"]:
        expect(world.grant_weapon(weapon_id) or catalog.inventory_ids(world.inventory).has(weapon_id), "rope fixture owns " + weapon_id)
    expect(world.open_link_pack(), "rope fixture can open the pack")
    var ui = world.hud.link_pack if world.hud != null else null
    expect(ui != null and ui.has_method("rope_knot_for"), "the pack UI is available for rope layout")
    if ui == null:
        world.queue_free()
        return
    var first: Dictionary = ui.try_drop("staff", "powder")
    var second: Dictionary = ui.try_drop("staff", "sling")
    expect(first.get("ok", false) and second.get("ok", false), "staff can hook powder and sling at once")
    await process_frame
    await process_frame
    var shell: Control = ui.result_control("rune_shell")
    var bolt: Control = ui.result_control("rune_sling")
    expect(shell != null and bolt != null, "both result nodes hang on the board")
    if shell == null or bolt == null:
        world.queue_free()
        return
    var shell_knot: Vector2 = ui.rope_knot_for("rune_shell")
    var bolt_knot: Vector2 = ui.rope_knot_for("rune_sling")
    var shell_anchor: Vector2 = Vector2(shell.position.x + shell.size.x * 0.5, shell.position.y + shell.size.y)
    var bolt_anchor: Vector2 = Vector2(bolt.position.x + bolt.size.x * 0.5, bolt.position.y + bolt.size.y)
    expect(shell_knot.distance_to(shell_anchor) <= 1.5, "魔法炮 knot sits on the result node")
    expect(bolt_knot.distance_to(bolt_anchor) <= 1.5, "符能弹 knot sits on the result node")
    var staff_card: Control = ui.cards.get("staff", null)
    var powder_card: Control = ui.cards.get("powder", null)
    var sling_card: Control = ui.cards.get("sling", null)
    expect(staff_card != null and powder_card != null and sling_card != null, "rope cards are present")
    if staff_card != null and powder_card != null:
        var staff_x: float = staff_card.position.x + staff_card.size.x * 0.5
        var powder_x: float = powder_card.position.x + powder_card.size.x * 0.5
        expect(shell_knot.x >= minf(staff_x, powder_x) - 8.0 and shell_knot.x <= maxf(staff_x, powder_x) + 8.0, "魔法炮 node stays on the staff-powder spoke")
        expect(absf(shell_knot.x - powder_x) < absf(shell_knot.x - staff_x) + 1.0, "魔法炮 node sits closer to its host than to the shared catalyst")
    if staff_card != null and sling_card != null:
        var staff_x2: float = staff_card.position.x + staff_card.size.x * 0.5
        var sling_x: float = sling_card.position.x + sling_card.size.x * 0.5
        expect(bolt_knot.x >= minf(staff_x2, sling_x) - 8.0 and bolt_knot.x <= maxf(staff_x2, sling_x) + 8.0, "符能弹 node stays on the staff-sling spoke")
        expect(absf(bolt_knot.x - sling_x) < absf(bolt_knot.x - staff_x2) + 1.0, "符能弹 node sits closer to its host than to the shared catalyst")
    expect(absf(shell_knot.x - bolt_knot.x) > 20.0, "two catalyst spokes do not stack their result nodes on the same x")
    world.queue_free()
