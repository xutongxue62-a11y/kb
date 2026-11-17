extends RefCounted

const Catalog = preload("res://src/catalog.gd")
const Growth = preload("res://src/growth.gd")
const EnemyRoster = preload("res://src/enemy_roster.gd")
const BASE_DAMAGE = {"hunter": 1.0, "charger": 1.25, "spitter": 1.0, "tank": 1.5, "boss": 2.0}

static func estimate_power(inventory: Array, levels: Dictionary, link: Dictionary = {}) -> float:
    var stats: Dictionary = Growth.stats(levels)
    var total: float = 0.0
    for item in inventory:
        var key: String = item["id"]
        if not Catalog.WEAPONS.has(key) or link.get("suppressed", []).has(key):
            continue
        var data: Dictionary = Catalog.WEAPONS[key]
        var damage: float = data["damage"] * (1.0 + (item["level"] - 1) * 0.35)
        if key == "powder" and link.get("kind", "none") == "chain":
            var partner: String = link["weapons"][1]
            var partner_level: int = 1
            for owned in inventory:
                if owned["id"] == partner:
                    partner_level = owned["level"]
            var chain_damage: float = Catalog.WEAPONS[partner]["damage"] * (1.0 + (partner_level - 1) * 0.35) + 1.6 * (1.0 + (item["level"] - 1) * 0.25)
            total += chain_damage * 1.6 / maxf(data["cooldown"] * link["cooldown_multiplier"], 0.65)
        elif data["kind"] == "melee":
            total += damage * minf(data["orbit_speed"] / TAU, 1.0 / data["cooldown"])
        else:
            var shots: float = 3.0 if key in ["staff", "wardrum"] else (6.0 if key == "firepot" else 1.0)
            var penalty: float = link.get("cooldown_multiplier", 1.0) if key == "powder" else 1.0
            total += damage * shots / (data["cooldown"] * penalty) * (1.2 if key == "powder" and link.get("enchanted", false) else 1.0)
    for key in ["pet", "drone"]:
        var level: int = int(levels.get(key, 0))
        if level > 0:
            total += (3.8 if key == "pet" else 2.8) * (1.0 + (level - 1) * 0.45) * (1.0 + (level - 1) * 0.18) / (0.95 if key == "pet" else 1.15) * (0.7 if key == "pet" else 0.9)
    return maxf(0.1, total * stats["attack_speed"] * stats["damage_multiplier"] * (1.0 + stats["crit_chance"] * (stats["crit_multiplier"] - 1.0)))

const ADAPT_CAP: float = 1.75
const ADAPT_FULL_WAVE: int = 28
const BOSS_DYNAMIC_MULT: float = 34.0
const BOSS_DYNAMIC_CAP: float = 2.4
# A single combat hit may never remove more than this share of the player's
# max HP (applied after armor reduction, at the hurt_player funnel).
# Lava and other terrain DoT ticks do not pass through this cap.
const HIT_CAP_RATIO: float = 0.70
const BOSS_HIT_CAP_RATIO: float = HIT_CAP_RATIO

static func cap_boss_hp(formula_hp: float, power: float) -> float:
    var dynamic_hp: float = power * BOSS_DYNAMIC_MULT
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

static func enemy_profile(wave: int, kind: String, adaptive: float = 1.0, elite: bool = false) -> Dictionary:
    var stage: int = maxi(1, wave)
    var milestones: int = stage / 5
    var hp_scale: float = exp(minf(27.6, (stage - 1) * log(1.10) + milestones * log(1.45))) * clampf(adaptive, 1.0, ADAPT_CAP)
    var milestone_log: float = minf(float(milestones), 3.0) * log(1.18) + maxf(0.0, float(milestones) - 3.0) * log(1.10)
    var damage_scale: float = minf(1000000.0, (1.0 + 0.06 * (stage - 1)) * exp(minf(14.0, milestone_log)))
    var dodge: float = minf(0.22, maxf(0, stage - 2) * 0.006 + milestones * 0.012) if stage > 2 else 0.0
    if kind in ["tank", "boss", "armored"]:
        dodge *= 0.35
    elif kind == "charger":
        dodge *= 0.65
    if elite and stage > 2:
        dodge += 0.05
    var data: Dictionary = Catalog.DINOS.get(kind, EnemyRoster.NEW_DATA.get(kind, Catalog.DINOS["hunter"]))
    return {
        "hp": data["hp"] * hp_scale * (1.8 if elite else 1.0),
        "damage": float(BASE_DAMAGE.get(kind, EnemyRoster.base_damage(kind))) * damage_scale * (1.35 if elite else 1.0),
        "dodge": minf(0.30, dodge),
        "speed_multiplier": 1.0 + minf(0.35, (stage - 1) * 0.009 + milestones * 0.025),
        "bullet_multiplier": 1.0 + minf(0.30, (stage - 1) * 0.007)
    }
