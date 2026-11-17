extends RefCounted
const Catalog = preload("res://src/catalog.gd")
const Growth = preload("res://src/growth.gd")
const MAX_WEAPONS: int = 6

static func equip(inventory: Array, weapon_id: String) -> Dictionary:
    if not Catalog.WEAPONS.has(weapon_id):
        return {"accepted": false, "reason": "unknown"}
    for entry in inventory:
        if entry["id"] == weapon_id:
            if entry["level"] >= Growth.MAX_WEAPON_LEVEL:
                return {"accepted": false, "reason": "max_level"}
            entry["level"] += 1
            return {"accepted": true, "upgraded": true}
    if inventory.size() >= MAX_WEAPONS:
        return {"accepted": false, "reason": "full"}
    inventory.append({"id": weapon_id, "level": 1})
    return {"accepted": true, "upgraded": false}

static func replace_weapon(inventory: Array, remove_id: String, new_id: String, new_level: int = 1) -> Dictionary:
    if not Catalog.WEAPONS.has(new_id):
        return {"accepted": false, "reason": "unknown"}
    if str(remove_id) == str(new_id):
        return {"accepted": false, "reason": "same"}
    for entry in inventory:
        if entry["id"] == new_id:
            return {"accepted": false, "reason": "already_owned"}
    var index: int = -1
    for i in range(inventory.size()):
        if inventory[i]["id"] == remove_id:
            index = i
            break
    if index < 0:
        return {"accepted": false, "reason": "missing"}
    inventory[index] = {"id": new_id, "level": clampi(new_level, 1, 5)}
    return {"accepted": true, "index": index, "level": int(inventory[index]["level"])}

static func is_stone(candidate: Dictionary) -> bool:
    return bool(candidate.get("stone", false)) or str(candidate.get("kind", "")) == "stone"

static func is_egg(candidate: Dictionary) -> bool:
    return str(candidate.get("state", "")) == "egg"

# Hatched, living dinosaurs only. Stones and unhatched eggs are secondary targets.
static func is_living_monster(candidate: Dictionary) -> bool:
    return not is_stone(candidate) and not is_egg(candidate) and float(candidate.get("hp", 0.0)) > 0.0

static func has_monster_in_range(origin: Vector2, attack_range: float, candidates: Array) -> bool:
    if attack_range < 0.0:
        return false
    var reach_sq: float = attack_range * attack_range
    for candidate in candidates:
        if not is_living_monster(candidate):
            continue
        if origin.distance_squared_to(candidate["position"]) <= reach_sq:
            return true
    return false

static func has_living_monster(candidates: Array) -> bool:
    for candidate in candidates:
        if is_living_monster(candidate):
            return true
    return false

static func has_egg_target(candidates: Array) -> bool:
    for candidate in candidates:
        if is_egg(candidate) and float(candidate.get("hp", 0.0)) > 0.0:
            return true
    return false

# Living dinosaurs first; unhatched eggs next; stones only when nothing else is available.
static func should_defer_target(candidate: Dictionary, candidates: Array) -> bool:
    if is_egg(candidate) and has_living_monster(candidates):
        return true
    if is_stone(candidate) and (has_living_monster(candidates) or has_egg_target(candidates)):
        return true
    return false

static func scaled_range(data: Dictionary, stats: Dictionary) -> float:
    return float(data.get("range", 0.0)) * float(stats.get("range_multiplier", 1.0))

static func choose_target(origin: Vector2, attack_range: float, candidates: Array, prefer_elite: bool = false) -> Dictionary:
    if attack_range < 0.0:
        return {}
    var nearest: Dictionary = {}
    var elite: Dictionary = {}
    var nearest_distance: float = INF
    var elite_distance: float = INF
    var has_enemy: bool = has_monster_in_range(origin, attack_range, candidates)
    var has_egg: bool = false
    if not has_enemy:
        for candidate in candidates:
            if is_egg(candidate) and float(candidate.get("hp", 0.0)) > 0.0 and origin.distance_squared_to(candidate["position"]) <= attack_range * attack_range:
                has_egg = true
                break
    for candidate in candidates:
        if has_enemy and (is_stone(candidate) or is_egg(candidate)):
            continue
        if not has_enemy and has_egg and is_stone(candidate):
            continue
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

