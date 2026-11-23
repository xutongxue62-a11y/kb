extends RefCounted

const Catalog = preload("res://src/catalog.gd")
const Growth = preload("res://src/growth.gd")
const Rules = preload("res://src/rules.gd")
const Evolution = preload("res://src/weapon_evolution.gd")
const EnemyRoster = preload("res://src/enemy_roster.gd")
const BASE_DAMAGE = {"hunter": 1.0, "charger": 1.25, "spitter": 1.0, "tank": 1.5, "boss": 2.0}

static func _link_list(link: Variant) -> Array:
    var links: Array = []
    if typeof(link) == TYPE_ARRAY:
        for entry in link:
            if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "none")) != "none":
                links.append(entry)
    elif typeof(link) == TYPE_DICTIONARY and str(link.get("id", "none")) != "none":
        if link.has("links") and typeof(link["links"]) == TYPE_ARRAY and not link["links"].is_empty():
            for entry in link["links"]:
                if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "none")) != "none":
                    links.append(entry)
        else:
            links.append(link)
    return links

static func estimate_power(inventory: Array, levels: Dictionary, link: Variant = {}) -> float:
    var links: Array = _link_list(link)
    var suppressed: Array = Rules.suppressed_weapon_ids(links)
    var chain: Dictionary = Rules.chain_profile(links)
    var stats: Dictionary = Growth.stats(levels)
    var total: float = 0.0
    for item in inventory:
        var key: String = item["id"]
        if not Catalog.WEAPONS.has(key) or suppressed.has(key):
            continue
        var data: Dictionary = Catalog.WEAPONS[key]
        var damage: float = data["damage"] * Evolution.damage_multiplier(key, int(item["level"]), key == "hammer" and Rules.host_is_thunder_enchanted(links, key))
        if key == "powder" and not chain.is_empty():
            var partner: String = chain["weapons"][1]
            var partner_level: int = 1
            for owned in inventory:
                if owned["id"] == partner:
                    partner_level = owned["level"]
            var chain_damage: float = Catalog.WEAPONS[partner]["damage"] * (1.0 + (partner_level - 1) * 0.35) + 1.6 * (1.0 + (item["level"] - 1) * 0.25)
            total += chain_damage * 1.6 / maxf(data["cooldown"] * Rules.weapon_cooldown_multiplier("powder", links), 0.65)
        elif data["kind"] == "melee":
            total += damage * minf(data["orbit_speed"] / TAU, 1.0 / data["cooldown"])
        else:
            var shots: float = 3.0 if key in ["staff", "wardrum"] else (6.0 if key == "firepot" else 1.0)
            var penalty: float = Rules.weapon_cooldown_multiplier(key, links)
            total += damage * shots / (data["cooldown"] * penalty) * (1.2 if key == "powder" and Rules.host_is_rune_enchanted(links, "powder") else 1.0)
    for key in ["pet", "drone"]:
        var level: int = int(levels.get(key, 0))
        if level > 0:
            total += (3.8 if key == "pet" else 2.8) * (1.0 + (level - 1) * 0.45) * (1.0 + (level - 1) * 0.18) / (0.95 if key == "pet" else 1.15) * (0.7 if key == "pet" else 0.9)
    return maxf(0.1, total * stats["attack_speed"] * stats["damage_multiplier"] * (1.0 + stats["crit_chance"] * (stats["crit_multiplier"] - 1.0)))

const ADAPT_CAP: float = 1.75
const ADAPT_FULL_WAVE: int = 28
const BOSS_DYNAMIC_MULT: float = 58.0
const BOSS_DYNAMIC_CAP: float = 4.8
const BOSS_HEALTH_TUNING: float = 1.05
const BOSS_DAMAGE_TUNING: float = 1.08
const MINION_DAMAGE_TUNING: float = 0.94
# A single combat hit may never remove more than this share of the player's
# max HP (applied after armor reduction, at the hurt_player funnel).
# Lava and other terrain DoT ticks do not pass through this cap.
const HIT_CAP_RATIO: float = 0.70
const BOSS_HIT_CAP_RATIO: float = 0.35

static func cap_boss_hp(formula_hp: float, power: float) -> float:
    var dynamic_hp: float = power * BOSS_DYNAMIC_MULT * BOSS_HEALTH_TUNING
    return maxf(formula_hp, minf(dynamic_hp, formula_hp * BOSS_DYNAMIC_CAP))

static func adapt_ceiling(wave: int) -> float:
    # The 1.75 cap is reached around stage 29, not at the first Boss milestone.
    return 1.0 + (ADAPT_CAP - 1.0) * clampf(float(maxi(1, wave) - 1) / float(ADAPT_FULL_WAVE), 0.0, 1.0)

static func adaptation(wave: int, power: float, previous: float = 1.0) -> float:
    var reference: float = estimate_power([{"id": "sling", "level": 1}], {})
    var milestones: int = maxi(0, wave / 5)
    var expected: float = reference * exp(minf(20.0, milestones * log(1.65)))
    var ratio: float = maxf(1.0, power / expected)
    var raw: float = clampf(maxf(previous, pow(ratio, 0.32)), 1.0, ADAPT_CAP)
    return minf(raw, adapt_ceiling(wave))

