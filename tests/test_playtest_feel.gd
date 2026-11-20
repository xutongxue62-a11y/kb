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
    check_awakened_skills()
    check_enchant_color_hooks()
    check_boss_stage_matches_normal()
    check_stage_clear_hp()
    check_late_balance()
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
    var catalog = load("res://src/catalog.gd")
    var details = load("res://src/ui_weapon_details.gd")
    var profile: Dictionary = rules.ward_profile("staff", 5)
    expect(str(profile.get("kind", "none")) == "none" and is_equal_approx(float(profile["duration"]), 0.0), "the staff has no special CC at any level")
    expect(not str(catalog.WEAPONS["staff"]["description"]).contains("喝退"), "staff catalog copy no longer mentions 喝退")
    expect(not details.attack("staff", 1).contains("喝退") and not details.attack("staff", 5).contains("喝退"), "staff hover text does not describe knockback or 喝退")
    var world = prepare_world("staff_ward")
    clear_field(world)
    if not world.grant_weapon("staff") and not catalog.inventory_ids(world.inventory).has("staff"):
        expect(false, "staff fixture can own a staff")
        world.queue_free()
        return
    set_level(world, "staff", 5)
    freeze_weapons(world)
    var lane: Dictionary = clear_push_lane(world)
    world.spawn_enemy("hunter", lane["point"])
    var enemy: Dictionary = world.enemies.back()
    enemy["hp"] = 200.0
    enemy["max_hp"] = 200.0
    enemy["speed_multiplier"] = 0.0
    var start: Vector2 = enemy["position"]
    world.hurt_enemy(enemy, 0.2, "staff", false, lane["direction"])
    expect(not bool(enemy.get("paralyzed", false)) and is_equal_approx(float(enemy.get("ward_left", 0.0)), 0.0), "a staff hit does not paralyze or 喝退")
    world.simulate(0.25, Vector2.ZERO)
    expect(enemy["position"].distance_to(start) < 8.0, "a staff hit does not shove the monster away")
    # Awakened 符阵 is damage-only.
    world.spawn_enemy("hunter", world.player_position + Vector2(40, 0))
    var near: Dictionary = world.enemies.back()
    near["hp"] = 200.0
    near["max_hp"] = 200.0
    var before: float = near["hp"]
    var before_pos: Vector2 = near["position"]
    world.weapon_runtime["staff"]["nova_cooldown"] = 0.0
    world.update_rune_nova(0.05, true)
    expect(near["hp"] < before, "awakened 符阵 still deals damage")
    expect(not bool(near.get("paralyzed", false)) and near["position"].distance_to(before_pos) < 8.0, "符阵 does not paralyze or knock back")
    world.queue_free()

