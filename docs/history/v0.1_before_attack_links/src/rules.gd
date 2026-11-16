extends RefCounted
const Catalog = preload("res://src/catalog.gd")
const MAX_WEAPONS: int = 6

static func equip(inventory: Array, weapon_id: String) -> Dictionary:
    if not Catalog.WEAPONS.has(weapon_id):
        return {"accepted": false, "reason": "unknown"}
    for entry in inventory:
        if entry["id"] == weapon_id:
            if entry["level"] >= 5:
                return {"accepted": false, "reason": "max_level"}
            entry["level"] += 1
            return {"accepted": true, "upgraded": true}
    if inventory.size() >= MAX_WEAPONS:
        return {"accepted": false, "reason": "full"}
    inventory.append({"id": weapon_id, "level": 1})
    return {"accepted": true, "upgraded": false}

static func choose_target(origin: Vector2, attack_range: float, candidates: Array, prefer_elite: bool = false) -> Dictionary:
    if attack_range < 0.0:
        return {}
    var nearest: Dictionary = {}
    var elite: Dictionary = {}
    var nearest_distance: float = INF
    var elite_distance: float = INF
    for candidate in candidates:
        if float(candidate.get("hp", 0.0)) <= 0.0:
            continue
        var distance: float = origin.distance_squared_to(candidate["position"])
        if distance > attack_range * attack_range:
            continue
        if distance < nearest_distance:
            nearest = candidate
            nearest_distance = distance
        if candidate.get("elite", false) and distance < elite_distance:
            elite = candidate
            elite_distance = distance
    return elite if prefer_elite and not elite.is_empty() else nearest

static func combo_groups(owned: Array, mode: String = "triple") -> Array:
    var available: Array = owned.duplicate()
    var result: Array = []
    var candidates: Array = []
    if mode == "triple":
        candidates.append_array(Catalog.TRIPLES)
    candidates.append_array(Catalog.PAIRS)
    for group in candidates:
        var complete: bool = true
        for weapon_id in group["weapons"]:
            if not available.has(weapon_id):
                complete = false
        if not complete:
            continue
        result.append(group)
        for weapon_id in group["weapons"]:
            available.erase(weapon_id)
    return result

static func advance_combos(counters: Dictionary, event: Dictionary, groups: Array) -> Array:
    if event.get("from_combo", false):
        return []
    var result: Array = []
    for group in groups:
        if not group["weapons"].has(event.get("weapon_id", "")):
            continue
        var combo_id: String = group["id"]
        var count: int = int(counters.get(combo_id, 0)) + 1
        var threshold: int = maxi(1, int(group["hits"]))
        counters[combo_id] = count % threshold
        if count >= threshold:
            result.append(group)
    return result

static func advance_gait(phase: float, distance: float, stride: float = 38.0) -> float:
    return fposmod(phase + maxf(distance, 0.0) / maxf(stride, 1.0) * TAU, TAU)

static func gait_pose(phase: float, direction: Vector2, amplitude: float) -> Dictionary:
    var amount: float = clampf(amplitude, 0.0, 1.0)
    var wave: float = sin(phase)
    var travel: Vector2 = direction.normalized() * wave * 3.8 * amount
    return {
        "left_foot": travel + Vector2(0.0, -maxf(wave, 0.0) * 1.6 * amount),
        "right_foot": -travel + Vector2(0.0, -maxf(-wave, 0.0) * 1.6 * amount),
        "left_hand": -travel * 0.58,
        "right_hand": travel * 0.58,
        "body": Vector2(0.0, -absf(wave) * 1.3 * amount),
        "rotation": wave * 0.021 * amount
    }

static func orbit_position(index: int, count: int, phase: float, collapsed: bool) -> Vector2:
    if count <= 0:
        return Vector2.ZERO
    var radius: float = 76.0 if collapsed else 112.0
    return Vector2.from_angle(phase + TAU * float(index) / float(count)) * radius