static func link_options(owned: Array) -> Array:
    var result: Array = []
    for key in Catalog.LINK_ORDER:
        var recipe: Dictionary = Catalog.LINKS[key]
        var available: bool = true
        for weapon_id in recipe["weapons"]:
            if not owned.has(weapon_id):
                available = false
        if available:
            result.append(recipe.duplicate(true))
    return result

static func link_profile(link_id: String, owned: Array) -> Dictionary:
    for recipe in link_options(owned):
        if recipe["id"] == link_id:
            return recipe
    return Catalog.LINKS["none"].duplicate(true)

static func ranged_mount(weapon_id: String) -> Vector2:
    match weapon_id:
        "powder": return Vector2(70, 12)
        "staff": return Vector2(-70, 3)
        "sling": return Vector2(32, -67)
    return Vector2.ZERO

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

# Six carried-weapon slots: left-up, left-mid, left-down, right-up, right-mid, right-down.
const SLOT_ANGLES: Array = [-5.0 * PI / 6.0, PI, 5.0 * PI / 6.0, -PI / 6.0, 0.0, PI / 6.0]
const SLOT_LAYOUTS: Dictionary = {
    1: [4],
    2: [1, 4],
    3: [1, 3, 5],
    4: [0, 2, 3, 5],
    5: [0, 1, 2, 3, 5],
    6: [0, 1, 2, 3, 4, 5]
}
# Parked ranged / magic / thrown / support sit against the hands.
# Orbiting melee keeps the farther ring so the circle stays readable.
const MELEE_ORBIT: float = 100.0
const MELEE_ORBIT_COLLAPSED: float = 74.0
const PARKED_RADIUS: float = 44.0
const PARKED_RADIUS_COLLAPSED: float = 38.0
const PARKED_MAX_ANCHOR: float = 62.0
const PARKED_MID_HAND_Y: float = 0.0
const HAND_LEFT: Vector2 = Vector2(-31.92797, 11.79237)
const HAND_RIGHT: Vector2 = Vector2(35.42373, 11.79237)
const PARKED_HAND_GAP: float = 3.0
const RANGED_ORBIT: float = 44.0
const RANGED_ORBIT_COLLAPSED: float = 38.0
const GRIP_FRACTIONS: Dictionary = {
    "sling":0.22,"powder":0.50,"staff":0.38,"bonebow":0.31,
    "spear":0.30,"hammer":0.26,"boomerang":0.34,"totem":0.28,
    "firepot":0.50,"wardrum":0.34,"crystal":0.34
}
# Eggs hatch slowly enough to smash, with a crack telegraph first.
const EGG_ARRIVAL_CHANCE: float = 0.48
const EGG_HATCH_MIN: float = 4.0
const EGG_HATCH_MAX: float = 5.8
const EGG_CRACK_TIME: float = 1.2

static func orbits_with_formation(weapon_id: String) -> bool:
    # Classify from catalog tags and the in-game description, not a hardcoded id list.
    if not Catalog.WEAPONS.has(weapon_id):
        return false
    var data: Dictionary = Catalog.WEAPONS[weapon_id]
    if str(data.get("kind", "")) == "melee":
        return true
    return str(data.get("description", "")).contains("环绕")

static func is_parked_weapon(weapon_id: String) -> bool:
    return not orbits_with_formation(weapon_id)

static func is_ranged_orbit(weapon_id: String) -> bool:
    # Legacy name: parked weapons use the closer radius and do not revolve.
    return is_parked_weapon(weapon_id)

static func orbit_radius_for(weapon_id: String, collapsed: bool) -> float:
    if is_parked_weapon(weapon_id):
        return PARKED_RADIUS_COLLAPSED if collapsed else PARKED_RADIUS
    return MELEE_ORBIT_COLLAPSED if collapsed else MELEE_ORBIT

static func orbit_position(index: int, count: int, phase: float, collapsed: bool) -> Vector2:
    if count <= 0:
        return Vector2.ZERO
    var radius: float = MELEE_ORBIT_COLLAPSED if collapsed else MELEE_ORBIT
    return Vector2.from_angle(phase + TAU * float(index) / float(count)) * radius