func check_thunder_ward() -> void:
    var rules = load("res://src/rules.gd")
    var catalog = load("res://src/catalog.gd")
    expect(str(rules.ward_profile("thunder", 1).get("kind", "none")) == "none", "base totem tiers do not yet paralyze")
    var advanced: Dictionary = rules.ward_profile("thunder", 3)
    var awakened: Dictionary = rules.ward_profile("thunder", 5)
    expect(str(advanced.get("kind", "")) == "paralyze" and is_equal_approx(float(advanced["duration"]), 0.28), "advanced thunder roots in place for a brief 0.28s")
    expect(is_equal_approx(float(advanced["interval"]), 2.5) and bool(advanced.get("once", false)), "thunder paralysis uses a global interval and may only root a monster once")
    expect(is_equal_approx(float(rules.PARALYZE_BOSS_DURATION), 0.12), "boss paralysis is shorter than the ordinary root")
    expect(is_equal_approx(float(advanced["distance"]), 0.0) and is_equal_approx(float(awakened["duration"]), float(advanced["duration"])), "awakened thunder does not shove farther; it stays an in-place root")
    expect(str(catalog.WEAPONS["totem"]["description"]).contains("麻痹") and str(catalog.WEAPONS["totem"]["description"]).contains("一生仅一次"), "totem catalog mentions once-per-life paralysis")
    var world = prepare_world("thunder_ward")
    clear_field(world)
    expect(world.grant_weapon("totem") or catalog.inventory_ids(world.inventory).has("totem"), "thunder fixture owns a totem")
    expect(world.grant_weapon("axe") or catalog.inventory_ids(world.inventory).has("axe"), "thunder fixture owns an axe")
    world.select_link("thunder_axe")
    expect(world.has_active_link("thunder_axe"), "axe can be thunder-enchanted for paralysis")
    set_level(world, "totem", 3)
    freeze_weapons(world)
    world.spawn_enemy("hunter", world.player_position + Vector2(80, 0))
    var enemy: Dictionary = world.enemies.back()
    enemy["hp"] = 200.0
    enemy["max_hp"] = 200.0
    enemy["speed_multiplier"] = 1.0
    var start: Vector2 = enemy["position"]
    expect(world.try_apply_ward(enemy, "thunder"), "an advanced thunder hit can paralyze")
    expect(bool(enemy.get("paralyzed", false)) and str(enemy.get("ward_kind", "")) == "paralyze", "thunder applies in-place paralysis, not a shove")
    expect(bool(enemy.get("paralyzed_once", false)), "a successful root marks the monster for life")
    world.simulate(0.14, Vector2.ZERO)
    expect(enemy["position"].distance_to(start) < 6.0, "a paralyzed monster stays in place instead of running away")
    expect(bool(enemy.get("paralyzed", false)) or float(enemy.get("ward_left", 0.0)) > 0.0, "the brief root is still active at 0.14s")
    expect(not world.try_apply_ward(enemy, "thunder"), "a second thunder hit cannot re-root the same monster")
    # After the root ends, the same monster must never be paralyzed again.
    enemy["ward_left"] = 0.0
    enemy["paralyzed"] = false
    enemy["ward_kind"] = ""
    world.elapsed += 20.0
    world.ward_ready["thunder"] = world.elapsed - 0.01
    expect(not world.try_apply_ward(enemy, "thunder"), "the same monster can never be paralyzed a second time")
    expect(bool(enemy.get("paralyzed_once", false)) and not bool(enemy.get("paralyzed", false)), "the once-per-life flag survives after the root expires")
    world.queue_free()

    # Global interval: a second monster is not instantly rooted.
    var pack = prepare_world("thunder_interval")
    clear_field(pack)
    expect(pack.grant_weapon("totem") or catalog.inventory_ids(pack.inventory).has("totem"), "interval fixture owns a totem")
    expect(pack.grant_weapon("axe") or catalog.inventory_ids(pack.inventory).has("axe"), "interval fixture owns an axe")
    pack.select_link("thunder_axe")
    set_level(pack, "totem", 5)
    freeze_weapons(pack)
    pack.spawn_enemy("hunter", pack.player_position + Vector2(70, 0))
    var first: Dictionary = pack.enemies.back()
    first["hp"] = 200.0
    first["max_hp"] = 200.0
    pack.spawn_enemy("hunter", pack.player_position + Vector2(0, 80))
    var second: Dictionary = pack.enemies.back()
    second["hp"] = 200.0
    second["max_hp"] = 200.0
    expect(pack.try_apply_ward(first, "thunder"), "the first thunder target can be paralyzed")
    expect(not pack.try_apply_ward(second, "thunder"), "the global interval blocks immediately paralyzing another monster")
    pack.elapsed = float(pack.ward_ready.get("thunder", 0.0)) + 0.01
    expect(pack.try_apply_ward(second, "thunder"), "a new target can be paralyzed after the global interval")
    pack.queue_free()

