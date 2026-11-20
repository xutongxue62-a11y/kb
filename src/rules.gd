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

# Powder can either fire shells or launch one chained melee weapon, not both,
# and it can launch only one chain recipe at a time. A catalyst (fire / magic /
# thunder) may attach to several hosts at once, but one host accepts only one
# enchantment; a new compatible attachment replaces the old one on that host.
static func uses_powder_shells(recipe: Dictionary) -> bool:
    return str(recipe.get("id", "")) in ["rune_shell", "fire_cannon", "thunder_shell"]

static func is_chain_recipe(recipe: Dictionary) -> bool:
    return str(recipe.get("kind", "")) == "chain"

static func is_catalyst_weapon(weapon_id: String) -> bool:
    return weapon_id in ["staff", "firepot", "totem"]

static func recipe_catalyst_id(recipe: Dictionary) -> String:
    for weapon_id in recipe.get("weapons", []):
        var key: String = str(weapon_id)
        if is_catalyst_weapon(key):
            return key
    return ""

static func enchant_host_id(recipe: Dictionary) -> String:
    var catalyst: String = recipe_catalyst_id(recipe)
    if catalyst.is_empty():
        return ""
    for weapon_id in recipe.get("weapons", []):
        var key: String = str(weapon_id)
        if key != catalyst:
            return key
    return ""

static func recipes_conflict(first: Dictionary, second: Dictionary) -> bool:
    var first_id: String = str(first.get("id", ""))
    var second_id: String = str(second.get("id", ""))
    if first_id.is_empty() or second_id.is_empty() or first_id == "none" or second_id == "none" or first_id == second_id:
        return false
    var first_chain: bool = is_chain_recipe(first)
    var second_chain: bool = is_chain_recipe(second)
    if first_chain and second_chain:
        return true
    if (first_chain and uses_powder_shells(second)) or (second_chain and uses_powder_shells(first)):
        return true
    var first_host: String = enchant_host_id(first)
    var second_host: String = enchant_host_id(second)
    if not first_host.is_empty() and first_host == second_host:
        return true
    return false

static func normalize_link_ids(link_ids: Array, owned: Array) -> Array:
    var result: Array = []
    for entry in link_ids:
        var link_id: String = str(entry)
        if link_id == "none" or not Catalog.LINKS.has(link_id) or result.has(link_id):
            continue
        var profile: Dictionary = link_profile(link_id, owned)
        if str(profile.get("id", "none")) == "none":
            continue
        result.append(link_id)
    return result

static func profiles_for_ids(link_ids: Array, owned: Array = []) -> Array:
    var result: Array = []
    for link_id in link_ids:
        var key: String = str(link_id)
        if key == "none" or not Catalog.LINKS.has(key):
            continue
        var profile: Dictionary = Catalog.LINKS[key].duplicate(true) if owned.is_empty() else link_profile(key, owned)
        if str(profile.get("id", "none")) == "none":
            continue
        result.append(profile)
    return result

static func add_link_ids(current_ids: Array, new_id: String, owned: Array) -> Dictionary:
    var wanted: String = str(new_id)
    var current: Array = normalize_link_ids(current_ids, owned)
    if wanted == "none":
        return {"ids": [], "added": "", "dropped": current.duplicate(), "unchanged": current.is_empty()}
    var profile: Dictionary = link_profile(wanted, owned)
    if str(profile.get("id", "none")) == "none":
        return {"ids": current, "added": "", "dropped": [], "unchanged": true, "invalid": true}
    if current.has(wanted):
        return {"ids": current, "added": "", "dropped": [], "unchanged": true}
    var kept: Array = []
    var dropped: Array = []
    for link_id in current:
        if recipes_conflict(Catalog.LINKS[link_id], profile):
            dropped.append(link_id)
        else:
            kept.append(link_id)
    kept.append(wanted)
    return {"ids": kept, "added": wanted, "dropped": dropped, "unchanged": false}

static func remove_link_ids(current_ids: Array, remove_id: String, owned: Array) -> Array:
    var result: Array = []
    var skip: String = str(remove_id)
    for link_id in normalize_link_ids(current_ids, owned):
        if link_id != skip:
            result.append(link_id)
    return result

