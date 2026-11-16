extends RefCounted

const Catalog = preload("res://src/catalog.gd")
const Growth = preload("res://src/growth.gd")

# Shop prices follow relative strength. 蛮力 costs more than 猎手直觉.
const BUFF_PRICE_BASE := {
    "power": 28,
    "haste": 26,
    "crit_chance": 18,
    "crit_power": 16,
    "pet": 24,
    "drone": 24
}

static func price(key: String, stage: int, level: int = 0) -> int:
    var inflation: int = mini(12, maxi(0, stage - 1) / 4)
    if key == "heal":
        return 10 + inflation
    if Catalog.WEAPONS.has(key):
        return 18 + level * 4 + inflation
    if Growth.BUFFS.has(key):
        var base: int = int(BUFF_PRICE_BASE.get(key, 24 if Growth.BUFFS[key]["category"] == "support" else 14))
        return base + level * 4 + inflation
    return 999999

static func stock(inventory: Array, levels: Dictionary, stage: int, random: RandomNumberGenerator) -> Array:
    var result: Array = []
    for key in Growth.weighted_choices(inventory, levels, random, 6, true):
        var owned: int = Growth.item_level(key, inventory, levels)
        var offered: int = owned
        if Catalog.WEAPONS.has(key) and owned <= 0:
            offered = Growth.roll_new_weapon_level(random, stage)
        var offer := {"id": key, "price": price(key, stage, offered if owned <= 0 else owned), "sold": false,
            "probability": Growth.draw_probability(key, inventory, levels, true)}
        if Catalog.WEAPONS.has(key) and owned <= 0:
            offer["level"] = offered
        result.append(offer)
    return result

# Replaced weapons sell at half their current-level shop buy price (floored, at least 1 coin).
# This is a resale conversion, never the full purchase price.
const SELL_BACK_RATE: float = 0.5

static func sell_price(key: String, stage: int, level: int) -> int:
    if not Catalog.WEAPONS.has(key):
        return 0
    var buy: int = price(key, stage, maxi(1, level))
    return maxi(1, int(floor(float(buy) * SELL_BACK_RATE)))

static func reward_sell_price(key: String, stage: int, offered_level: int) -> int:
    if Catalog.WEAPONS.has(key): return sell_price(key,stage,offered_level)
    if not Growth.BUFFS.has(key): return 0
    # Buff shop prices take the current stack, not the stack after purchasing.
    var buy: int=price(key,stage,maxi(0,offered_level-1))
    return maxi(1,int(floor(float(buy)*SELL_BACK_RATE)))

static func valid(offer: Dictionary, coins: int, inventory: Array, levels: Dictionary, hp: float, max_hp: float) -> bool:
    if offer.get("sold", false) or int(offer.get("price", 0)) <= 0 or coins < int(offer["price"]):
        return false
    var key: String = str(offer.get("id", ""))
    if key == "heal":
        return hp < max_hp
    if Growth.BUFFS.has(key):
        return int(levels.get(key, 0)) < Growth.BUFFS[key]["max_level"]
    if not Catalog.WEAPONS.has(key):
        return false
    for item in inventory:
        if item["id"] == key:
            return item["level"] < 5
    # A new weapon is still buyable at six slots; the shop then asks which one to replace.
    return true