func check_spawns() -> void:
    var rules = load("res://src/rules.gd")
    expect(is_equal_approx(rules.spawn_interval(1), 0.40), "wave 1 cadence is tighter for a 割草 feel")
    expect(is_equal_approx(rules.spawn_interval(3), 0.32), "wave 3 interval is 0.32")
    expect(is_equal_approx(rules.spawn_interval(10), maxf(0.14, 0.32 - 7.0 * 0.008)), "mid-game interval keeps falling")
    expect(is_equal_approx(rules.spawn_interval(40), 0.14), "late-game interval floors at 0.14")
    expect(is_equal_approx(rules.spawn_interval_for(5, true, false), rules.spawn_interval(5)), "a live Boss stage uses the same spawn interval as a normal stage")
    expect(is_equal_approx(rules.spawn_interval_for(5, true, true), rules.spawn_interval(5)), "after the Boss dies, the spawn interval stays the same as a normal stage")
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
    expect(visuals.staff_tint(1) == visuals.staff_tint(0), "staff and rune shots stay cyan/blue through level 4")
    expect(visuals.staff_tint(2) != visuals.staff_tint(0), "only 觉醒 (level 5+) staff shots turn purple")
    expect(not visuals.WEAPON_ORBIT_RINGS, "orbiting weapons no longer draw rotating wrap or aura rings")
    expect(visuals.weapon_enchant_modulate("rune", 1) == visuals.weapon_enchant_modulate("rune", 0), "rune-enchanted views also stay blue until 觉醒")
    expect(visuals.fire_tint(2).r >= visuals.fire_tint(0).r and visuals.fire_tint(2).g < visuals.fire_tint(0).g, "later fire upgrades shift toward a hotter crimson")
    expect(visuals.thunder_tint(2).g >= visuals.thunder_tint(0).g and visuals.thunder_tint(2).b >= visuals.thunder_tint(0).b, "later thunder upgrades shift toward a brighter white-blue")
    var rune_shell := {"enchanted": true, "vfx_tier": 2}
    var fire_shell := {"fire_enchanted": true, "fire_tier": 2}
    var thunder_shell := {"thunder_enchanted": true, "thunder_tier": 2}
    expect(visuals._shot_body_color(rune_shell, Color.WHITE) == visuals.staff_tint(2), "rune-enchanted shells use the staff purple at awakened tier")
    expect(visuals._shot_body_color(fire_shell, Color.WHITE) == visuals.fire_tint(2), "fire-enchanted shells use the later fire tint")
    expect(visuals._shot_body_color(thunder_shell, Color.WHITE) == visuals.thunder_tint(2), "thunder-enchanted shots use the later thunder tint")
    expect(visuals.weapon_enchant_modulate("fire", 2) != Color.WHITE, "fire-enchanted weapon views pick up a visible fire tint")
    expect(visuals.weapon_enchant_modulate("rune", 2) != visuals.weapon_enchant_modulate("rune", 0), "rune-enchanted views shift toward purple at later staff tiers")

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

