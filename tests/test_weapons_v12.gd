extends SceneTree

const Catalog = preload("res://src/catalog.gd")
const Rules = preload("res://src/rules.gd")
const Armory = preload("res://src/armory.gd")
const WeaponArt = preload("res://src/weapon_art.gd")
const EXPANDED: Array = ["bonebow", "firepot", "wardrum", "crystal"]

var checks: int = 0
var failures: int = 0
var armory: Node2D
var views: Dictionary = {}

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func enemy(id: int, point: Vector2, radius: float = 8.0) -> Dictionary:
    return {"id": id, "position": point, "hp": 1000.0, "radius": radius}

func simulate(key: String, seconds: float, targets: Array, level: int = 1, haste: float = 1.0, hero: Vector2 = Vector2.ZERO) -> Array:
    var events: Array = []
    var remaining: float = seconds
    while remaining > 0.00001:
        var delta: float = minf(1.0 / 120.0, remaining)
        events.append_array(armory.advance(delta, hero, targets, [{"id": key, "level": level}], {"attack_speed": haste}, false, views))
        remaining -= delta
    return events

func hits(events: Array, target_id: int = -1) -> Array:
    return events.filter(func(event): return event.get("type", "") == "hit" and (target_id == -1 or event["enemy"]["id"] == target_id))

func _initialize() -> void:
    call_deferred("run_checks")

