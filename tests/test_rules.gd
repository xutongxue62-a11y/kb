extends SceneTree

var failures: int = 0
var checks: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func _initialize() -> void:
    if not FileAccess.file_exists("res://src/rules.gd"):
        expect(false, "six-slot inventory, target selection, combo and coordinated gait are not implemented")
        print("RESULT: %d checks, %d failures" % [checks, failures])
        quit(1)
        return
    var rules = load("res://src/rules.gd")
    if rules == null or not rules.can_instantiate():
        expect(false, "rules script must load")
        quit(1)
        return
    var inventory: Array = []
    for weapon_id in ["club", "axe", "blade", "sling", "powder", "staff"]:
        expect(rules.equip(inventory, weapon_id).get("accepted", false), "sixth legal weapon is accepted: " + weapon_id)
    expect(inventory.size() == 6, "six different legal weapons occupy six slots")
    expect(rules.equip(inventory, "club").get("upgraded", false), "same weapon upgrades when all six slots are full")
    expect(inventory.size() == 6 and inventory[0]["level"] == 2, "same-weapon upgrade preserves slot count and increases level")
    expect(not rules.equip(inventory, "unknown").get("accepted", false), "unknown seventh weapon is rejected")
    expect(inventory.size() == 6, "invalid equip cannot mutate inventory")
    var enemies = [
        {"id": 1, "position": Vector2(30, 0), "elite": false, "hp": 2},
        {"id": 2, "position": Vector2(140, 0), "elite": true, "hp": 5},
        {"id": 3, "position": Vector2(2, 0), "elite": false, "hp": 0}
    ]
    expect(rules.choose_target(Vector2.ZERO, 100.0, enemies, true).get("id", -1) == 1, "out-of-range elite cannot steal a target; dead nearest is ignored")
    enemies.append({"id": 4, "position": Vector2(80, 0), "elite": true, "hp": 3})
    expect(rules.choose_target(Vector2.ZERO, 100.0, enemies, true).get("id", -1) == 4, "in-range elite has priority when enabled")
    expect(rules.choose_target(Vector2.ZERO, 100.0, enemies, false).get("id", -1) == 1, "default nearest targeting ignores elite priority")
    expect(rules.choose_target(Vector2.ZERO, 1.0, enemies, false).is_empty(), "no in-range living target means no shot")
    expect(rules.choose_target(Vector2.ZERO, 50.0, [], false).is_empty(), "empty target list is safe")
    var rock: Dictionary = {"id": 9, "hp": 20.0, "position": Vector2(20, 0), "stone": true, "kind": "stone", "elite": false, "radius": 20.0}
    var monster: Dictionary = {"id": 10, "hp": 5.0, "position": Vector2(80, 0), "stone": false, "kind": "hunter", "elite": false, "radius": 22.0}
    expect(int(rules.choose_target(Vector2.ZERO, 120.0, [rock, monster]).get("id", -1)) == 10, "a living monster in range beats a closer rock")
    expect(int(rules.choose_target(Vector2.ZERO, 120.0, [rock]).get("id", -1)) == 9, "a rock can still be targeted when no monster is in range")
    expect(rules.has_monster_in_range(Vector2.ZERO, 120.0, [rock, monster]) and not rules.has_monster_in_range(Vector2.ZERO, 40.0, [rock, monster]), "monster presence is measured inside the weapon range")
    var boundary = [{"id": 8, "position": Vector2(100, 0), "hp": 1, "elite": false}]
    expect(rules.choose_target(Vector2.ZERO, 100.0, boundary).get("id", -1) == 8, "exact range boundary is included")
    expect(is_equal_approx(rules.advance_gait(0.0, 9.5), PI / 2.0), "gait advances a quarter cycle after a quarter stride")
    expect(is_equal_approx(rules.advance_gait(1.25, 0.0), 1.25), "no actual movement means gait phase does not advance")
    var pose = rules.gait_pose(PI / 2.0, Vector2.RIGHT, 1.0)
    expect(pose["left_foot"].x > 0.0 and pose["right_foot"].x < 0.0, "left and right feet alternate independently")
    expect(pose["left_hand"].x < 0.0 and pose["right_hand"].x > 0.0, "hands counter-swing against their same-side feet")
    var stopped = rules.gait_pose(PI / 2.0, Vector2.UP, 0.0)
    expect(stopped["left_foot"].is_zero_approx() and stopped["right_foot"].is_zero_approx() and stopped["left_hand"].is_zero_approx() and stopped["right_hand"].is_zero_approx(), "all four limbs return to rest when amplitude reaches zero")
    expect(rules.orbit_position(0, 3, 0.0, false).is_equal_approx(Vector2(rules.MELEE_ORBIT, 0)), "expanded orbit starts on the actual outer radius")
    expect(rules.orbit_position(0, 3, 0.0, true).is_equal_approx(Vector2(rules.MELEE_ORBIT_COLLAPSED, 0)), "focused orbit uses the shorter collision path")
    print("RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