func check_awakened_skills() -> void:
    var evolution = load("res://src/weapon_evolution.gd")
    expect(not evolution.sky_lightning_unlocked(4), "天雷 stays locked before level 5")
    expect(evolution.sky_lightning_unlocked(5), "天雷 unlocks at the awakened totem tier")
    var sky: Dictionary = evolution.sky_lightning_profile(5)
    expect(is_equal_approx(float(sky["cooldown"]), 9.0) and float(sky["damage_multiplier"]) > 5.0, "天雷 is a long-cooldown, high-damage strike")
    expect(float(sky["radius"]) >= 80.0 and float(sky["height"]) >= 200.0, "天雷 falls from above with a wide blast")
    expect(not evolution.fire_pillar_unlocked(4) and evolution.fire_pillar_unlocked(5), "炎柱 unlocks at firepot level 5")
    expect(not evolution.rune_nova_unlocked(4) and evolution.rune_nova_unlocked(5), "符阵轰击 unlocks at staff level 5")
    var catalog = load("res://src/catalog.gd")
    var world = prepare_world("sky_lightning")
    clear_field(world)
    expect(world.grant_weapon("totem") or catalog.inventory_ids(world.inventory).has("totem"), "天雷 fixture owns a totem")
    set_level(world, "totem", 5)
    world.sync_idle_loadout()
    freeze_weapons(world)
    world.spawn_enemy("hunter", world.player_position + Vector2(90, 0))
    var enemy: Dictionary = world.enemies.back()
    enemy["hp"] = 400.0
    enemy["max_hp"] = 400.0
    var before: float = enemy["hp"]
    world.update_armory(0.08)
    expect(enemy["hp"] < before, "awakened totem 天雷 damages the marked cluster")
    expect(world.armory.states.has("totem") and float(world.armory.states["totem"].get("sky_cooldown", 0.0)) >= 8.0, "天雷 then enters its long cooldown")
    world.armory.states["totem"]["cooldown"] = 99.0
    var mid_hp: float = enemy["hp"]
    var mid_cd: float = float(world.armory.states["totem"].get("sky_cooldown", 0.0))
    world.update_armory(1.0)
    expect(is_equal_approx(enemy["hp"], mid_hp), "天雷 does not strike again during the cooldown")
    expect(float(world.armory.states["totem"].get("sky_cooldown", 0.0)) < mid_cd and float(world.armory.states["totem"].get("sky_cooldown", 0.0)) > 6.5, "the 天雷 cooldown keeps ticking but stays long")
    world.queue_free()

    var staff_world = prepare_world("rune_nova")
    clear_field(staff_world)
    expect(staff_world.grant_weapon("staff") or catalog.inventory_ids(staff_world.inventory).has("staff"), "符阵 fixture owns a staff")
    set_level(staff_world, "staff", 5)
    staff_world.sync_idle_loadout()
    freeze_weapons(staff_world)
    staff_world.spawn_enemy("hunter", staff_world.player_position + Vector2(40, 0))
    var near: Dictionary = staff_world.enemies.back()
    near["hp"] = 200.0
    near["max_hp"] = 200.0
    var staff_before: float = near["hp"]
    staff_world.update_rune_nova(0.05, true)
    expect(near["hp"] < staff_before, "awakened staff 符阵轰击 damages nearby enemies")
    expect(float(staff_world.weapon_runtime["staff"].get("nova_cooldown", 0.0)) >= 7.0, "符阵轰击 then waits on a long cooldown")
    staff_world.queue_free()

    var pot_world = prepare_world("fire_pillar")
    clear_field(pot_world)
    expect(pot_world.grant_weapon("firepot") or catalog.inventory_ids(pot_world.inventory).has("firepot"), "炎柱 fixture owns a firepot")
    set_level(pot_world, "firepot", 5)
    pot_world.sync_idle_loadout()
    freeze_weapons(pot_world)
    pot_world.spawn_enemy("hunter", pot_world.player_position + Vector2(80, 0))
    var burned: Dictionary = pot_world.enemies.back()
    burned["hp"] = 300.0
    burned["max_hp"] = 300.0
    var pot_before: float = burned["hp"]
    pot_world.update_armory(0.08)
    expect(burned["hp"] < pot_before, "awakened firepot 炎柱 damages the aimed cluster")
    expect(pot_world.armory.states.has("firepot") and float(pot_world.armory.states["firepot"].get("pillar_cooldown", 0.0)) >= 7.0, "炎柱 then enters its long cooldown")
    pot_world.queue_free()

