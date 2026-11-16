extends RefCounted

# Unit positions are deterministic and never consume the encounter/reward RNG.
# Late-game clutter is handled by a stronger auto-magnet, not by merging values,
# so saves, collection, and existing unit-loot contracts stay exact.
const GOLDEN_ANGLE: float = 2.399963229728653

static func append_reward(drops: Array, reward: Dictionary, at: Vector2) -> void:
    var xp: float = maxf(0.0, float(reward.get("xp", 0)))
    var coins: int = maxi(0, int(reward.get("coin", 0)))
    var phase: float = fposmod(at.x * 0.01299 + at.y * 0.07823 + drops.size() * 0.618, TAU)
    var index: int = 0
    for kind in ["xp", "coin"]:
        var amount: float = xp if kind == "xp" else float(coins)
        var count: int = int(floorf(amount))
        var fraction: float = amount - float(count)
        if kind == "xp" and fraction > 0.0:
            count += 1
        for unit_index in range(count):
            var offset: Vector2 = Vector2.from_angle(phase + index * GOLDEN_ANGLE) * (14.0 * sqrt(index + 0.5))
            var drop := {"kind":kind, "position":at + offset, "value":1}
            if kind == "xp" and fraction > 0.0 and unit_index == count - 1:
                drop["legacy_fraction"] = fraction
            drops.append(drop)
            index += 1

static func append_blood_pack(drops: Array, at: Vector2, heal: float = 2.0) -> void:
    var phase: float = fposmod(at.x * 0.021 + at.y * 0.053 + drops.size() * 0.618, TAU)
    var offset: Vector2 = Vector2.from_angle(phase) * 16.0
    drops.append({"kind": "blood", "position": at + offset, "value": maxf(0.1, heal)})

static func restore(drops: Array, saved: Dictionary, at: Vector2) -> void:
    var amount: float = float(saved.get("value", 1))
    if amount <= 0.0:
        return
    var kind: String = str(saved.get("kind", "xp"))
    if kind == "blood":
        drops.append({"kind": "blood", "position": at, "value": amount})
        return
    if amount == 1.0:
        var drop := {"kind":kind, "position":at, "value":1}
        if saved.has("legacy_fraction"):
            drop["legacy_fraction"] = float(saved.legacy_fraction)
        drops.append(drop)
    else:
        append_reward(drops, {kind:amount}, at)

static func experience_value(drop: Dictionary) -> float:
    return float(drop.get("value", 1)) * float(drop.get("legacy_fraction", 1.0))
