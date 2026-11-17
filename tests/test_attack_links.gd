extends SceneTree
const PoseProbe=preload("res://tests/weapon_pose_probe.gd")
var failures: int = 0
var checks: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func check_ranged_torso_clearance(world: Node) -> void:
    world.start_run(true)
    for enemy in world.enemies:
        enemy["view"].queue_free()
    world.enemies.clear()
    world.projectiles.clear()
    var body: Sprite2D = world.hero.parts["body"]
    for key in ["powder", "staff", "sling"]:
        var clear: bool = true
        for index in range(8):
            world.weapon_runtime[key]["aim"] = Vector2.from_angle(float(index) * TAU / 8.0)
            world.weapon_runtime[key]["recoil"] = 0.12
            world.weapon_runtime[key]["glow"] = 0.2
            world.update_weapons(0.0)
            world.apply_weapon_glows(0.0)
            var view: Sprite2D = world.weapon_views[key]
            clear = clear and PoseProbe.torso_overlap_area(body,view)<=2.0
        expect(clear, "opaque rotated ranged art clears the torso during peak recoil and attack glow: " + key)

func _initialize() -> void:
    var rules = load("res://src/rules.gd")
    var names: Array = []
    for method in rules.get_script_method_list():
        names.append(method["name"])
    expect(names.has("ranged_mount") and names.has("link_options") and names.has("link_profile"), "fixed near mounts and optional pair-only attack links are not implemented")
    if failures > 0:
        print("LINK RESULT: %d checks, %d failures" % [checks, failures])
        quit(1)
        return
    var ids = ["club", "axe", "blade", "sling", "powder", "staff"]
    var options: Array = rules.link_options(ids)
    expect(options[0]["id"] == "none", "no-link is always selectable")
    for option in options:
        expect(option["weapons"].size() == 0 or option["weapons"].size() == 2, "every recipe uses exactly two weapons")
    expect(rules.link_options(["club", "staff"]).size() == 1, "missing powder cannot activate a recipe")
    var rune: Dictionary = rules.link_profile("rune_shell", ids)
    expect(rune["weapons"] == ["powder", "staff"], "magic cannon consists of powder and staff only")
    expect(rune["suppressed"].has("staff") and rune["cooldown_multiplier"] > 1.0, "magic cannon really pays staff-fire and reload costs")
    var chain: Dictionary = rules.link_profile("chain_axe", ids)
    expect(chain["weapons"] == ["powder", "axe"] and chain["range"] < 395.0, "chain axe is a shorter-range two-piece recipe")
    expect(chain["kind"] == "chain" and not chain.get("enchanted", false), "owning staff cannot add a third-piece magic chain")
    expect(rules.link_profile("chain_axe", ["powder", "staff"])["id"] == "none", "ineligible recipe falls back to no link")
    for id in ["powder", "staff", "sling"]:
        expect(rules.ranged_mount(id).length() <= 76.0, "ranged mount stays near the body and inside the expanded melee orbit: " + id)
    expect(is_equal_approx(rules.orbit_position(0, 3, 0.0, false).length(), rules.MELEE_ORBIT), "melee orbit sits on the expanded readable radius")
    expect(rules.MELEE_ORBIT - rules.PARKED_RADIUS >= 30.0, "melee ring sits clearly farther out than parked weapons")
    expect(rules.is_parked_weapon("hammer") and not rules.orbits_with_formation("hammer"), "stone hammer is a parked magic/area weapon, not circling melee")
    call_deferred("scene_checks")

