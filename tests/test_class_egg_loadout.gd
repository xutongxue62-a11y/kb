extends SceneTree

const Catalog = preload("res://src/catalog.gd")
const Rules = preload("res://src/rules.gd")
const Main = preload("res://src/main.gd")
const SaveStore = preload("res://src/save_store.gd")

var checks: int = 0
var failures: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func make_world() -> Node:
    var world = Main.new()
    world.save_store = SaveStore.new("res://runtime/tests/class_egg_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.demo = true
    return world

func _initialize() -> void:
    call_deferred("run_checks")

func run_checks() -> void:
    check_battle_sprites()
    check_egg_smash_and_hatch()
    check_weapon_layout_and_draw_order()
    print("RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)

func check_battle_sprites() -> void:
    var world = make_world()
    for id in Catalog.CHARACTER_ORDER:
        world.character_id = id
        world.start_run(false)
        expect(world.hero.character_id == id, "in-battle actor follows character_id: " + id)
        var path: String = world.hero.body_resource_path()
        expect(path == str(Catalog.character(id).body), "battle body matches the current character configuration: " + id)
    world.character_id = "barbarian"
    world.start_run(true)
    expect(world.hero.character_id == "caveman", "trial mode does not apply a class battle sprite")
    expect(world.hero.body_resource_path() == str(Catalog.character("caveman").body), "trial mode keeps the current default hunter body")
    expect(is_equal_approx(float(world.stats.get("damage_multiplier", 1.0)), 1.0) and is_equal_approx(float(world.stats.get("reduction", 0.0)), 0.0), "trial mode still skips class modifiers")
    world.queue_free()

func check_egg_smash_and_hatch() -> void:
    var world = make_world()
    world.start_run(true)
    for enemy in world.enemies:
        if is_instance_valid(enemy.get("view")):
            enemy["view"].queue_free()
    world.enemies.clear()
    world.pickups.clear()
    world.coins = 0
    world.xp = 0.0
    world.kills = 0
    world.spawn_enemy("hunter", world.player_position + Vector2(240, 0), false, "egg")
    var egg: Dictionary = world.enemies.back()
    egg["dodge"] = 0.0
    expect(str(egg.get("state", "")) == "egg", "smash test starts with an unhatched egg")
    var before_count: int = world.enemies.size()
    world.hurt_enemy(egg, 100000.0, "powder", true, Vector2.RIGHT)
    expect(float(egg.get("hp", 1.0)) <= 0.0, "smashing an unhatched egg can kill it in place")
    expect(str(egg.get("state", "")) == "egg", "a smashed egg is not converted into a walking monster")
    var living: int = 0
    for enemy in world.enemies:
        if float(enemy.get("hp", 0.0)) > 0.0:
            living += 1
    expect(living == 0 and world.enemies.size() == before_count, "smashing an unhatched egg spawns no child enemies")
    expect(world.pickups.size() >= 2, "smashing an unhatched egg drops loot")
    var gold: float = 0.0
    var experience: float = 0.0
    for drop in world.pickups:
        if str(drop.get("kind", "xp")) == "coin":
            gold += float(drop["value"])
        else:
            experience += float(drop["value"])
    world.collect_all_drops()
    expect(world.coins > 0 and gold > 0.0, "smashed unhatched egg grants gold")
    expect(world.xp > 0.0 and experience > 0.0, "smashed unhatched egg grants experience")
    world.pickups.clear()
    world.spawn_enemy("hunter", world.player_position + Vector2(220, 40), false, "egg")
    var pending: Dictionary = world.enemies.back()
    expect(float(pending.get("timer", 0.0)) >= Rules.EGG_HATCH_MIN and float(pending.get("timer", 0.0)) <= Rules.EGG_HATCH_MAX, "unhatched eggs start with a slower hatch timer")
    expect(Rules.EGG_HATCH_MIN >= 3.5 and Rules.EGG_CRACK_TIME >= 0.8 and Rules.EGG_CRACK_TIME < Rules.EGG_HATCH_MIN, "the crack telegraph plays before a slower hatch")
    expect(Rules.EGG_ARRIVAL_CHANCE > 0.30 and Rules.EGG_ARRIVAL_CHANCE <= 0.55, "egg arrival chance is raised without flooding the wave")
    pending["timer"] = Rules.EGG_CRACK_TIME * 0.6
    world.update_enemies(0.05)
    expect(str(pending.get("state", "")) == "egg", "an egg stays unhatched while the crack telegraph is playing")
    expect(is_instance_valid(pending.get("view")) and float(pending["view"].crack_progress) > 0.2, "the shell shows a crack telegraph before hatching")
    expect(world.effects.has_method("egg_crack"), "crack telegraph is a dedicated short-lived effect")
    # Smash during the telegraph still drops loot and spawns no children.
    var mid_count: int = world.enemies.size()
    world.pickups.clear()
    world.coins = 0
    world.xp = 0.0
    pending["dodge"] = 0.0
    world.hurt_enemy(pending, 100000.0, "powder", true, Vector2.RIGHT)
    var mid_living: int = 0
    for enemy in world.enemies:
        if float(enemy.get("hp", 0.0)) > 0.0:
            mid_living += 1
    expect(mid_living == 0 and world.enemies.size() == mid_count, "smashing a cracking egg still spawns no child enemies")
    world.collect_all_drops()
    expect(world.coins > 0 and world.xp > 0.0, "smashing a cracking egg still grants gold and experience")
    world.pickups.clear()
    world.spawn_enemy("hunter", world.player_position + Vector2(200, -30), false, "egg")
    var ripe: Dictionary = world.enemies.back()
    ripe["timer"] = 0.01
    world.update_enemies(0.05)
    expect(str(ripe.get("state", "")) == "walk", "an unsmashed egg still hatches when its timer elapses after the telegraph")
    expect(float(ripe.get("hp", 0.0)) > 0.0, "a naturally hatched egg becomes a living monster")
    world.queue_free()

func check_weapon_layout_and_draw_order() -> void:
    var world = make_world()
    world.start_run(true)
    var ids: Array = ["club", "axe", "blade", "sling", "powder", "staff"]
    world.clear_weapons()
    for key in ids:
        world.grant_weapon(key)
    world.formation_phase = 0.0
    world.collapsed = false
    world.sync_idle_loadout()
    var slots: Array = Rules.loadout_slots(6)
    expect(slots == [0, 1, 2, 3, 4, 5], "six carried weapons fill left-up, left-mid, left-down, right-up, right-mid, right-down")
    var melee_radius: float = 0.0
    var ranged_radius: float = 0.0
    for index in range(ids.size()):
        var key: String = ids[index]
        var offset: Vector2 = world.weapon_views[key].position - world.player_position
        var expected: Vector2 = Rules.loadout_offset(index, 6, 0.0, key, false)
        expect(offset.distance_to(expected) < 2.5, "weapon sits in its six-slot orbit: " + key)
        if Rules.is_parked_weapon(key):
            ranged_radius = offset.length()
            expect(offset.length() <= Rules.PARKED_MAX_ANCHOR, "parked weapon stays on the close carry rows: " + key)
            expect(offset.length() >= 28.0, "parked weapon is not glued to the torso center: " + key)
        else:
            melee_radius = offset.length()
            expect(is_equal_approx(offset.length(), Rules.MELEE_ORBIT), "melee orbit stays on the readable outer radius: " + key)
    expect(ranged_radius >= 28.0 and melee_radius - ranged_radius >= 36.0, "parked carry rows retain a clear gap inside the closer melee orbit ring")
    expect(Rules.MELEE_ORBIT - Rules.PARKED_RADIUS >= 48.0 and Rules.PARKED_RADIUS <= 46.0, "compact parked weapons remain by the hands inside the closer melee ring")
    for key in Catalog.IDS:
        var text: String = str(Catalog.WEAPONS[key].get("description", ""))
        var parked_pos: Vector2 = Rules.loadout_offset(3, 6, 0.0, key, false)
        var later_pos: Vector2 = Rules.loadout_offset(3, 6, 1.25, key, false)
        if Rules.orbits_with_formation(key):
            expect(str(Catalog.WEAPONS[key].get("kind", "")) == "melee" or text.contains("环绕"), "orbiting weapons are catalog melee or described as circling: " + key)
            expect(parked_pos.distance_to(later_pos) > 8.0, "true melee still orbits with the formation: " + key)
            expect(is_equal_approx(parked_pos.length(), Rules.MELEE_ORBIT), "orbiting melee uses the farther radius: " + key)
        else:
            expect(str(Catalog.WEAPONS[key].get("kind", "")) != "melee" and not text.contains("环绕"), "parked weapons are not circling melee: " + key)
            expect(parked_pos.is_equal_approx(later_pos), "non-melee stays in its assigned slot when the formation advances: " + key)
            expect(parked_pos.length() <= Rules.PARKED_MAX_ANCHOR, "parked weapon uses a close readable row: " + key)
    expect(Rules.is_parked_weapon("hammer") and not Rules.orbits_with_formation("hammer"), "the magic/area stone hammer does not orbit")
    expect(Rules.is_parked_weapon("totem") and Rules.is_parked_weapon("wardrum"), "lightning totem and war drum stay parked as instruments, not circling melee")
    expect(Rules.is_parked_weapon("spear") and Rules.is_parked_weapon("boomerang"), "thrust spear and thrown boomerang stay parked")
    expect(Rules.orbits_with_formation("club") and Rules.orbits_with_formation("axe") and Rules.orbits_with_formation("blade"), "club, axe, and blade remain the circling melee set")
    var before_melee: Dictionary = {}
    var before_ranged: Dictionary = {}
    for key in ids:
        if Rules.is_parked_weapon(key):
            before_ranged[key] = world.weapon_views[key].position
        else:
            before_melee[key] = world.weapon_views[key].position
    world.update_weapons(0.25, false)
    world.sync_idle_loadout()
    for key in before_melee:
        expect(world.weapon_views[key].position.distance_to(before_melee[key]) > 8.0, "melee weapons still orbit as a formation: " + key)
    for key in before_ranged:
        expect(world.weapon_views[key].position.distance_to(before_ranged[key]) < 2.5, "ranged weapons stay parked in their assigned slots: " + key)
    # Two parked weapons fill 左中 / 右中 and should rest at the hands.
    world.clear_weapons()
    world.grant_weapon("sling")
    world.grant_weapon("staff")
    world.formation_phase = 0.0
    world.collapsed = false
    world.sync_idle_loadout()
    var left_hand: Vector2 = world.hero.rest["left_hand"]
    var right_hand: Vector2 = world.hero.rest["right_hand"]
    var left_mid: Vector2 = world.weapon_views["sling"].position - world.player_position
    var right_mid: Vector2 = world.weapon_views["staff"].position - world.player_position
    expect(left_mid.distance_to(left_hand) <= 14.0, "左中 parked weapon sits at or just off the left hand")
    expect(right_mid.distance_to(right_hand) <= 14.0, "右中 parked weapon sits at or just off the right hand")
    # Restore a mixed loadout that includes melee so draw-order checks can run.
    world.clear_weapons()
    for key in ["club", "axe", "blade", "sling", "powder", "staff"]:
        world.grant_weapon(key)
    world.formation_phase = 0.0
    world.sync_idle_loadout()
    # Force a front/back pair and check draw order against the hero.
    var front_key: String = "club"
    var back_key: String = "axe"
    world.weapon_views[front_key].position = world.player_position + Vector2(0, 80)
    world.weapon_views[back_key].position = world.player_position + Vector2(0, -80)
    world.refresh_weapon_draw_order()
    expect(world.weapon_views[front_key].z_index > world.hero.z_index, "a weapon in front of the hunter draws over the sprite")
    expect(world.weapon_views[back_key].z_index < world.hero.z_index, "a weapon behind the hunter draws under the sprite")
    expect(world.weapons_layer.z_index <= world.hero.z_index, "the weapon layer no longer forces every weapon under the hunter")
    # Drum / totem must not rest under the feet when a loadout includes them.
    world.clear_weapons()
    for key in ["sling", "wardrum", "spear", "club", "totem", "axe"]:
        world.grant_weapon(key)
    world.formation_phase = 0.0
    world.sync_idle_loadout()
    var drum_offset: Vector2 = world.weapon_views["wardrum"].position - world.player_position
    expect(drum_offset.length() >= 28.0 and absf(drum_offset.y) < drum_offset.length() * 0.85, "the drum sits in a side slot rather than under the feet")
    expect(world.weapon_views["wardrum"].z_index >= 8, "the drum participates in front/back draw sorting")
    # Mixed loadout: magic hammer, drum, and totem stay parked; club and axe still orbit.
    world.clear_weapons()
    for key in ["club", "hammer", "totem", "sling", "axe", "wardrum"]:
        world.grant_weapon(key)
    world.formation_phase = 0.0
    world.sync_idle_loadout()
    var parked_before: Dictionary = {}
    var melee_before: Dictionary = {}
    for key in ["club", "hammer", "totem", "sling", "axe", "wardrum"]:
        if Rules.orbits_with_formation(key):
            melee_before[key] = world.weapon_views[key].position
        else:
            parked_before[key] = world.weapon_views[key].position
            var parked_off: Vector2 = world.weapon_views[key].position - world.player_position
            expect(parked_off.length() >= 28.0 and parked_off.length() <= Rules.PARKED_MAX_ANCHOR, "mixed-loadout parked weapon uses the closer carry rows: " + key)
    world.update_weapons(0.25, false)
    world.sync_idle_loadout()
    for key in melee_before:
        expect(world.weapon_views[key].position.distance_to(melee_before[key]) > 8.0, "mixed loadout still orbits true melee: " + key)
    for key in parked_before:
        expect(world.weapon_views[key].position.distance_to(parked_before[key]) < 2.5, "mixed loadout keeps magic hammer and other non-melee parked: " + key)
    world.queue_free()