# Extra mid-to-late monster growth starts after wave 8 so early stages stay
# close to the original curve while later waves stop being stand-and-DPS fodder.
const LATE_GROWTH_START: int = 8
const LATE_GROWTH_MID: int = 16
const LATE_GROWTH_DEEP: int = 24
# After wave 20, HP compounding switches to a gentler rate so late Bosses
# stay hard but are no longer effectively unkillable. Waves 1-20 keep the
# original curve exactly. Monster damage and outgoing player damage are unchanged.
const LATE_GROWTH_SOFTEN: int = 20
const LATE_GROWTH_SOFT_RATE: float = 1.062

static func late_hp_log(stage: int) -> float:
    var capped: int = mini(stage, LATE_GROWTH_SOFTEN)
    var late: float = 0.0
    if capped > LATE_GROWTH_START:
        late += float(capped - LATE_GROWTH_START) * log(1.06)
    if capped > LATE_GROWTH_MID:
        late += float(capped - LATE_GROWTH_MID) * log(1.07)
    if capped > LATE_GROWTH_DEEP:
        late += float(capped - LATE_GROWTH_DEEP) * log(1.06)
    if stage > LATE_GROWTH_SOFTEN:
        late += float(stage - LATE_GROWTH_SOFTEN) * log(LATE_GROWTH_SOFT_RATE)
    return late

static func late_damage_log(stage: int) -> float:
    var late: float = 0.0
    if stage > LATE_GROWTH_START:
        late += float(stage - LATE_GROWTH_START) * log(1.04)
    if stage > LATE_GROWTH_MID:
        late += float(stage - LATE_GROWTH_MID) * log(1.05)
    if stage > LATE_GROWTH_DEEP:
        late += float(stage - LATE_GROWTH_DEEP) * log(1.04)
    return late

# Mild outgoing player-damage softening in mid-to-late waves. Waves 1-8 stay at 1.0.
static func outgoing_damage_scale(wave: int) -> float:
    var stage: int = maxi(1, wave)
    if stage <= LATE_GROWTH_START:
        return 1.0
    if stage <= LATE_GROWTH_MID:
        return 1.0 - 0.015 * float(stage - LATE_GROWTH_START)
    return maxf(0.72, 0.88 - 0.012 * float(stage - LATE_GROWTH_MID))

static func enemy_profile(wave: int, kind: String, adaptive: float = 1.0, elite: bool = false) -> Dictionary:
    var stage: int = maxi(1, wave)
    var milestones: int = stage / 5
    var hp_scale: float = exp(minf(27.6, (stage - 1) * log(1.10) + milestones * log(1.45) + late_hp_log(stage))) * clampf(adaptive, 1.0, ADAPT_CAP)
    var milestone_log: float = minf(float(milestones), 3.0) * log(1.18) + maxf(0.0, float(milestones) - 3.0) * log(1.10)
    var damage_log: float = late_damage_log(stage)
    var damage_scale: float = minf(1000000.0, (1.0 + 0.06 * (stage - 1)) * exp(minf(14.0, milestone_log + damage_log)))
    if kind == "boss":
        damage_scale = minf(1000000.0, (0.50 + 0.03 * (stage - 1)) * exp(minf(14.0, milestone_log * 0.55 + damage_log * 0.55)))
    var dodge: float = minf(0.22, maxf(0, stage - 2) * 0.006 + milestones * 0.012) if stage > 2 else 0.0
    if kind in ["tank", "boss", "armored", "basaltroller"]:
        dodge *= 0.35
    elif kind == "charger":
        dodge *= 0.65
    if elite and stage > 2:
        dodge += 0.05
    var data: Dictionary = Catalog.DINOS.get(kind, EnemyRoster.BiomeEncounters.MOBS.get(kind, Catalog.DINOS["hunter"]))
    var boss_hp_mult: float = minf(1.85, 1.0 + 0.04 * float(stage - 9)) if (kind == "boss" and stage >= 10) else 1.0
    var hp_tuning: float = BOSS_HEALTH_TUNING if kind == "boss" else 1.0
    var damage_tuning: float = BOSS_DAMAGE_TUNING if kind == "boss" else MINION_DAMAGE_TUNING
    return {
        "hp": data["hp"] * hp_scale * (1.8 if elite else 1.0) * boss_hp_mult * hp_tuning,
        "damage": float(BASE_DAMAGE.get(kind, EnemyRoster.base_damage(kind))) * damage_scale * (1.35 if elite else 1.0) * damage_tuning,
        "dodge": minf(0.30, dodge),
        "speed_multiplier": 1.0 + minf(0.35, (stage - 1) * 0.009 + milestones * 0.025),
        "bullet_multiplier": 1.0 + minf(0.30, (stage - 1) * 0.007)
    }
