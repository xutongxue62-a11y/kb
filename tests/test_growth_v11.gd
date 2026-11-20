extends SceneTree

var checks: int = 0
var failures: int = 0

func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)

func _initialize() -> void:
    var growth = load("res://src/growth.gd")
    var economy = load("res://src/economy.gd")
    var levels: Dictionary = {}
    for key in ["power", "haste"]:
        for index in range(10):
            expect(growth.apply(levels, key), key + " stacks to ten")
    expect(is_equal_approx(growth.stats(levels)["attack_speed"], 2.0), "ten haste yields 2.0x actual speed")
    expect(is_equal_approx(growth.stats({"haste": 1})["attack_speed"], 1.10), "one haste stack is +10%")
    expect(is_equal_approx(growth.stats({"armor": 1})["reduction"], 0.06), "one armor stack is -6%")
    expect(is_equal_approx(growth.stats(levels)["damage_multiplier"], 2.8), "ten power yields 2.8x damage")
    for key in ["power", "haste"]:
        expect(growth.apply(levels, key), key + " can still grow past ten")
    for key in ["crit_chance", "crit_power"]:
        for index in range(8):
            expect(growth.apply(levels, key), key + " stacks to eight")
    expect(is_equal_approx(growth.stats(levels)["crit_chance"], 0.53), "maximum critical chance is 53 percent at eight stacks")
    expect(is_equal_approx(growth.stats(levels)["crit_multiplier"], 4.3), "maximum critical damage reaches 4.3x at eight stacks")
    expect(int(growth.BUFFS["pet"]["max_level"]) == 999 and int(growth.BUFFS["drone"]["max_level"]) == 999, "both supports stay available across a long run")
    var random: RandomNumberGenerator = RandomNumberGenerator.new()
    random.seed = 113
    var inventory: Array = [{"id":"club", "level":1}]
    var stock: Array = economy.stock(inventory, {}, 1, random)
    expect(stock.size() == 6, "shop offers six choices")
    if not growth.has_method("draw_probability"):
        expect(false, "first draw probability API is available")
        finish()
        return
    var previous: float = 1.0
    var power_cap: int = int(growth.BUFFS["power"]["max_level"])
    for level in [0, 1, 2, 5, 10]:
        var probability: float = growth.draw_probability("power", inventory, {"power":level})
        expect(probability > 0.0 and probability < previous, "higher owned level strictly lowers first draw chance")
        previous = probability
    expect(growth.draw_probability("power", inventory, {"power":power_cap}) == 0.0, "capped buffs have no draw chance")
    expect(growth.probability_text("power", inventory, {}).begins_with("首抽率 "), "UI labels first draw odds separately from crit stats")
    var total: float = 0.0
    for key in growth.candidate_pool(inventory, {}, true):
        total += growth.draw_probability(key, inventory, {}, true)
    expect(is_equal_approx(total, 1.0), "candidate first-draw rates normalize to one")
    var heal_seen: bool = false
    var heal_absent: bool = false
    var support_seen: bool = false
    for sample in range(120):
        stock = economy.stock(inventory, {}, 7, random)
        var seen: Dictionary = {}
        expect(stock.size() == 6, "nonexhausted pool supplies six")
        for offer in stock:
            expect(not seen.has(offer["id"]), "shop choices are distinct")
            seen[offer["id"]] = true
            expect(economy.valid(offer, 10000, inventory, {}, 1.0, 8.0), "shop offer is buyable when affordable and injured")
            expect(is_equal_approx(offer["probability"], growth.draw_probability(offer["id"], inventory, {}, true)), "stock probability records initial pool odds")
        heal_seen = heal_seen or seen.has("heal")
        heal_absent = heal_absent or not seen.has("heal")
        support_seen = support_seen or seen.has("pet") or seen.has("drone")
    expect(heal_seen and heal_absent, "healing is random rather than a forced slot")
    expect(support_seen, "support appears through weighted draws")
    var maxed: Dictionary = {}
    for key in growth.BUFFS:
        maxed[key] = growth.BUFFS[key]["max_level"]
    var full: Array = []
    for key in ["club", "axe", "blade", "sling", "powder", "staff"]:
        full.append({"id":key, "level":growth.MAX_WEAPON_LEVEL})
    var owned: Dictionary = {}
    for item in full:
        owned[item["id"]] = true
    var leftover: Array = growth.choices(full, maxed, random)
    expect(not leftover.is_empty() and leftover.all(func(key): return not owned.has(key) and growth.Catalog.WEAPONS.has(key)), "a full maxed loadout still offers unowned weapons so one can be replaced")
    expect(not growth.chest_choices(full, maxed, random).is_empty(), "chests can still offer a replacement weapon when every owned weapon is already capstones")
    stock = economy.stock(full, maxed, 99, random)
    expect(stock.size() == 6, "full loadout shop still fills six offers from remaining weapons or healing")
    expect(stock.any(func(offer): return not owned.has(offer["id"]) or offer["id"] == "heal"), "full shop can roll an unowned weapon or healing rather than stalling")
    full[0]["level"] = 4
    expect(growth.candidate_pool(full, maxed).has("club"), "an owned weapon below capstone stays in the replace-era pool")
    var saw_club := false
    for _sample in range(120):
        if growth.choices(full, maxed, random).has("club"):
            saw_club = true
            break
    expect(saw_club, "six weapons still include the remaining owned upgrade among replacement options")
    var armory = load("res://src/armory.gd").new()
    var view: Sprite2D = Sprite2D.new()
    var foe: Dictionary = {"id":1, "position":Vector2(100, 0), "hp":100000.0, "radius":20.0, "elite":false}
    var attacks: Array = []
    for build in [{}, {"haste":10}]:
        armory.reset()
        var count: int = 0
        for frame in range(1200):
            for event in armory.advance(1.0 / 120.0, Vector2.ZERO, [foe], [{"id":"totem", "level":1}], growth.stats(build), false, {"totem":view}):
                if event["type"] == "flash":
                    count += 1
        attacks.append(count)
    expect(attacks[1] > attacks[0] * 1.7, "real armory produces nearly twice the attacks at ten haste")
    print("ARMORY HASTE: base=%d high=%d over 10s" % [attacks[0], attacks[1]])
    armory.free()
    view.free()
    var store = load("res://src/save_store.gd").new("res://runtime/tests/growth_v11_" + str(Time.get_ticks_usec()))
    var state: Dictionary = {"version":1,"wave":1,"inventory":inventory,"buff_levels":{"power":3,"haste":3},"player_hp":8.0,"coins":999,"xp":0,"player_level":1,"finished":false}
    expect(store.write_run(state)["ok"], "old three-stack saves remain valid")
    state["buff_levels"] = maxed
    state["shop_stock"] = economy.stock(inventory, {}, 1, random)
    state["shop_stock"][0]["sold"] = true
    expect(store.write_run(state)["ok"], "new caps and six offers save")
    var restored: Dictionary = store.read_run()
    expect(restored["ok"] and same_levels(restored["state"]["buff_levels"], maxed) and same_stock(restored["state"]["shop_stock"], state["shop_stock"]), "caps prices sold states and six offer odds roundtrip")
    state["shop_stock"][0]["probability"] = 1.1
    expect(not store.write_run(state)["ok"], "probability metadata rejects values outside zero to one")
    state["shop_stock"][0]["probability"] = 0.1
    var defense: Dictionary = growth.stats({"armor":40, "dodge":40})
    expect(defense["reduction"] > 0.9 and defense["reduction"] < 1.0 and defense["dodge"] > 0.8 and defense["dodge"] < 1.0, "defensive layers never reach full immunity even on high stacks")
    var offer: Dictionary = {"id":"power", "price":14,"sold":false}
    expect(not economy.valid(offer, 13, inventory, {}, 1.0, 8.0), "insufficient coins cannot buy an upgrade")
    offer["price"] = 0
    expect(not economy.valid(offer, 99, inventory, {}, 1.0, 8.0), "zero price cannot grant free upgrades")
    state["buff_levels"]["power"] = 1000
    expect(not store.write_run(state)["ok"], "overcap save rejected")
    finish()

func finish() -> void:
    print("GROWTH V11 RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)

func same_stock(actual: Array, expected: Array) -> bool:
    if actual.size() != expected.size():
        return false
    for index in range(actual.size()):
        for key in ["id", "price", "sold"]:
            if actual[index][key] != expected[index][key]:
                return false
        if not is_equal_approx(actual[index]["probability"], expected[index]["probability"]):
            return false
    return true

func same_levels(actual: Dictionary, expected: Dictionary) -> bool:
    if actual.size() != expected.size():
        return false
    for key in expected:
        if not actual.has(key) or int(actual[key]) != int(expected[key]):
            return false
    return true
