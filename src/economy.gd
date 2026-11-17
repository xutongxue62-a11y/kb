extends RefCounted

const Catalog = preload("res://src/catalog.gd")
const Growth = preload("res://src/growth.gd")

# Shop prices follow relative strength. 蛮力 costs more than 猎手直觉.
# Batch 3 (Juniper: gold overflows mid-run): everything costs more, and the
# price climbs steeply with the level you are buying — high-level weapons and
# deep buff stacks are the gold sink. For weapons `level` is the level being
# bought; for buffs it is the stack the player already owns.
const BUFF_PRICE_BASE := {
    "power": 34,
    "haste": 32,
    "crit_chance": 24,
    "crit_power": 22,
    "pet": 30,
    "drone": 30
}

static func price(key: String, stage: int, level: int = 0) -> int:
    var inflation: int = mini(24, maxi(0, stage - 1) / 2)
    if key == "heal":
        return 12 + mini(18, maxi(0, stage - 1) / 3)
    if Catalog.WEAPONS.has(key):
        var target: int = clampi(level, 1, Growth.MAX_WEAPON_LEVEL)
        return 26 + int(round(10.0 * pow(float(target), 1.7))) + inflation
    if Growth.BUFFS.has(key):
        var base: int = int(BUFF_PRICE_BASE.get(key, 30 if Growth.BUFFS[key]["category"] == "support" else 20))
        return int(round(float(base) * (1.0 + 0.45 * float(maxi(0, level))))) + inflation
    return 999999

# Rerolling the camp shop costs gold and gets pricier each time within the
# same camp visit, so spare gold has somewhere to go without becoming free.
static func reroll_price(stage: int, rerolls: int) -> int:
    return 15 + maxi(0, stage) + 15 * maxi(0, rerolls)

static func stock(inventory: Array, levels: Dictionary, stage: int, random: RandomNumberGenerator) -> Array:
    var result: Array = []
    for key in Growth.weighted_choices(inventory, levels, random, 6, true):
        var owned: int = Growth.item_level(key, inventory, levels)
        var offered: int = owned
        if Catalog.WEAPONS.has(key) and owned <= 0:
            offered = Growth.roll_new_weapon_level(random, stage)
        var offer := {"id": key, "price": price(key, stage, offered if owned <= 0 else owned + 1), "sold": false,
            "probability": Growth.draw_probability(key, inventory, levels, true)}
        if Catalog.WEAPONS.has(key) and owned <= 0:
            offer["level"] = offered
        result.append(offer)
    # Boss-adjacent camps always stock a heal: the camp right before a boss
    # wave (stage 4, 9, 14, ...) and the camp right after one (5, 10, 15, ...).
    # Without this the heal slot is a coin flip exactly when it matters most.
    var boss_adjacent: bool = stage % 5 == 0 or (stage + 1) % 5 == 0
    var has_heal: bool = false
    for offer in result:
        if str(offer.get("id", "")) == "heal":
            has_heal = true
    if boss_adjacent and not has_heal:
        var heal_offer := {"id": "heal", "price": price("heal", stage), "sold": false,
            "probability": Growth.draw_probability("heal", inventory, levels, true)}
        if result.is_empty():
            result.append(heal_offer)
        else:
            result[result.size() - 1] = heal_offer
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
            return item["level"] < Growth.MAX_WEAPON_LEVEL
    # A new weapon is still buyable at six slots; the shop then asks which one to replace.
    return true