static func loadout_slots(count: int) -> Array:
    var n: int = clampi(count, 0, 6)
    if n <= 0:
        return []
    return SLOT_LAYOUTS[n]

static func loadout_offset(index: int, count: int, phase: float, weapon_id: String, collapsed: bool) -> Vector2:
    var slots: Array = loadout_slots(count)
    if slots.is_empty():
        return Vector2.ZERO
    var slot: int = int(slots[index]) if index < slots.size() else int(slots[index % slots.size()])
    var angle: float = float(SLOT_ANGLES[slot])
    # Only true circling melee advances with the formation phase.
    # Ranged, magic, thrown, and support weapons stay parked in their slot.
    if orbits_with_formation(weapon_id):
        angle += phase
    if is_parked_weapon(weapon_id) and (slot == 1 or slot == 4):
        var gap: float = 2.0 if collapsed else PARKED_HAND_GAP
        if slot == 1:
            return Vector2(HAND_LEFT.x - gap, HAND_LEFT.y)
        return Vector2(HAND_RIGHT.x + gap, HAND_RIGHT.y)
    if is_parked_weapon(weapon_id):
        var side: float=-1.0 if slot<3 else 1.0
        var x: float=38.0 if collapsed else (41.0 if slot in [0,3] else 40.0)
        var y: float=(-28.0 if collapsed else -32.0) if slot in [0,3] else (38.0 if collapsed else 42.0)
        return Vector2(side*x,y)
    return Vector2.from_angle(angle) * orbit_radius_for(weapon_id, collapsed)

static func parked_hold_length(weapon_id: String) -> float:
    if not Catalog.WEAPONS.has(weapon_id):
        return 12.0
    var size: float = float(Catalog.WEAPONS[weapon_id].get("size", 36.0))
    var scale: float = 1.0 if weapon_id == "sling" else 1.12
    # The mount is already next to the hand. Only the grip-to-centre length
    # belongs here; adding almost a full weapon length made the art float away.
    return size * scale * float(GRIP_FRACTIONS.get(weapon_id,0.24))

static func parked_aim_limit(_weapon_id: String) -> float:
    # Keep the long padded sprite in a tight outward cone so it cannot sweep through the torso.
    return PI * 0.12

static func parked_aim_direction(mount: Vector2, origin: Vector2, desired: Vector2, max_angle: float = -1.0) -> Vector2:
    var outward: Vector2 = mount - origin
    if outward.length() < 0.001:
        outward = Vector2.RIGHT
    else:
        outward = outward.normalized()
    if desired.length() < 0.001:
        return outward
    var aim: Vector2 = desired.normalized()
    var ang: float = outward.angle_to(aim)
    var limit: float = PI * 0.12 if max_angle < 0.0 else max_angle
    if absf(ang) > limit:
        return outward.rotated(signf(ang) * limit)
    return aim

static func apply_parked_hold(view: Sprite2D, weapon_id: String, origin: Vector2, aim: Vector2, idle: bool = true, aim_limit: float = -1.0) -> void:
    if view == null or not is_instance_valid(view):
        return
    if orbits_with_formation(weapon_id):
        view.offset = Vector2.ZERO
        return
    var limit: float = parked_aim_limit(weapon_id) if aim_limit < 0.0 else aim_limit
    var visual_aim: Vector2 = parked_aim_direction(view.position, origin, aim, limit)
    if idle and weapon_id in ["sling","staff","bonebow","spear"]:
        view.rotation = visual_aim.angle() + PI / 2.0
    elif idle and weapon_id == "powder":
        view.rotation = visual_aim.angle()
    var world_shift: Vector2 = (visual_aim * parked_hold_length(weapon_id)).rotated(-view.rotation)
    if not view.has_meta("base_scale"):
        view.set_meta("base_scale", view.scale)
    var base = view.get_meta("base_scale")
    var axis: float = absf(base.x) if base is Vector2 else absf(view.scale.x)
    view.offset = world_shift / maxf(axis, 0.001)

static func loadout_layout(ids: Array, phase: float, collapsed: bool) -> Dictionary:
    var result: Dictionary = {}
    var count: int = ids.size()
    for index in range(count):
        result[str(ids[index])] = loadout_offset(index, count, phase, str(ids[index]), collapsed)
    return result
