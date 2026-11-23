extends SceneTree

var failures: int = 0
var checks: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func _initialize() -> void:
    if not FileAccess.file_exists("res://src/growth.gd"):
        expect(false, "non-weapon Buff rules and mixed growth choices are not implemented")
        finish()
        return
    var growth = load("res://src/growth.gd")
    var levels: Dictionary = {}
    var base: Dictionary = growth.stats(levels)
    expect(is_equal_approx(base["crit_chance"], 0.05) and is_equal_approx(base["crit_multiplier"], 1.5), "base critical hits have a real 5 percent chance and 150 percent damage")
    expect(is_equal_approx(base["speed"], 220.0) and is_equal_approx(base["max_hp"], 8.0), "base movement and health preserve the playable baseline")
    expect(growth.apply(levels, "crit_chance"), "a passive Buff can be acquired without a weapon inventory")
    expect(is_equal_approx(growth.stats(levels)["crit_chance"], 0.10), "critical chance gains five percentage points")
    growth.apply(levels, "crit_power")
    expect(is_equal_approx(growth.stats(levels)["crit_multiplier"], 1.75), "critical damage increases independently of critical chance")
    growth.apply(levels, "speed")
    growth.apply(levels, "armor")
    var boosted: Dictionary = growth.stats(levels)
    expect(is_equal_approx(boosted["speed"], 237.6) and is_equal_approx(boosted["reduction"], 0.05), "speed and reduction change their actual consumers' values")
    expect(str(growth.BUFFS["armor"]["description"]).contains("受到伤害 -5%"), "armor card quotes the tuned reduction")
    expect(str(growth.BUFFS["haste"]["description"]).contains("攻击速度 +8%"), "haste card quotes the tuned attack speed")
    growth.apply(levels, "accuracy")
    expect(growth.stats(levels)["hit_radius"] > 0.0 and growth.stats(levels)["homing"] > 0.0, "accuracy improves collision tolerance and flight correction without random misses")
    growth.apply(levels, "explorer")
    expect(is_equal_approx(growth.stats(levels)["pickup_radius"], 124.0) and is_equal_approx(growth.stats(levels)["xp_multiplier"], 1.12), "explorer expands collection radius and XP yield")
    growth.apply(levels, "pierce")
    growth.apply(levels, "pierce")
    expect(growth.stats(levels)["pierce"] == 2 and growth.apply(levels, "pierce") and growth.stats(levels)["pierce"] == 3, "each pierce stack adds one extra target")
    var before: Dictionary = levels.duplicate(true)
    expect(not growth.apply(levels, "invalid") and levels == before, "unknown growth cannot mutate a run")
    var random: RandomNumberGenerator = RandomNumberGenerator.new()
    random.seed = 123
    var inventory: Array = []
    for key in ["club", "axe", "blade", "sling", "powder", "staff"]:
        inventory.append({"id": key, "level": growth.MAX_WEAPON_LEVEL})
    var owned: Dictionary = {}
    for item in inventory:
        owned[item["id"]] = true
    var choices: Array = growth.choices(inventory, {}, random)
    expect(choices.size() == 3 and not choices.has("club"), "six maxed weapons still offer valid non-owned-upgrade growth")
    expect(choices.all(func(key): return not owned.has(key)), "a full maxed loadout never re-offers those six capstones")
    var seen_support: bool = false
    var seen_passive: bool = false
    var seen_replace: bool = false
    for draw in range(80):
        for key in growth.choices(inventory, {}, random):
            if growth.BUFFS.has(key):
                seen_support = seen_support or growth.BUFFS[key]["category"] == "support"
                seen_passive = seen_passive or growth.BUFFS[key]["category"] == "passive"
            elif growth.Catalog.WEAPONS.has(key):
                seen_replace = seen_replace or not owned.has(key)
    expect(seen_support and seen_passive, "weighted pool includes attribute and follower options without forced category slots")
    expect(seen_replace, "full loadout growth can also offer an unowned weapon for replacement")
    var maxed: Dictionary = {}
    for key in growth.BUFFS:
        maxed[key] = growth.BUFFS[key]["max_level"]
    var leftover: Array = growth.choices(inventory, maxed, random)
    expect(not leftover.is_empty() and leftover.all(func(key): return not owned.has(key) and growth.Catalog.WEAPONS.has(key)), "when every buff is also maxed, leftover unowned weapons remain as replace options instead of an empty sheet")
    inventory[0]["level"] = 4
    expect(growth.candidate_pool(inventory, maxed).has("club"), "the last legal owned upgrade stays in the pool alongside replace options")
    var saw_club := false
    for _sample in range(120):
        if growth.choices(inventory, maxed, random).has("club"):
            saw_club = true
            break
    expect(saw_club, "the last legal weapon upgrade remains selectable")
    expect(is_equal_approx(growth.stage_hp_bonus(0), 0.0) and is_equal_approx(growth.stats({}, 0)["max_hp"], 8.0), "no cleared stages keep the base 8 health")
    expect(is_equal_approx(growth.stats({}, 1)["max_hp"], 9.0) and is_equal_approx(growth.stats({}, 5)["max_hp"], 13.0), "each cleared stage adds 1 max HP")
    expect(is_equal_approx(growth.stats({}, 2)["max_hp"], 10.0), "two cleared stages give 10 max HP")
    growth.apply(levels, "vitality")
    expect(is_equal_approx(growth.stats(levels, 3)["max_hp"], 13.0), "stage-clear HP stacks with vitality: 8 + 2 + 3")
    expect(is_equal_approx(growth.stats(levels, 0)["max_hp"], 10.0), "player level is not used; vitality alone is 10")
    finish()

func finish() -> void:
    print("GROWTH RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
