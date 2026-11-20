extends RefCounted

const Catalog = preload("res://src/catalog.gd")
const Evolution = preload("res://src/weapon_evolution.gd")
const BUFFS = {
    "power": {"name": "蛮力", "glyph": "力", "category": "passive", "max_level": 999, "save_max_level": 999, "description": "全部伤害 +18%\n也强化宠物与飞行器", "color": Color("#cb794a")},
    "crit_chance": {"name": "猎手直觉", "glyph": "暴", "category": "passive", "max_level": 999, "save_max_level": 999, "description": "暴击率 +6 个百分点\n金色大数字表示暴击", "color": Color("#c38c25")},
    "crit_power": {"name": "致命一击", "glyph": "击", "category": "passive", "max_level": 999, "save_max_level": 999, "description": "暴击伤害 +35 个百分点\n与暴击率分别成长", "color": Color("#c36736")},
    "haste": {"name": "迅捷出手", "glyph": "速", "category": "passive", "max_level": 999, "save_max_level": 999, "description": "攻击速度 +20%\n武器与支援都更快出手", "color": Color("#a98140")},
    "speed": {"name": "轻盈步伐", "glyph": "移", "category": "passive", "max_level": 999, "description": "移动速度 +10%\n更轻松地躲避冲锋与毒弹", "color": Color("#668b58")},
    "armor": {"name": "厚皮护甲", "glyph": "甲", "category": "passive", "max_level": 999, "description": "受到伤害 -12%\n接触与敌方弹丸均生效", "color": Color("#858d78")},
    "vitality": {"name": "强健体魄", "glyph": "心", "category": "passive", "max_level": 999, "description": "生命上限 +2\n同时恢复 2 点生命", "color": Color("#b96d61")},
    "regen": {"name": "生命嫩芽", "glyph": "生", "category": "passive", "max_level": 999, "description": "每秒恢复 0.12 生命\n成长和暂停期间停止计时", "color": Color("#669362")},
    "dodge": {"name": "灵巧闪避", "glyph": "闪", "category": "passive", "max_level": 999, "description": "闪避率 +6 个百分点\n触发时显示“闪避”", "color": Color("#7b9b9c")},
    "accuracy": {"name": "鹰眼瞄准", "glyph": "准", "category": "passive", "max_level": 999, "description": "弹速 +8% · 命中半径 +2\n轻微追踪 · 抵消敌闪避 4%", "color": Color("#518f99")},
    "explorer": {"name": "探险拾荒", "glyph": "探", "category": "passive", "max_level": 999, "description": "拾取范围 +30 · 经验 +15%\n经验石会向你靠拢", "color": Color("#8b9460")},
    "area": {"name": "震荡扩散", "glyph": "域", "category": "passive", "max_level": 999, "description": "爆炸与灼烧范围 +18%\n范围圆圈对应实际伤害区", "color": Color("#b2824c")},
    "pierce": {"name": "贯穿石弹", "glyph": "穿", "category": "passive", "max_level": 999, "description": "石弹与符能弹额外穿透 1 敌\n火药范围弹不参与", "color": Color("#5c949b")},
    "ricochet": {"name": "弹射技巧", "glyph": "弹", "category": "passive", "max_level": 999, "description": "石弹与符能弹额外弹射 1 敌\n同一发不会重复伤害同一敌人", "color": Color("#6f86a2")},
    "pet": {"name": "幼龙伙伴", "glyph": "龙", "category": "support", "max_level": 999, "description": "召唤跟随幼龙，自动扑咬\n再选提升伤害与出手速度", "color": Color("#b98245")},
    "drone": {"name": "石灵飞行器", "glyph": "灵", "category": "support", "max_level": 999, "description": "召唤跟随飞行器，符能点射\n再选提升伤害与出手速度", "color": Color("#4f9b9f")}
}