func check_enchant_color_hooks() -> void:
    var catalog = load("res://src/catalog.gd")
    var rune_world = prepare_world("rune_colors")
    clear_field(rune_world)
    for weapon_id in ["staff", "powder", "sling"]:
        expect(rune_world.grant_weapon(weapon_id) or catalog.inventory_ids(rune_world.inventory).has(weapon_id), "rune color fixture owns " + weapon_id)
    set_level(rune_world, "staff", 5)
    rune_world.apply_links(["rune_shell", "rune_sling"])
    expect(rune_world.Rules.host_is_rune_enchanted(rune_world.active_links, "powder"), "powder is rune-enchanted for color checks")
    expect(rune_world.projectile_vfx_tier("powder", true) == 2, "rune-enchanted cannon shells use the awakened staff purple tier")
    expect(rune_world.projectile_vfx_tier("sling", true) == 2, "rune-enchanted sling stones use the awakened staff purple tier")
    rune_world.fire_projectile(rune_world.player_position, Vector2.RIGHT, "powder", 4.0, 200.0, false, true)
    expect(not rune_world.projectiles.is_empty() and int(rune_world.projectiles.back().get("vfx_tier", 0)) == 2, "a fired rune shell stores the staff vfx tier")
    rune_world.queue_free()

    var fire_world = prepare_world("fire_colors")
    clear_field(fire_world)
    for weapon_id in ["firepot", "powder", "sling"]:
        expect(fire_world.grant_weapon(weapon_id) or catalog.inventory_ids(fire_world.inventory).has(weapon_id), "fire color fixture owns " + weapon_id)
    set_level(fire_world, "firepot", 5)
    fire_world.apply_links(["fire_cannon"])
    expect(fire_world.Rules.host_is_fire_enchanted(fire_world.active_links, "powder"), "powder is fire-enchanted for 烈焰火炮")
    expect(fire_world.projectile_fire_tier("powder") == 2, "烈焰火炮 shells use the awakened firepot tint tier")
    fire_world.fire_projectile(fire_world.player_position, Vector2.RIGHT, "powder", 4.0, 200.0, false, false)
    expect(not fire_world.projectiles.is_empty() and bool(fire_world.projectiles.back().get("fire_enchanted", false)), "a fired cannon shell is tagged as fire-enchanted")
    expect(int(fire_world.projectiles.back().get("fire_tier", 0)) == 2, "the fired cannon shell stores the later fire tint tier")
    fire_world.queue_free()

    var storm_world = prepare_world("thunder_colors")
    clear_field(storm_world)
    for weapon_id in ["totem", "powder", "sling"]:
        expect(storm_world.grant_weapon(weapon_id) or catalog.inventory_ids(storm_world.inventory).has(weapon_id), "thunder color fixture owns " + weapon_id)
    set_level(storm_world, "totem", 5)
    storm_world.apply_links(["thunder_shell"])
    expect(storm_world.Rules.host_is_thunder_enchanted(storm_world.active_links, "powder"), "powder is thunder-enchanted for 导雷火炮")
    expect(storm_world.projectile_thunder_tier("powder") == 2, "thunder-enchanted shells use the awakened totem tint tier")
    storm_world.fire_projectile(storm_world.player_position, Vector2.RIGHT, "powder", 4.0, 200.0, false, false)
    expect(bool(storm_world.projectiles.back().get("thunder_enchanted", false)) and int(storm_world.projectiles.back().get("thunder_tier", 0)) == 2, "a fired thunder shell stores the later thunder tint")
    storm_world.queue_free()