func scene_checks() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/links_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.demo = true
    world.start_run(true)
    expect(world.active_link["id"] == "none", "six-weapon trial defaults to no link")
    world.formation_phase = 0.0
    world.update_weapons(0.0, false)
    var before: Dictionary = {}
    var rules = load("res://src/rules.gd")
    for key in ["powder", "staff", "sling"]:
        before[key] = world.weapon_views[key].position - world.player_position
        expect(before[key].length() >= 28.0 and before[key].length() <= rules.PARKED_MAX_ANCHOR, "ranged slot stays on the compact readable carry rows: " + key)
        expect(before[key].length() + 20.0 < rules.MELEE_ORBIT, "ranged slot stays clearly inside the melee ring: " + key)
    var club_before: Vector2 = world.weapon_views["club"].position - world.player_position
    world.update_weapons(0.25, false)
    var club_after: Vector2 = world.weapon_views["club"].position - world.player_position
    expect(club_after.distance_to(club_before) > 8.0, "melee weapons still orbit around the avatar in a mixed loadout")
    for key in ["powder", "staff", "sling"]:
        var offset: Vector2 = world.weapon_views[key].position - world.player_position
        expect(offset.distance_to(before[key]) < 2.5, "ranged weapons stay parked in their assigned slots: " + key)
        expect(absf(offset.length() - before[key].length()) < 3.0 and offset.length() + 20.0 < rules.MELEE_ORBIT, "parked ranged slot keeps a clearly closer radius: " + key)
    world.select_link("rune_shell")
    world.projectiles.clear()
    world.weapon_runtime["powder"]["cooldown"] = 0.0
    world.weapon_runtime["staff"]["cooldown"] = 0.0
    world.update_weapons(0.01)
    var magical: bool = false
    var staff_fired: bool = false
    for projectile in world.projectiles:
        if projectile["weapon_id"] == "powder" and projectile.get("enchanted", false):
            magical = true
        if projectile["weapon_id"] == "staff":
            staff_fired = true
    expect(magical, "actual powder projectile becomes magic fire")
    expect(not staff_fired, "staff stops independent firing as a real cost")
    world.select_link("chain_axe")
    # Measure chain extension against a target, without a mineable rock in its lane.
    for x in range(-2,5):
        for y in range(-2,5): world.map_view.chunks[Vector2i(x,y)]=[]
    for enemy in world.enemies:
        enemy["view"].queue_free()
    world.enemies.clear()
    world.spawn_enemy("tank", world.player_position + Vector2(150, 0))
    world.enemies[0]["hp"] = 1000.0
    world.enemies[0]["max_hp"] = 1000.0
    world.update_weapons(0.0, false)
    var muzzle: Vector2 = world.chain_anchor()
    expect(muzzle.distance_to(world.weapon_muzzle_point("powder")) <= 1.5, "chain anchor uses the powder cannon muzzle")
    expect(world.weapon_views["axe"].position.distance_to(muzzle) <= 3.0, "the linked weapon rests on the cannon muzzle")
    var launch_target: Vector2 = world.enemies[0]["position"]
    world.launch_chain("axe", launch_target)
    expect(world.weapon_runtime["axe"]["chain_position"].distance_to(muzzle) <= 1.5, "the chain launches from the cannon muzzle")
    var launch_dir: Vector2 = world.weapon_runtime["axe"]["chain_direction"]
    expect(launch_dir.dot((launch_target - muzzle).normalized()) > 0.999, "the chain aims from the muzzle to the target")
    world.weapon_runtime["axe"]["chain_state"] = "rest"
    world.weapon_runtime["powder"]["cooldown"] = 0.0
    var extended: bool = false
    var peak_reach: float = 0.0
    for index in range(35):
        world.simulate(1.0 / 60.0, Vector2.ZERO)
        # The chain launches from the tracked barrel muzzle (Juniper,
        # 2026-11-17), so it can pass 95 px on the very step it reaches its
        # target and turns back; judge the launch by the flight's peak reach
        # instead of one same-step snapshot.
        if world.weapon_runtime["axe"].get("chain_state", "rest") != "rest":
            peak_reach = maxf(peak_reach, world.weapon_views["axe"].position.distance_to(world.player_position))
        if peak_reach > 95.0:
            extended = true
            break
    expect(extended, "chain weapon really extends out")
    var returning: Dictionary = world.weapon_runtime["axe"]
    returning["chain_state"] = "back"
    returning["chain_position"] = world.enemies[0]["position"]
    returning["chain_hit_ids"] = [world.enemies[0]["id"]]
    var before_repeat: float = world.enemies[0]["hp"]
    world.select_link("none")
    world.update_chain_weapon(world.inventory[1], 1.0 / 60.0)
    expect(is_equal_approx(world.enemies[0]["hp"], before_repeat), "changing a pending link during return cannot damage an already-hit enemy twice")
    world.select_link("none")
    for index in range(180):
        world.simulate(1.0 / 60.0, Vector2.ZERO)
    expect(world.active_link["id"] == "none" and world.weapon_runtime["axe"].get("chain_state", "rest") == "rest", "disable recalls weapon before settling into no-link state")
    expect(world.inventory.size() == 6 and world.weapon_views.size() == 6, "links preserve the six original weapons")
    world.start_run(false)
    expect(world.burning_fields.is_empty() and world.active_link["id"] == "none", "restart clears link hazards")
    check_ranged_torso_clearance(world)
    world.queue_free()
    await process_frame
    print("LINK RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