static func links_for_weapon(link_ids: Array, weapon_id: String) -> Array:
    var result: Array = []
    if weapon_id.is_empty():
        return result
    for link_id in link_ids:
        var key: String = str(link_id)
        if key == "none" or not Catalog.LINKS.has(key):
            continue
        if Catalog.LINKS[key].get("weapons", []).has(weapon_id):
            result.append(key)
    return result

static func suppressed_weapon_ids(links: Array) -> Array:
    var result: Array = []
    for recipe in links:
        for weapon_id in recipe.get("suppressed", []):
            var key: String = str(weapon_id)
            if not key.is_empty() and not result.has(key):
                result.append(key)
    return result

static func chain_profile(links: Array) -> Dictionary:
    for recipe in links:
        if is_chain_recipe(recipe):
            return recipe
    return {}

static func has_link_kind(links: Array, kind: String) -> bool:
    for recipe in links:
        if str(recipe.get("kind", "")) == kind:
            return true
    return false

static func has_link_id(links: Array, link_id: String) -> bool:
    for recipe in links:
        if str(recipe.get("id", "")) == link_id:
            return true
    return false

static func weapon_cooldown_multiplier(weapon_id: String, links: Array) -> float:
    var penalty: float = 1.0
    for recipe in links:
        var applies: bool = str(recipe.get("reload_weapon", "")) == weapon_id
        if not applies and weapon_id == "powder" and recipe.get("weapons", []).has("powder"):
            applies = true
        if applies:
            penalty = maxf(penalty, float(recipe.get("cooldown_multiplier", 1.0)))
    return penalty

static func powder_attack_range(links: Array) -> float:
    var chain: Dictionary = chain_profile(links)
    if not chain.is_empty():
        return float(chain.get("range", 210.0))
    var reach: float = -1.0
    for recipe in links:
        if recipe.get("weapons", []).has("powder"):
            reach = maxf(reach, float(recipe.get("range", 395.0)))
    return 395.0 if reach < 0.0 else reach

static func host_enchant_kinds(links: Array, weapon_id: String) -> Array:
    var kinds: Array = []
    for recipe in links:
        if enchant_host_id(recipe) != weapon_id:
            continue
        var kind: String = str(recipe.get("kind", ""))
        if kind in ["", "none", "chain", "fire_drum", "thunder_crystal"]:
            continue
        var mapped: String = "thunder_enchant" if kind == "storm_arrow" else kind
        if not kinds.has(mapped):
            kinds.append(mapped)
    return kinds

static func host_is_rune_enchanted(links: Array, weapon_id: String) -> bool:
    var kinds: Array = host_enchant_kinds(links, weapon_id)
    return kinds.has("rune") or kinds.has("rune_enchant")

static func host_is_fire_enchanted(links: Array, weapon_id: String) -> bool:
    return host_enchant_kinds(links, weapon_id).has("fire_enchant")

static func host_is_thunder_enchanted(links: Array, weapon_id: String) -> bool:
    return host_enchant_kinds(links, weapon_id).has("thunder_enchant")

static func reload_multipliers(links: Array) -> Dictionary:
    var result: Dictionary = {}
    for recipe in links:
        var key: String = str(recipe.get("reload_weapon", ""))
        if key.is_empty() and recipe.get("weapons", []).has("powder"):
            key = "powder"
        if key.is_empty():
            continue
        result[key] = maxf(float(result.get(key, 1.0)), float(recipe.get("cooldown_multiplier", 1.0)))
    return result

static func link_ids_of(links: Array) -> Array:
    var result: Array = []
    for recipe in links:
        var link_id: String = str(recipe.get("id", ""))
        if not link_id.is_empty() and link_id != "none" and not result.has(link_id):
            result.append(link_id)
    return result