func check_boss_stage_matches_normal() -> void:
    var roster = load("res://src/enemy_roster.gd")
    var rules = load("res://src/rules.gd")
    for wave in [4, 5, 9, 10]:
        var normal: Array = roster.spawn_pool(wave, 16.0, false, false)
        var boss: Array = roster.spawn_pool(wave, 16.0, false, true)
        normal.sort()
        boss.sort()
        expect(normal == boss, "wave %d Boss minion pool matches the normal stage" % wave)
        expect(is_equal_approx(rules.spawn_interval_for(wave, true, false), rules.spawn_interval(wave)), "wave %d live Boss interval matches normal" % wave)
        expect(is_equal_approx(rules.spawn_interval_for(wave, true, true), rules.spawn_interval(wave)), "wave %d post-Boss interval still matches normal" % wave)
    expect(roster.spawn_pool(5, 16.0, false, true).has("bonecaller"), "a grove Boss stage still includes heavy bonecallers")
    expect(roster.spawn_pool(9, 16.0, false, true).has("basaltroller"), "a volcano Boss stage still includes heavy basaltrollers")
    expect(roster.spawn_pool(4, 16.0, false, true).has("armored"), "an early Boss stage still includes armored heavies")
    expect(not roster.spawn_pool(5, 16.0, false, true).has("boss"), "the Boss itself is never a random regular pick")
    var world = prepare_world("boss_match")
    world.begin_round(5)
    world.invulnerable = 999.0
    world.xp_needed = 99999
    world.simulate(0.56, Vector2.ZERO)
    expect(world.boss_round and not world.boss_defeated, "composition check is on a live Boss stage")
    expect(is_equal_approx(world.Rules.spawn_interval_for(world.wave, true, false), world.Rules.spawn_interval(5)), "live Boss world cadence matches a normal wave 5")
    expect(world.enemy_limit() == world.Rules.enemy_limit_for(5), "Boss-stage on-screen cap matches the same-wave normal cap")
    var boss := {}
    var minion_kinds := {}
    for enemy in world.enemies:
        if enemy["kind"] == "boss":
            boss = enemy
        else:
            minion_kinds[str(enemy["kind"])] = true
    expect(not boss.is_empty(), "the extra threat on the stage is the Boss itself")
    var allowed: Array = roster.spawn_pool(5, world.wave_elapsed, world.trial_mode, false)
    for kind in minion_kinds:
        expect(allowed.has(kind), "Boss-stage minion " + str(kind) + " also belongs on a normal wave 5")
    if not boss.is_empty():
        world.hurt_enemy(boss, 20000.0, "powder", true, Vector2.RIGHT)
        world.simulate(0.01, Vector2.ZERO)
        var after_death: int = world.enemies.size()
        var post_interval: float = world.Rules.spawn_interval_for(world.wave, world.boss_round, world.boss_defeated)
        expect(is_equal_approx(post_interval, world.Rules.spawn_interval(5)), "cleanup cadence stays on the normal-stage interval")
        world.spawn_clock = 0.0
        world.simulate(post_interval + 0.05, Vector2.ZERO)
        expect(world.boss_defeated and not world.wave_closing, "cleanup window stays live after the Boss dies")
        expect(world.enemies.size() > after_death, "the normal-stage pipeline keeps spawning after the Boss dies")
        expect(not world.enemies.any(func(enemy): return enemy["kind"] == "boss" and float(enemy.get("hp", 0.0)) > 0.0), "cleanup still does not spawn another Boss")
    world.queue_free()

func pick_non_vitality(world) -> String:
    for key in world.upgrade_choices:
        if str(key) != "vitality":
            return str(key)
    return str(world.upgrade_choices[0]) if not world.upgrade_choices.is_empty() else ""