func run_checks() -> void:
    armory = Armory.new()
    root.add_child(armory)
    for key in EXPANDED:
        var view: Sprite2D = Sprite2D.new()
        armory.add_child(view)
        views[key] = view
    check_catalog_and_slots()
    check_bone_arrow()
    check_bone_arrow_reach()
    check_firepot()
    check_drum()
    check_crystal()
    check_growth_and_haste()
    check_lifecycle_and_art()
    armory.queue_free()
    await process_frame
    print("WEAPONS V12 RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)

func check_bone_arrow_reach() -> void:
    armory.reset()
    var outside: Array=simulate("bonebow",1.2,[enemy(100,Vector2(-425,-34),28)])
    expect(not outside.any(func(e):return e.type=="flash"),"bonebow does not repeatedly fire at a target beyond its actual muzzle range")
    armory.reset()
    var inside: Array=simulate("bonebow",0.85,[enemy(101,Vector2(-300,-34),28)])
    expect(not hits(inside,101).is_empty(),"left-side bonebow shots reach a target inside actual muzzle range")

func check_catalog_and_slots() -> void:
    var catalog_script: Script = load("res://src/catalog.gd")
    var constants: Dictionary = catalog_script.get_script_constant_map()
    expect(constants.get("EXPANDED_IDS", []) == EXPANDED, "expanded weapons form a separate selectable group while the previous expansion keeps its IDs")
    expect(Catalog.NEW_IDS == ["spear", "hammer", "boomerang", "totem"], "the previous four-weapon trial remains selectable")
    for key in EXPANDED:
        var inventory: Array = []
        expect(Catalog.IDS.has(key) and Rules.equip(inventory, key).get("accepted", false), "new weapon enters the actual equip pool: " + key)
        for upgrade in range(4):
            Rules.equip(inventory, key)
        var beyond_cap: Dictionary = Rules.equip(inventory, key)
        expect(inventory.size() == 1 and inventory[0]["level"] == 5 and not beyond_cap.get("accepted", true), "new weapon upgrades to level five and rejects level six: " + key)
    var full: Array = []
    for key in ["club", "staff", "bonebow", "firepot", "wardrum", "crystal"]:
        Rules.equip(full, key)
    expect(full.size() == 6 and not Rules.equip(full, "axe").get("accepted", true), "four expanded weapons share the existing six-slot limit")

func check_bone_arrow() -> void:
    armory.reset()
    var targets: Array = [enemy(4, Vector2(410, -34)), enemy(3, Vector2(330, -34)), enemy(2, Vector2(250, -34)), enemy(1, Vector2(170, -34)), enemy(9, Vector2(250, 45))]
    var early: Array = simulate("bonebow", 0.05, targets)
    expect(hits(early).is_empty(), "bone crossbow damage waits for the physical arrow to reach the enemy")
    var events: Array = simulate("bonebow", 0.55, targets)
    for target_id in [1, 2, 3]:
        expect(hits(events, target_id).size() == 1, "one bone arrow pierces each crossed enemy once: " + str(target_id))
    expect(hits(events, 4).is_empty() and hits(events, 9).is_empty(), "a bone arrow stops after three pierces and cannot hit beside its narrow path")
    armory.reset()
    var swept: Array = armory.advance(0.01, Vector2.ZERO, targets, [{"id": "bonebow", "level": 1}], {"attack_speed": 1.0}, false, views)
    swept.append_array(armory.advance(0.5, Vector2.ZERO, targets, [{"id": "bonebow", "level": 1}], {"attack_speed": 1.0}, false, views))
    expect(hits(swept).size() == 3, "swept bone-arrow collision catches crossed targets during a long frame")

func check_firepot() -> void:
    armory.reset()
    var targets: Array = [enemy(1, Vector2(150, 0)), enemy(2, Vector2(260, 0))]
    var early: Array = simulate("firepot", 0.2, targets)
    expect(hits(early).is_empty(), "a firepot cannot burn enemies while it is still in the air")
    var events: Array = simulate("firepot", 1.55, targets)
    expect(hits(events, 1).size() == 3, "a landed firepot applies three separated burn ticks by 1.75 seconds rather than per-frame damage")
    expect(hits(events, 2).is_empty(), "the persistent fire remains at its landing site and respects its radius")
    targets[0]["position"] = Vector2(350, 0)
    var escaped: Array = simulate("firepot", 0.25, targets)
    expect(hits(escaped).is_empty(), "leaving a burning patch immediately stops its damage")

func check_drum() -> void:
    armory.reset()
    var targets: Array = [enemy(1, Vector2(80, 0)), enemy(2, Vector2(130, 0)), enemy(3, Vector2(210, 0))]
    var events: Array = simulate("wardrum", 0.95, targets)
    expect(hits(events, 1).size() == 3 and hits(events, 2).size() == 3, "three expanding drumbeats each strike a nearby enemy once")
    expect(hits(events, 3).is_empty(), "drum shockwaves cannot damage an enemy beyond their outer radius")
    armory.reset()
    var before_wave: Array = simulate("wardrum", 0.06, [enemy(1, Vector2(130, 0))])
    expect(hits(before_wave).is_empty(), "a drumbeat damages when its ring reaches the enemy rather than an instant full disk")

func check_crystal() -> void:
    armory.reset()
    var targets: Array = [enemy(1, Vector2(160, 0)), enemy(2, Vector2(270, 0)), enemy(3, Vector2(210, 50)), enemy(4, Vector2(380, 0))]
    var early: Array = simulate("crystal", 0.2, targets)
    expect(hits(early).is_empty(), "a crystal cluster must land and arm before releasing shards")
    var events: Array = simulate("crystal", 1.2, targets)
    expect(hits(events, 1).size() == 1 and hits(events, 2).size() == 1, "one triggered cluster releases real radial shards without sixfold overlap damage")
    expect(hits(events, 3).is_empty() and hits(events, 4).is_empty(), "crystal shards have separate narrow paths and finite travel")
    armory.reset()
    var mobile: Array = [enemy(1, Vector2(160, 0))]
    simulate("crystal", 0.2, mobile)
    mobile[0]["position"] = Vector2(500, 0)
    var waiting: Array = simulate("crystal", 0.9, mobile)
    expect(hits(waiting).is_empty(), "an armed crystal waits when every enemy leaves its trigger radius")
    mobile[0]["position"] = Vector2(160, 0)
    var triggered: Array = simulate("crystal", 0.5, mobile)
    expect(hits(triggered, 1).size() == 1, "an enemy entering the armed cluster triggers a single detonation")

func check_growth_and_haste() -> void:
    for key in EXPANDED:
        var point: Vector2 = Vector2(90, 0) if key == "wardrum" else Vector2(170, -34) if key == "bonebow" else Vector2(160, 0)
        var targets: Array = [enemy(1, point)]
        armory.reset()
        var low: Array = hits(simulate(key, 1.75, targets))
        armory.reset()
        var high: Array = hits(simulate(key, 1.75, targets, 5))
        expect(not low.is_empty() and not high.is_empty(), "expanded weapon causes actual hit events at both levels: " + key)
        if not low.is_empty() and not high.is_empty():
            var per_hit: float={"bonebow":1.392,"firepot":1.2,"wardrum":2.4,"crystal":2.4}[key]
            expect(is_equal_approx(high[0]["damage"], low[0]["damage"] * per_hit), "level five balances each actual hit against its unlocked multi-attack pattern: " + key)
            expect(is_same(low[0]["enemy"], targets[0]), "hit event carries the live target dictionary for real damage: " + key)
        armory.reset()
        var normal: Array = simulate(key, 5.0, targets)
        armory.reset()
        var fast: Array = simulate(key, 5.0, targets, 1, 2.0)
        var normal_attacks: int = normal.filter(func(event): return event.get("type", "") == "flash").size()
        var fast_attacks: int = fast.filter(func(event): return event.get("type", "") == "flash").size()
        expect(normal_attacks >= 2 and fast_attacks > normal_attacks, "attack-speed upgrades increase actual launch or beat sequences: " + key)

func check_lifecycle_and_art() -> void:
    armory.reset()
    var inventory: Array = []
    for key in EXPANDED:
        inventory.append({"id": key, "level": 1})
    var empty: Array = armory.advance(0.1, Vector2.ZERO, [], inventory, {"attack_speed": 1.0}, false, views)
    expect(empty.is_empty(), "equipped expanded weapons do not attack without a living in-range target")
    var bow_rest: Vector2 = views["bonebow"].position
    var pot_rest: float = views["firepot"].rotation
    armory.advance(0.2, Vector2.ZERO, [], inventory, {"attack_speed": 1.0}, false, views)
    expect(views["bonebow"].position.is_equal_approx(bow_rest) and is_equal_approx(views["firepot"].rotation, pot_rest), "newly equipped idle weapons do not recoil or throw without an attack")
    for first in range(EXPANDED.size()):
        for second in range(first + 1, EXPANDED.size()):
            expect(views[EXPANDED[first]].position.distance_to(views[EXPANDED[second]].position) >= 44.0, "expanded held weapons occupy separate readable mounts")
    var masks: Array = []
    for key in EXPANDED:
        var texture: Texture2D = WeaponArt.texture(key)
        expect(texture != null, "expanded weapon has native hand-drawn SVG artwork: " + key)
        if texture == null:
            continue
        var icon: Image = texture.get_image()
        expect(icon.get_size() == Vector2i(128, 128) and icon.get_pixel(0, 0).a == 0.0, "new icon keeps the transparent 128-pixel asset contract: " + key)
        var mask: PackedByteArray = []
        for y in range(128):
            for x in range(128):
                mask.append(255 if icon.get_pixel(x, y).a > 0.5 else 0)
        expect(not masks.has(mask), "new weapon changes the silhouette rather than only its color: " + key)
        masks.append(mask)
    simulate("bonebow", 0.1, [enemy(1, Vector2(200, -34))])
    armory.reset()
    expect(armory.states.is_empty(), "reset discards every expanded projectile, hazard, and cooldown")
    simulate("bonebow", 0.1, [enemy(1, Vector2(200, -34))])
    var removed: Array = armory.advance(0.5, Vector2.ZERO, [enemy(1, Vector2(200, -34))], [], {"attack_speed": 1.0}, false, views)
    expect(removed.is_empty() and armory.states.is_empty(), "unequipping cannot leave a damaging expanded attack behind")