static func combined_link_view(links: Array) -> Dictionary:
    var profiles: Array = []
    for recipe in links:
        if str(recipe.get("id", "none")) != "none":
            profiles.append(recipe)
    if profiles.is_empty():
        var empty: Dictionary = Catalog.LINKS["none"].duplicate(true)
        empty["links"] = []
        empty["link_ids"] = []
        return empty
    if profiles.size() == 1:
        var single: Dictionary = profiles[0].duplicate(true)
        single["links"] = [profiles[0].duplicate(true)]
        single["link_ids"] = [str(profiles[0].get("id", ""))]
        single["suppressed"] = suppressed_weapon_ids(profiles)
        return single
    var names: PackedStringArray = PackedStringArray()
    var summaries: PackedStringArray = PackedStringArray()
    var benefits: PackedStringArray = PackedStringArray()
    var costs: PackedStringArray = PackedStringArray()
    var weapons: Array = []
    for recipe in profiles:
        names.append(str(recipe.get("name", "")))
        var summary: String = str(recipe.get("summary", "")).replace("\n", " · ")
        if not summary.is_empty():
            summaries.append(summary)
        var benefit: String = Catalog.benefit_text(recipe)
        if not benefit.is_empty():
            benefits.append(benefit)
        var cost: String = Catalog.cost_text(recipe)
        if not cost.is_empty():
            costs.append(cost)
        for weapon_id in recipe.get("weapons", []):
            if not weapons.has(weapon_id):
                weapons.append(weapon_id)
    var view: Dictionary = profiles.back().duplicate(true)
    view["id"] = str(profiles.back().get("id", "none"))
    view["name"] = "、".join(names)
    view["kind"] = "multi"
    view["summary"] = "、".join(summaries)
    view["benefit"] = "；".join(benefits)
    view["cost"] = "；".join(costs)
    view["weapons"] = weapons
    view["suppressed"] = suppressed_weapon_ids(profiles)
    view["cooldown_multiplier"] = weapon_cooldown_multiplier("powder", profiles)
    view["range"] = powder_attack_range(profiles)
    view["enchanted"] = host_is_rune_enchanted(profiles, "powder")
    view["links"] = []
    for recipe in profiles:
        view["links"].append(recipe.duplicate(true))
    view["link_ids"] = link_ids_of(profiles)
    return view

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


const EXPLORER_PICKUP_BONUS: float = 30.0
const MAGNET_WAVE_BONUS: float = 10.0
const MAGNET_WAVE_STEPS: int = 10
const WARD_INTERVAL: float = 0.70
const WARD_TARGET_COOLDOWN: float = 1.55
const PARALYZE_DURATION: float = 0.28
const PARALYZE_BOSS_DURATION: float = 0.12
const PARALYZE_INTERVAL: float = 2.5
const BURN_TICK_SCALE: float = 0.50

static func spawn_interval(wave: int) -> float:
    var stage: int = maxi(1, wave)
    if stage <= 3:
        return 0.40 - float(stage - 1) * 0.04
    return maxf(0.14, 0.32 - float(stage - 3) * 0.008)

static func spawn_interval_for(wave: int, _boss_round: bool = false, _boss_defeated: bool = false) -> float:
    # A Boss stage, including the post-death cleanup window, uses the same
    # regular spawn cadence as a normal stage of this wave.
    return spawn_interval(wave)

static func enemy_limit_for(wave: int) -> int:
    var stage: int = maxi(1, wave)
    return 50 + clampi((stage - 2) * 2, 0, 50) + clampi((stage - 24) * 4, 0, 56)

static func magnet_wave_bonus(wave: int) -> float:
    return MAGNET_WAVE_BONUS * float(clampi(wave - 3, 0, MAGNET_WAVE_STEPS))

static func ward_profile(source: String, level: int = 1) -> Dictionary:
    # Staff is damage-only. Thunder, from 进阶 onward, briefly roots in place
    # with a long per-target cooldown instead of shoving the monster away.
    if source == "staff":
        return {"kind": "none", "distance": 0.0, "duration": 0.0, "interval": 0.0, "target_cooldown": 0.0}
    if source == "thunder":
        var stage: int = 2 if level >= 5 else (1 if level >= 3 else 0)
        if stage <= 0:
            return {"kind": "none", "distance": 0.0, "duration": 0.0, "interval": PARALYZE_INTERVAL, "once": true}
        return {"kind": "paralyze", "distance": 0.0, "duration": PARALYZE_DURATION, "interval": PARALYZE_INTERVAL, "once": true}
    return {"kind": "none", "distance": 0.0, "duration": 0.0, "interval": 0.0, "target_cooldown": 0.0}