func check_stage_clear_hp() -> void:
    var growth = load("res://src/growth.gd")
    var session = load("res://src/session_state.gd")
    expect(is_equal_approx(growth.stage_hp_bonus(0), 0.0), "no cleared stages add no extra health pips")
    expect(is_equal_approx(growth.stage_hp_bonus(1), 1.0), "the first cleared stage adds one max HP")
    expect(is_equal_approx(growth.stage_hp_bonus(5), 5.0), "each further cleared stage adds another pip")
    expect(is_equal_approx(growth.stats({}, 0)["max_hp"], 8.0), "base max HP with no clears stays 8")
    expect(is_equal_approx(growth.stats({}, 3)["max_hp"], 11.0), "three cleared stages have 11 max HP before vitality")
    var world = prepare_world("stage_hp")
    world.refresh_stats()
    var start_max: float = float(world.stats["max_hp"])
    expect(world.player_level == 1 and world.stage_hp_bonus == 0, "a new run starts with no stage-clear HP bonus")
    # XP level-up must not raise max or current HP.
    world.player_hp = start_max
    world.xp = world.xp_needed
    world.present_upgrade("xp")
    expect(world.upgrade_pending and not world.upgrade_choices.is_empty(), "gaining enough XP presents a level-up choice")
    world.on_choice(pick_non_vitality(world))
    expect(world.player_level == 2, "taking the upgrade raises the player level")
    expect(is_equal_approx(float(world.stats["max_hp"]), start_max), "XP level-up no longer adds maximum HP")
    expect(is_equal_approx(world.player_hp, start_max), "XP level-up does not add a current HP pip")
    # Full bar: clearing a stage adds a filled pip.
    world.grant_stage_clear_hp()
    expect(world.stage_hp_bonus == 1, "clearing a stage records one bonus pip")
    expect(is_equal_approx(float(world.stats["max_hp"]), start_max + 1.0), "clearing a stage adds 1 maximum HP")
    expect(is_equal_approx(world.player_hp, start_max + 1.0), "a full bar gains a filled new pip")
    expect(is_equal_approx(world.hud.current_max_hp, start_max + 1.0), "the health bar maximum visibly gains the new pip")
    expect(world.hud.health_label.text.contains("%.0f" % (start_max + 1.0)), "the health label shows the raised maximum")
    world.grant_stage_clear_hp()
    expect(world.stage_hp_bonus == 1, "the same wave cannot grant the bonus twice")
    # Injured: later clear adds one current HP, not a full heal.
    world.wave = 2
    world.player_hp = float(world.stats["max_hp"]) - 3.0
    var injured: float = world.player_hp
    var injured_max: float = float(world.stats["max_hp"])
    world.grant_stage_clear_hp()
    expect(world.stage_hp_bonus == 2, "the next wave can grant another pip")
    expect(is_equal_approx(float(world.stats["max_hp"]), injured_max + 1.0), "the second cleared stage adds another max HP pip")
    expect(is_equal_approx(world.player_hp, injured + 1.0), "an injured clear restores only the new pip, not a full heal")
    # A later XP level-up still must not add leftover player_level HP.
    world.xp = world.xp_needed
    world.present_upgrade("xp")
    expect(world.upgrade_pending and not world.upgrade_choices.is_empty(), "a second level-up can be presented")
    world.on_choice(pick_non_vitality(world))
    expect(world.player_level == 3, "the second upgrade reaches level 3")
    expect(is_equal_approx(float(world.stats["max_hp"]), injured_max + 1.0), "a later XP level-up still does not add max HP")
    # Mid-run save keeps the bonus; leftover player_level does not recreate it.
    var snap: Dictionary = session.capture(world)
    var saved_bonus: int = world.stage_hp_bonus
    var saved_max: float = float(world.stats["max_hp"])
    var saved_hp: float = world.player_hp
    world.queue_free()
    var restored = prepare_world("stage_hp_restore")
    expect(session.apply(restored, snap), "a mid-run save can be restored")
    expect(restored.stage_hp_bonus == saved_bonus, "the stage-clear bonus is restored")
    expect(is_equal_approx(float(restored.stats["max_hp"]), saved_max), "restored max HP keeps the cleared-stage pips")
    expect(is_equal_approx(restored.player_hp, saved_hp), "restored current HP is not lost")
    restored.player_level = 9
    restored.refresh_stats()
    expect(is_equal_approx(float(restored.stats["max_hp"]), saved_max), "leftover player_level does not grant extra max HP")
    restored.queue_free()
    # The actual 过关 hook, and begin_round jumping ahead, must not invent bonuses.
    var closer = prepare_world("stage_hp_close")
    var close_max: float = float(closer.stats["max_hp"])
    closer.player_hp = close_max
    closer.start_wave_closing()
    expect(closer.stage_hp_bonus == 1 and is_equal_approx(float(closer.stats["max_hp"]), close_max + 1.0), "start_wave_closing grants the stage-clear pip")
    expect(is_equal_approx(closer.player_hp, close_max + 1.0), "a full bar is filled when the stage actually closes")
    closer.start_wave_closing()
    expect(closer.stage_hp_bonus == 1, "a second close of the same wave does not stack")
    closer.queue_free()
    var jumper = prepare_world("stage_hp_jump")
    var jump_max: float = float(jumper.stats["max_hp"])
    jumper.begin_round(5)
    expect(jumper.stage_hp_bonus == 0 and is_equal_approx(float(jumper.stats["max_hp"]), jump_max), "starting a later wave without clearing does not invent prior pips")
    jumper.queue_free()

