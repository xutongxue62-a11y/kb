extends SceneTree

const Rules = preload("res://src/rules.gd")
const Growth = preload("res://src/growth.gd")
const Economy = preload("res://src/economy.gd")
const Catalog = preload("res://src/catalog.gd")

var checks: int = 0
var failures: int = 0

func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)

func ids_of(inventory: Array) -> Array:
    var ids: Array = []
    for item in inventory:
        ids.append(item["id"])
    return ids

func fill(world, keys: Array) -> void:
    world.clear_weapons()
    for key in keys:
        expect(world.grant_weapon(key), "fixture can grant " + str(key))

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    expect(is_equal_approx(Growth.new_weapon_level_chance(1, 1), 0.90) and Growth.new_weapon_level_chance(1, Growth.MAX_WEAPON_LEVEL) > 0.0, "early offers mostly roll Lv.1 but every catalog level stays possible")
    expect(Growth.high_tier_chance(1) < Growth.high_tier_chance(4) and Growth.high_tier_chance(4) < Growth.high_tier_chance(10), "mid and high weapon levels ramp up with stage progress")
    expect(Growth.high_tier_chance(10) < 0.45, "even late offers keep the top end uncommon")
    expect(Growth.high_tier_status(1) == "新获得" and Growth.high_tier_status(3).contains("Lv.3") and Growth.high_tier_status(5).contains("Lv.5"), "high-tier means catalog evolution milestones: Lv.3 进阶 and Lv.5 觉醒")
    expect(Growth.is_high_tier_level(3) and Growth.is_high_tier_level(5) and not Growth.is_high_tier_level(1), "level 1 stays a basic drop")
    expect(Growth.weapon_level_text(1) == "Lv.1" and Growth.weapon_level_text(3).contains("进阶") and Growth.weapon_level_text(5).contains("觉醒"), "every weapon level has a visible label, including Lv.1")
    expect(is_equal_approx(Economy.SELL_BACK_RATE, 0.5), "sell-back is an explicit half of the current-level buy price")
    var buy_l1: int = Economy.price("club", 1, 1)
    var sell_l1: int = Economy.sell_price("club", 1, 1)
    var buy_l5: int = Economy.price("club", 1, 5)
    var sell_l5: int = Economy.sell_price("club", 1, 5)
    expect(sell_l1 == int(floor(float(buy_l1) * Economy.SELL_BACK_RATE)) and sell_l1 > 0 and sell_l1 < buy_l1, "Lv.1 sell-back is a discounted conversion, not the full buy price")
    expect(sell_l5 == int(floor(float(buy_l5) * Economy.SELL_BACK_RATE)) and sell_l5 > sell_l1 and sell_l5 < buy_l5, "a higher-level weapon sells for more, still below its buy price")

    var inventory: Array = []
    for key in ["club", "axe", "blade", "sling", "powder", "staff"]:
        expect(Rules.equip(inventory, key).accepted, "six starters still equip")
    expect(not Rules.equip(inventory, "spear").get("accepted", true) and Rules.equip(inventory, "spear").reason == "full", "equip itself still refuses a seventh unique weapon")
    var swapped: Dictionary = Rules.replace_weapon(inventory, "club", "spear", 3)
    expect(swapped.accepted and inventory.size() == 6 and inventory[0]["id"] == "spear" and inventory[0]["level"] == 3, "replace swaps the chosen slot and can insert a high-tier weapon")
    expect(not ids_of(inventory).has("club") and ids_of(inventory).has("spear"), "the outgoing weapon leaves the loadout")
    expect(not Rules.replace_weapon(inventory, "axe", "spear", 1).get("accepted", true), "cannot replace with a weapon already held")
    expect(not Rules.replace_weapon(inventory, "missing", "hammer", 1).get("accepted", true), "cannot replace a weapon that is not in the loadout")

    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/replace_v20_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.start_run(false)
    var six: Array = ["club", "axe", "blade", "sling", "powder", "staff"]
    fill(world, six)
    expect(world.inventory.size() == 6 and not world.grant_weapon("spear"), "grant_weapon still does not silently add a seventh weapon")
    expect(ids_of(world.inventory) == six, "rejected grant leaves the original six")

    world.coins = 40
    world.shop_open = true
    world.shop_stock = [{"id":"spear","price":18,"sold":false,"level":3}]
    expect(Economy.valid(world.shop_stock[0], world.coins, world.inventory, {}, world.player_hp, world.stats["max_hp"]), "a new weapon remains purchasable when the loadout is full")
    expect(world.buy_shop_item(0) and not world.replace_pending.is_empty(), "buying a new weapon at six slots opens a replace choice instead of rejecting it")
    expect(ids_of(world.inventory) == six and world.coins == 40 and world.shop_stock[0]["sold"] == false, "opening replace does not spend gold or consume the offer")
    world.cancel_replace()
    expect(world.replace_pending.is_empty() and ids_of(world.inventory) == six and world.coins == 40 and world.shop_stock[0]["sold"] == false, "cancel keeps the six weapons and does not spend gold")

    expect(world.buy_shop_item(0), "the unsold offer can be chosen again after cancel")
    var club_refund: int = Economy.sell_price("club", world.wave, 1)
    expect(world.confirm_replace("club") and world.coins == 40 - 18 + club_refund and world.shop_stock[0]["sold"] == true, "confirm charges the new price and credits sell-back for the replaced weapon")
    expect(club_refund < Economy.price("club", world.wave, 1), "shop replace sell-back is not the full buy price")
    expect(world.inventory.size() == 6 and world.inventory[0]["id"] == "spear" and world.inventory[0]["level"] == 3, "the new high-tier weapon occupies the chosen slot")
    expect(not world.weapon_views.has("club") and world.weapon_views.has("spear"), "the outgoing weapon view is removed and the incoming one is bound")
    expect(world.replace_pending.is_empty(), "replace state clears after a confirmed shop swap")

    fill(world, six)
    world.upgrade_pending = true
    world.upgrade_reason = "chest"
    world.upgrade_choices = ["hammer", "power", "haste"]
    world.upgrade_offer_levels = {"hammer": 5}
    world.on_choice("hammer")
    expect(world.upgrade_pending and world.replace_pending.get("id", "") == "hammer" and int(world.replace_pending.get("level", 0)) == 5, "a full-loadout chest weapon asks which slot to replace")
    expect(ids_of(world.inventory) == six, "the chest reward is not applied until the player confirms")
    world.cancel_replace()
    expect(world.upgrade_pending and world.upgrade_reason == "chest" and ids_of(world.inventory) == six, "cancel returns to the chest choice without losing the reward")
    world.on_choice("power")
    expect(world.buff_levels.get("power", 0) == 1 and not world.upgrade_pending and ids_of(world.inventory) == six, "a buff can still be taken instead, and it does not touch the six weapons")

    fill(world, six)
    world.upgrade_pending = true
    world.upgrade_reason = "chest"
    world.upgrade_choices = ["totem"]
    world.upgrade_offer_levels = {"totem": 5}
    world.chest_queue = 0
    world.coins = 10
    world.on_choice("totem")
    var staff_refund: int = Economy.sell_price("staff", world.wave, 1)
    expect(world.confirm_replace("staff") and world.inventory[5]["id"] == "totem" and world.inventory[5]["level"] == 5, "confirming a chest replace inserts the rolled high-tier weapon")
    expect(world.coins == 10 + staff_refund, "chest replace credits sell-back and does not charge a shop price")
    expect(not world.upgrade_pending and not world.weapon_views.has("staff") and world.weapon_views.has("totem"), "the chest is consumed only after the swap confirms")

    fill(world, six)
    world.grant_weapon("club")
    expect(world.inventory[0]["id"] == "club" and world.inventory[0]["level"] == 2 and world.inventory.size() == 6, "owning a weapon at six slots still upgrades it without opening replace")

    var early := RandomNumberGenerator.new()
    early.seed = 20261116
    var early_new := 0
    var early_high := 0
    var early_awake := 0
    for sample in range(200):
        var stock: Array = Economy.stock([], {}, 1, early)
        for offer in stock:
            if not Catalog.WEAPONS.has(str(offer["id"])):
                continue
            early_new += 1
            var rolled: int = int(offer.get("level", 1))
            if Growth.is_high_tier_level(rolled):
                early_high += 1
                if rolled >= 5:
                    early_awake += 1
    expect(early_new >= 400, "the early seeded batch still rolls many new weapons")
    var early_rate: float = float(early_high) / float(early_new)
    expect(early_rate > 0.005 and early_rate < 0.08, "wave-1 shops do not flood high-tier weapons: " + str(early_rate))
    expect(early_high > 0, "the stated early rate is still possible")

    var late := RandomNumberGenerator.new()
    late.seed = 20261116
    var late_new := 0
    var late_high := 0
    var late_awake := 0
    for sample in range(200):
        var stock: Array = Economy.stock([], {}, 8, late)
        for offer in stock:
            if not Catalog.WEAPONS.has(str(offer["id"])):
                continue
            late_new += 1
            var rolled: int = int(offer.get("level", 1))
            if Growth.is_high_tier_level(rolled):
                late_high += 1
                if rolled >= 5:
                    late_awake += 1
    var late_rate: float = float(late_high) / float(maxi(1, late_new))
    expect(late_rate > 0.10 and late_rate < 0.38, "stage-8 shops raise Lv.3+ offers with the current progression weights: " + str(late_rate))
    expect(late_rate > early_rate * 2.0, "later shop stock actually raises higher-level frequency above the early pool")
    expect(float(late_awake) / float(maxi(1, late_new)) < 0.10, "Lv.5 remains uncommon even after lower evolved levels become more available")
    if late_high >= 8:
        var awake_share: float = float(late_awake) / float(late_high)
        expect(awake_share < 0.6, "awakened Lv.5 stays the rarer half of high-tier rolls: " + str(awake_share))

    var forced := RandomNumberGenerator.new()
    forced.seed = 1
    var seen_levels := {}
    for i in range(800):
        var rolled: int = Growth.roll_new_weapon_level(forced, 8)
        expect(rolled >= 1 and rolled <= Growth.MAX_WEAPON_LEVEL, "rolled starting levels stay inside the supported weapon levels")
        seen_levels[rolled] = true
    for level in range(1, 6):
        expect(seen_levels.has(level), "the current distribution can actually produce Lv.%d" % level)

    var store = load("res://src/save_store.gd").new("res://runtime/tests/replace_stock_" + str(Time.get_ticks_usec()))
    var state: Dictionary = {"version":1,"wave":2,"inventory":[{"id":"club","level":1}],"buff_levels":{},"player_hp":8.0,"coins":20,"xp":0,"player_level":1,"finished":false,"shop_stock":[{"id":"spear","price":30,"sold":false,"probability":0.1,"level":5}]}
    expect(store.write_run(state).ok, "optional high-tier shop level is a backward-compatible save field")
    var restored: Dictionary = store.read_run()
    expect(restored.ok and int(restored.state.shop_stock[0].get("level", 0)) == 5, "a direct Lv.5 shop offer survives a save roundtrip")
    state.shop_stock[0].level = 9
    expect(not store.write_run(state).ok, "shop levels outside 1-5 are rejected")

    world.queue_free()
    print("WEAPON REPLACE V20 RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