static func stats(levels: Dictionary) -> Dictionary:
    levels = levels.duplicate()
    for key in BUFFS:
        levels[key] = clampi(int(levels.get(key, 0)), 0, int(BUFFS[key]["max_level"]))
    return {
        "damage_multiplier": 1.0 + 0.18 * int(levels.get("power", 0)),
        "crit_chance": minf(0.95, 0.05 + 0.06 * int(levels.get("crit_chance", 0))),
        "crit_multiplier": 1.5 + 0.35 * int(levels.get("crit_power", 0)),
        "attack_speed": 1.0 + 0.20 * int(levels.get("haste", 0)),
        "speed": 220.0 * (1.0 + 0.10 * int(levels.get("speed", 0))),
        # Layers are uncapped now, so reduction and dodge stack multiplicatively:
        # each layer removes its share of what is left, never reaching 100%.
        "reduction": 1.0 - pow(0.88, int(levels.get("armor", 0))),
        "max_hp": 8.0 + 2.0 * int(levels.get("vitality", 0)),
        "regen": 0.12 * int(levels.get("regen", 0)),
        "dodge": 1.0 - pow(0.94, int(levels.get("dodge", 0))),
        "hit_radius": 2.0 * int(levels.get("accuracy", 0)),
        "bullet_speed": 1.0 + 0.08 * int(levels.get("accuracy", 0)),
        "homing": 1.5 * int(levels.get("accuracy", 0)),
        "dodge_ignore": 0.04 * int(levels.get("accuracy", 0)),
        "pickup_radius": 100.0 + 30.0 * int(levels.get("explorer", 0)),
        "xp_multiplier": 1.0 + 0.15 * int(levels.get("explorer", 0)),
        "area_multiplier": 1.0 + 0.18 * int(levels.get("area", 0)),
        "pierce": int(levels.get("pierce", 0)),
        "ricochet": int(levels.get("ricochet", 0)),
        "range_multiplier": 1.0,
        "close_damage_bonus": 0.0,
        "close_damage_range": 140.0
    }

static func apply(levels: Dictionary, key: String) -> bool:
    if not BUFFS.has(key) or int(levels.get(key, 0)) >= BUFFS[key]["max_level"]:
        return false
    levels[key] = int(levels.get(key, 0)) + 1
    return true

const PROBABILITY_HINT: String = "按当前候选池首抽计算；同轮不重复；已拥有层数越高，抽取权重越低"

static func item_level(key: String, inventory: Array, levels: Dictionary) -> int:
    for item in inventory:
        if item["id"] == key:
            return int(item["level"])
    return int(levels.get(key, 0))

static func candidate_pool(inventory: Array, levels: Dictionary, include_heal: bool = false) -> Array:
    var pool: Array = []
    for key in Catalog.IDS:
        var level: int = item_level(key, inventory, {})
        # Unowned weapons stay in the pool even at six slots so the player can replace one.
        if level < MAX_WEAPON_LEVEL:
            pool.append(key)
    for key in BUFFS:
        if int(levels.get(key, 0)) < int(BUFFS[key]["max_level"]):
            pool.append(key)
    if include_heal:
        pool.append("heal")
    return pool

static func pick_weight(_key: String, level: int) -> float:
    # All types use the same transparent curve; no hidden category guarantees.
    return 1.0 / pow(1.0 + maxi(0, level), 1.1)

static func effective_weight(key: String, inventory: Array, levels: Dictionary) -> float:
    var weight: float = pick_weight(key, item_level(key, inventory, levels))
    # At six weapons an unowned weapon means giving up a built one, so swap
    # offers draw less often than upgrades and buffs. Panels that are nothing
    # but swaps were a recurring complaint; this keeps swaps possible but rare.
    if inventory.size() >= 6 and Catalog.WEAPONS.has(key) and item_level(key, inventory, levels) <= 0:
        weight *= 0.45
    return weight

static func draw_probability(key: String, inventory: Array, levels: Dictionary, include_heal: bool = false) -> float:
    var pool: Array = candidate_pool(inventory, levels, include_heal)
    if not pool.has(key):
        return 0.0
    var total: float = 0.0
    for candidate in pool:
        total += effective_weight(candidate, inventory, levels)
    return effective_weight(key, inventory, levels) / total if total > 0.0 else 0.0

static func probability_text(key: String, inventory: Array, levels: Dictionary, include_heal: bool = false) -> String:
    return "首抽率 %.1f%%" % (100.0 * draw_probability(key, inventory, levels, include_heal))

static func weighted_choices(inventory: Array, levels: Dictionary, random: RandomNumberGenerator, count: int = 3, include_heal: bool = false) -> Array:
    var pool: Array = candidate_pool(inventory, levels, include_heal)
    var result: Array = []
    while result.size() < count and not pool.is_empty():
        var total: float = 0.0
        for key in pool:
            total += effective_weight(key, inventory, levels)
        var roll: float = random.randf() * total
        var selected: int = pool.size() - 1
        for index in range(pool.size()):
            roll -= effective_weight(pool[index], inventory, levels)
            if roll < 0.0:
                selected = index
                break
        result.append(pool.pop_at(selected))
    return result