func check_late_balance() -> void:
    var progression = load("res://src/progression.gd")
    var rules = load("res://src/rules.gd")
    var first: Dictionary = progression.enemy_profile(1, "hunter")
    var fifth: Dictionary = progression.enemy_profile(5, "hunter")
    var eighth: Dictionary = progression.enemy_profile(8, "hunter")
    var twentieth: Dictionary = progression.enemy_profile(20, "hunter")
    var thirtieth: Dictionary = progression.enemy_profile(30, "hunter")
    expect(is_equal_approx(first["hp"], 5.0) and is_equal_approx(first["damage"], 1.0), "wave 1 hunter HP and damage stay at the opening baseline")
    var old5_hp: float = 5.0 * exp(4.0 * log(1.10) + log(1.45))
    var old5_dmg: float = (1.0 + 0.06 * 4.0) * exp(log(1.18))
    expect(is_equal_approx(fifth["hp"], old5_hp) and is_equal_approx(fifth["damage"], old5_dmg), "wave 5 hunter growth is unchanged")
    var old8_hp: float = 5.0 * exp(7.0 * log(1.10) + log(1.45))
    expect(is_equal_approx(eighth["hp"], old8_hp), "wave 8 still follows the original HP curve")
    var old20_hp: float = 5.0 * exp(19.0 * log(1.10) + 4.0 * log(1.45))
    var old20_dmg: float = (1.0 + 0.06 * 19.0) * exp(3.0 * log(1.18) + log(1.10))
    expect(twentieth["hp"] > old20_hp * 2.2, "wave 20 hunter HP is substantially above the previous curve")
    expect(twentieth["damage"] > old20_dmg * 1.6, "wave 20 hunter damage is substantially above the previous curve")
    var old30_hp: float = 5.0 * exp(29.0 * log(1.10) + 6.0 * log(1.45))
    expect(thirtieth["hp"] > old30_hp * 8.0, "wave 30 hunter HP ramps much harder in the late game")
    expect(is_equal_approx(progression.outgoing_damage_scale(1), 1.0) and is_equal_approx(progression.outgoing_damage_scale(8), 1.0), "player damage is unchanged through wave 8")
    expect(progression.outgoing_damage_scale(16) < 0.90 and progression.outgoing_damage_scale(30) <= 0.73, "mid-to-late outgoing player damage is gently reduced")
    expect(is_equal_approx(rules.BURN_TICK_SCALE, 0.50), "burn and residual DoT ticks are halved")
    var world = prepare_world("burn_scale")
    var pot_level: int = maxi(1, world.weapon_level("firepot"))
    world._spawn_attachment_fire(world.player_position, "sling")
    expect(not world.burning_fields.is_empty(), "a fire attachment leaves a burning field")
    var expected_burn: float = 0.55 * (1.0 + float(pot_level - 1) * 0.25) * rules.BURN_TICK_SCALE
    expect(is_equal_approx(float(world.burning_fields[0]["damage"]), expected_burn), "attachment burn uses the lowered tick scale")
    world.burning_fields.clear()
    world.explode_powder({"position": world.player_position, "damage": 10.0, "enchanted": false, "fire_enchanted": true})
    var powder_field: Dictionary = {}
    for field in world.burning_fields:
        if str(field.get("residual", "")) == "fire":
            powder_field = field
            break
    expect(not powder_field.is_empty() and is_equal_approx(float(powder_field["damage"]), 10.0 * 0.16 * rules.BURN_TICK_SCALE), "fire-cannon residual burn is halved")
    world.stats["crit_chance"] = 0.0
    world.wave = 30
    world.spawn_enemy("hunter", world.player_position + Vector2(80, 0))
    var enemy: Dictionary = world.enemies.back()
    enemy["hp"] = 100.0
    enemy["max_hp"] = 100.0
    enemy["dodge"] = 0.0
    world.hurt_enemy(enemy, 10.0, "sling", false, Vector2.RIGHT)
    var expected: float = 10.0 * float(world.stats["damage_multiplier"]) * progression.outgoing_damage_scale(30)
    expect(is_equal_approx(enemy["hp"], 100.0 - expected), "late-wave outgoing player damage uses the reduced scale")
    world.queue_free()