static func choices(inventory: Array, levels: Dictionary, random: RandomNumberGenerator) -> Array:
    return weighted_choices(inventory, levels, random)

static func chest_choices(inventory: Array, levels: Dictionary, random: RandomNumberGenerator) -> Array:
    return weighted_choices(inventory, levels, random)

# XP to the next player level. Raised so early stages do not flood growth picks.
# Level 1 needs 15; each later level adds 5 more (20, 25, 30, ...).
static func xp_needed_for(level: int) -> int:
    return 10 + maxi(1, level) * 5

# Direct new-weapon levels (1 through the current catalog cap) all remain possible.
# Early stages heavily favor Lv.1; mid/high levels ramp in later, with the top end uncommon.
# Batch 3: cap raised to 7 and the high end cut again — direct Lv.5+ draws are
# now rare at every stage, and Lv.6/7 are jackpots rather than a plan.
const MAX_WEAPON_LEVEL: int = 7
const MAX_NEW_WEAPON_LEVEL: int = 7
# Stage-band weights for Lv.1 .. Lv.7. Rows stay positive so every level can appear.
const NEW_WEAPON_LEVEL_WEIGHTS := {
    1: [90.0, 7.0, 2.2, 0.6, 0.15, 0.04, 0.01],
    4: [76.0, 16.0, 5.5, 1.7, 0.55, 0.17, 0.08],
    7: [64.0, 22.0, 9.0, 3.2, 1.2, 0.4, 0.2],
    10: [55.0, 26.0, 12.0, 4.4, 1.7, 0.6, 0.3]
}

static func new_weapon_level_weights(stage: int) -> Array:
    var chosen: Array = NEW_WEAPON_LEVEL_WEIGHTS[1]
    var best: int = 1
    for key in NEW_WEAPON_LEVEL_WEIGHTS:
        if int(key) <= stage and int(key) >= best:
            best = int(key)
            chosen = NEW_WEAPON_LEVEL_WEIGHTS[key]
    return chosen.duplicate()

static func new_weapon_level_chance(stage: int, level: int) -> float:
    var weights: Array = new_weapon_level_weights(stage)
    if level < 1 or level > weights.size():
        return 0.0
    var total: float = 0.0
    for weight in weights:
        total += float(weight)
    return float(weights[level - 1]) / total if total > 0.0 else 0.0

static func roll_new_weapon_level(random: RandomNumberGenerator, stage: int) -> int:
    var weights: Array = new_weapon_level_weights(stage)
    var total: float = 0.0
    for weight in weights:
        total += float(weight)
    var roll: float = random.randf() * total
    for index in range(weights.size()):
        roll -= float(weights[index])
        if roll < 0.0:
            return index + 1
    return weights.size()

# Convenience: chance of rolling 进阶 (Lv.3+) for a given stage.
static func high_tier_chance(stage: int) -> float:
    var chance: float = 0.0
    for level in range(3, MAX_NEW_WEAPON_LEVEL + 1):
        chance += new_weapon_level_chance(stage, level)
    return chance

static func is_high_tier_level(level: int) -> bool:
    return level >= 3

static func high_tier_status(level: int) -> String:
    if level >= 5:
        return "直接获得 Lv.%d 觉醒" % level
    if level >= 3:
        return "直接获得 Lv.3 进阶"
    return "新获得"

static func weapon_level_text(level: int) -> String:
    var n: int = clampi(level, 1, MAX_WEAPON_LEVEL)
    if n >= 5:
        return "Lv.%d 觉醒" % n
    if n >= 3:
        return "Lv.%d 进阶" % n
    return "Lv.%d" % n

static func acquired_description(key: String, level: int) -> String:
    var labels: Array = Evolution.MILESTONES.get(key, ["进阶", "觉醒"])
    if level >= 5:
        return "直接获得 %d级觉醒 · " % level + str(labels[1]) + "
已包含 3级" + str(labels[0])
    if level >= 3:
        return "直接获得 3级进阶 · " + str(labels[0]) + "
5级觉醒 · " + str(labels[1])
    return Evolution.offer_description(key, 0)
