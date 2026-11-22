extends RefCounted
const BattleVisuals=preload("res://src/battle_visuals.gd")
const CombatArt=preload("res://src/combat_art.gd")

const Catalog = preload("res://src/catalog.gd")
const Rules = preload("res://src/rules.gd")
const Evolution = preload("res://src/weapon_evolution.gd")
const INK: Color = Color("#48372c")
const MOUNTS = {
    "bonebow": Vector2(70, -34),
    "firepot": Vector2(-58, 48),
    "wardrum": Vector2(12, 67),
    "crystal": Vector2(-63, -53)
}

static func create_state(key: String, hero: Vector2) -> Dictionary:
    return {"phase": "rest", "cooldown": 0.0, "age": 0.0, "has_fired": false, "position": hero + MOUNTS[key], "direction": Vector2.RIGHT, "arrows": [], "pots": [], "fires": [], "waves": [], "mines": [], "shards": [], "beat_count": 0}

static func hit(target: Dictionary, damage: float, key: String, direction: Vector2) -> Dictionary:
    return {"type": "hit", "enemy": target, "damage": damage, "weapon_id": key, "direction": direction}

static func advance(key: String, delta: float, hero: Vector2, targets: Array, item: Dictionary, stats: Dictionary, prefer_elite: bool, view: Sprite2D, state: Dictionary, mount_point: Vector2 = Vector2(INF, INF)) -> Array:
    var events: Array = []
    var dt: float = maxf(0.0, delta) * maxf(0.0, float(stats.get("attack_speed", 1.0)))
    var data: Dictionary = Catalog.WEAPONS[key]
    var level: int = clampi(int(item.get("level", 1)), 1, 10)
    var stage: int=Evolution.tier(level)
    state["evolution"]=stage
    var damage: float = data["damage"] * Evolution.damage_multiplier(key, level) * float(stats.get("enchant_mults", {}).get(key, 1.0))
    var area: float = maxf(0.1, float(stats.get("area_multiplier", 1.0)))
    var bullet_speed: float = maxf(0.1, float(stats.get("bullet_speed", 1.0)))
    var mount: Vector2 = mount_point if mount_point.is_finite() else hero + MOUNTS[key]
    state["cooldown"] = maxf(0.0, state["cooldown"] - dt)
    state["age"] += dt
    var target_origin: Vector2=mount if key=="bonebow" else hero
    var mastery: Dictionary = Catalog.exclusive_bonus(str(stats.get("character_id", "")), key)
    var reach: float = Rules.scaled_range(data, stats) * (area if key == "wardrum" else 1.0)
    if key == "bonebow" and mastery.has("range_multiplier"):
        reach *= float(mastery["range_multiplier"])
    var target: Dictionary = Rules.choose_target(target_origin, reach, targets, prefer_elite)
    if not target.is_empty():
        var aim: Vector2 = target["position"] - mount
        state["direction"] = aim.normalized() if aim.length_squared() > 0.01 else Vector2.RIGHT
    view.position = mount
    view.rotation = state["direction"].angle() + PI / 2.0 if key == "bonebow" else 0.0
    var hold_aim: Vector2 = state["direction"] if Vector2(state.get("direction", Vector2.RIGHT)).length() > 0.01 else (mount - hero)
    var idle_presentation: bool = key != "bonebow" or (target.is_empty() and (not state["has_fired"] or state["age"] > 0.16))
    Rules.apply_parked_hold(view, key, hero, hold_aim, idle_presentation)
    if key == "firepot":
        events.append_array(try_fire_pillar(state, item, target, damage, area, dt, stage))
    if state["cooldown"] <= 0.0 and not target.is_empty() and not (key == "wardrum" and state["phase"] == "playing"):
        state["cooldown"] = data["cooldown"] / (1.0 + (level - 1) * 0.08)
        var reload_map: Dictionary = stats.get("reload_multipliers", {})
        var reload_penalty: float = float(reload_map.get(key, 1.0)) if typeof(reload_map) == TYPE_DICTIONARY else 1.0
        if is_equal_approx(reload_penalty, 1.0) and key==stats.get("reload_weapon",""):
            reload_penalty = float(stats.get("reload_multiplier",1.0))
        state.cooldown*=reload_penalty
        state["age"] = 0.0
        state["has_fired"] = true
        events.append({"type": "flash", "weapon_id": key})
        match key:
            "bonebow":
                for arrow in range(1+stage):
                    var side: Vector2=Vector2(state.direction).orthogonal()*((arrow-stage*0.5)*11.0)
                    var shot: Dictionary=projectile(mount+state.direction*22.0+side,state.direction,damage*(1.0 if stage==0 else (0.70 if stage==1 else 0.58)),data.speed*bullet_speed,reach,[])
                    var pierce_limit: int = 5 if stage>=2 else 3
                    if mastery.has("pierce_limit"):
                        pierce_limit = maxi(pierce_limit, int(mastery["pierce_limit"]))
                    shot["pierce_limit"]=pierce_limit
                    var kinds: Array = stats.get("link_kinds", [])
                    if typeof(kinds) != TYPE_ARRAY or kinds.is_empty():
                        kinds = [str(stats.get("link_kind", "none"))]
                    var bonebow_hosted: bool = str(stats.get("reload_weapon", "")) == "bonebow" or (typeof(reload_map) == TYPE_DICTIONARY and float(reload_map.get("bonebow", 1.0)) > 1.0)
                    var fire_shot: bool = bonebow_hosted and kinds.has("fire_enchant")
                    var rune_shot: bool = bonebow_hosted and (kinds.has("rune_enchant") or kinds.has("rune"))
                    var thunder_shot: bool = bonebow_hosted and (kinds.has("thunder_enchant") or kinds.has("storm_arrow"))
                    if fire_shot or rune_shot or thunder_shot:
                        shot["enchanted"] = rune_shot
                        shot["fire_enchanted"] = fire_shot
                        shot["thunder_enchanted"] = thunder_shot
                        shot["vfx_tier"] = int(stats.get("staff_tier", 0)) if rune_shot else 0
                        shot["fire_tier"] = int(stats.get("firepot_tier", 0)) if fire_shot else 0
                        shot["thunder_tier"] = int(stats.get("totem_tier", 0)) if thunder_shot else 0
                        shot["thunder_red"] = thunder_shot and (bool(stats["bonebow_next_red"]) if stats.has("bonebow_next_red") else (randf() < Rules.red_lightning_chance(int(stats.get("totem_level", 1)))))
                        shot["link_kind"] = "rune_enchant" if rune_shot else ("fire_enchant" if fire_shot else "thunder_enchant")
                    state.arrows.append(shot)
            "firepot":
                var flight: float = clampf(mount.distance_to(target["position"]) / data["speed"], 0.32, 0.65)
                for pot in range(1+stage):
                    var offset: Vector2=Vector2(state.direction).orthogonal()*((pot-stage*0.5)*48.0)
                    var pot_damage: float = damage*(1.0 if stage==0 else (0.65 if stage==1 else 0.50))
                    var pot_radius: float = 56.0*area
                    var pot_life: float = 1.45 if stage>=2 else 1.15
                    if not mastery.is_empty():
                        pot_damage *= float(mastery.get("damage_multiplier", 1.0))
                        pot_radius *= float(mastery.get("area_multiplier", 1.0))
                        pot_life *= float(mastery.get("life_multiplier", 1.0))
                    state.pots.append({"from":mount,"position":target.position+offset,"age":0.0,"flight":flight,"damage":pot_damage,"radius":pot_radius,"life":pot_life})
            "wardrum":
                state["phase"] = "playing"
                state["beat_count"] = 0
            "crystal":
                state["mines"].append({"from": mount, "position": target["position"], "age": 0.0, "damage": damage, "speed": data["speed"] * bullet_speed, "trigger": 78.0 * area,"fragments":10 if stage>=1 else 8,"bursts_left":2 if stage>=2 else 1})
    match key:
        "bonebow":
            advance_projectiles(state["arrows"], dt, targets, events, key)
            if state["has_fired"]:
                view.position -= state["direction"] * maxf(0.0, 1.0 - state["age"] / 0.16) * 8.0
        "firepot":
            advance_firepots(state, dt, targets, events)
            if state["has_fired"]:
                view.rotation = -sin(minf(state["age"] / 0.35, 1.0) * PI) * 0.35
        "wardrum":
            advance_drum(state, dt, hero, targets, damage, area, events)
            var drum_kinds: Array = stats.get("link_kinds", [])
            if stats.get("link_kind","")=="fire_drum" or (typeof(drum_kinds)==TYPE_ARRAY and drum_kinds.has("fire_drum")):
                state["fan_fire"]=true
            view.position.y -= maxf(0.0, sin(state["age"] / 0.24 * TAU)) * 3.5 if state["phase"] == "playing" else 0.0
        "crystal":
            advance_projectiles(state["shards"], dt, targets, events, key)
            advance_crystals(state, dt, targets, events)
            view.rotation = sin(state["age"] * 3.0) * 0.05
    state["position"] = view.position
    return events

static func projectile(point: Vector2, direction: Vector2, damage: float, speed: float, reach: float, shared_hits: Array) -> Dictionary:
    return {"position": point, "direction": direction, "damage": damage, "speed": speed, "left": reach, "hit_ids": shared_hits, "hit_count": 0}

static func advance_projectiles(projectiles: Array, dt: float, targets: Array, events: Array, key: String) -> void:
    for index in range(projectiles.size() - 1, -1, -1):
        var shot: Dictionary = projectiles[index]
        var before: Vector2 = shot["position"]
        var distance: float = minf(shot["left"], shot["speed"] * dt)
        var after: Vector2 = before + shot["direction"] * distance
        var crossed: Array = []
        for target in targets:
            if target["hp"] <= 0.0 or shot["hit_ids"].has(target["id"]):
                continue
            if Geometry2D.get_closest_point_to_segment(target["position"], before, after).distance_to(target["position"]) <= target["radius"] + 6.0:
                crossed.append(target)
        # Pierce the nearest bodies first even when the roster is in spawn order.
        crossed.sort_custom(func(first, second): return before.distance_squared_to(first["position"]) < before.distance_squared_to(second["position"]))
        for target in crossed:
            if shot["hit_count"] >= int(shot.get("pierce_limit",3)):
                break
            shot["hit_ids"].append(target["id"])
            var dealt_damage: float = float(shot["damage"]) * pow(Rules.SECONDARY_HIT_DECAY, float(shot["hit_count"]))
            shot["hit_count"] += 1
            var ev: Dictionary = hit(target, dealt_damage, key, shot["direction"])
            if bool(shot.get("thunder_enchanted", false)):
                ev["thunder_enchanted"] = true
                ev["thunder_red"] = bool(shot.get("thunder_red", false))
            events.append(ev)
        shot["position"] = after
        shot["left"] -= distance
        if shot["left"] <= 0.0 or shot["hit_count"] >= int(shot.get("pierce_limit",3)):
            projectiles.remove_at(index)

static func advance_firepots(state: Dictionary, dt: float, targets: Array, events: Array) -> void:
    var fires: Array = state["fires"]
    for index in range(fires.size() - 1, -1, -1):
        var fire: Dictionary = fires[index]
        fire["age"] += dt
        # Fixed tick times keep an overlap from becoming a per-frame attack.
        while fire["next_tick"] <= minf(fire["age"], float(fire.get("life",1.85))-0.1):
            for target in targets:
                if target["hp"] > 0.0 and fire["position"].distance_to(target["position"]) <= fire["radius"] + target["radius"]:
                    events.append(hit(target, fire["damage"], "firepot", (target["position"] - fire["position"]).normalized()))
            fire["next_tick"] += 0.48
        if fire["age"] > float(fire.get("life",1.15)):
            fires.remove_at(index)
    var pots: Array = state["pots"]
    for index in range(pots.size() - 1, -1, -1):
        var pot: Dictionary = pots[index]
        pot["age"] += dt
        if pot["age"] >= pot["flight"]:
            fires.append({"position": pot["position"], "age": -0.18 + pot["age"] - pot["flight"], "next_tick": 0.0, "damage": pot["damage"] * Rules.BURN_TICK_SCALE, "radius": pot["radius"],"life":pot.get("life",1.85)})
            pots.remove_at(index)

static func advance_drum(state: Dictionary, dt: float, hero: Vector2, targets: Array, damage: float, area: float, events: Array) -> void:
    var waves: Array = state["waves"]
    var beats: int=3+int(state.get("evolution",0))
    if state["phase"] == "playing":
        while state["beat_count"] < beats and state["age"] >= state["beat_count"] * 0.24:
            waves.append({"position": hero, "radius": 0.0, "maximum": 148.0 * area*(1.25 if beats==5 and state.beat_count==4 else 1.0), "damage": damage, "hit_ids": [], "beat": state["beat_count"]})
            state["beat_count"] += 1
    for index in range(waves.size() - 1, -1, -1):
        var wave: Dictionary = waves[index]
        var before: float = wave["radius"]
        wave["radius"] = minf(wave["maximum"], before + 440.0 * area * dt)
        for target in targets:
            if target["hp"] <= 0.0 or wave["hit_ids"].has(target["id"]):
                continue
            var distance: float = wave["position"].distance_to(target["position"])
            if distance + target["radius"] + 5.0 >= before and distance - target["radius"] - 5.0 <= wave["radius"]:
                wave["hit_ids"].append(target["id"])
                events.append(hit(target, wave["damage"], "wardrum", (target["position"] - wave["position"]).normalized()))
        if wave["radius"] >= wave["maximum"]:
            waves.remove_at(index)
    if state["beat_count"] == beats and waves.is_empty():
        state["phase"] = "rest"

static func advance_crystals(state: Dictionary, dt: float, targets: Array, events: Array = []) -> void:
    var mines: Array = state["mines"]
    for index in range(mines.size() - 1, -1, -1):
        var mine: Dictionary = mines[index]
        mine["age"] += dt
        if mine["age"] < 0.36:
            continue
        var triggered: bool = bool(mine.get("charged",false))
        for target in targets:
            if target["hp"] > 0.0 and mine["position"].distance_to(target["position"]) <= mine["trigger"] + target["radius"]:
                triggered = true
                break
        if triggered:
            # Guaranteed crystal shatter AoE burst right inside trigger zone + fast radial shards!
            var blast_dmg: float = float(mine["damage"]) * 0.75
            for target in targets:
                if target["hp"] > 0.0 and mine["position"].distance_to(target["position"]) <= mine["trigger"] + target["radius"]:
                    events.append(hit(target, blast_dmg, "crystal", (target["position"] - mine["position"]).normalized()))
            var shared_hits: Array = []
            var is_charged: bool = bool(mine.get("charged", false))
            var fragments: int=int(mine.get("fragments",8))+(4 if is_charged else 0)
            for shard in range(fragments):
                var direction: Vector2 = Vector2.from_angle(TAU * shard / float(fragments))
                var shard_proj: Dictionary = projectile(mine["position"], direction, mine["damage"], mine["speed"], 220.0, shared_hits)
                if is_charged:
                    shard_proj["charged"] = true
                state["shards"].append(shard_proj)
            mine["bursts_left"]=int(mine.get("bursts_left",1))-1
            if mine.bursts_left>0:
                mine.age=0.10
                mine["charged"]=false
                mine.damage*=0.65
            else:
                mines.remove_at(index)
        elif mine["age"] > 3.40:
            mines.remove_at(index)

static func draw(canvas: Node2D, key: String, state: Dictionary) -> void:
    match key:
        "bonebow":
            for arrow in state["arrows"]:
                var point: Vector2 = arrow["position"]
                var direction: Vector2 = arrow["direction"]
                var side: Vector2 = direction.orthogonal()
                var shaft: Color = Color("#e5c794")
                var tip: Color = Color("#f1dfb9")
                if arrow.get("enchanted", false) or arrow.get("fire_enchanted", false) or arrow.get("thunder_enchanted", false):
                    var is_red_arrow: bool = bool(arrow.get("thunder_red", false))
                    if bool(arrow.get("enchanted", false)):
                        shaft = BattleVisuals.staff_tint(int(arrow.get("vfx_tier", 0)))
                    elif bool(arrow.get("fire_enchanted", false)):
                        shaft = BattleVisuals.fire_tint(int(arrow.get("fire_tier", 0)))
                    else:
                        shaft = Color("#ff3a2e") if is_red_arrow else BattleVisuals.thunder_tint(int(arrow.get("thunder_tier", 0)))
                    tip = shaft.lightened(0.22)
                    canvas.draw_line(point - direction * 31.0, point + direction * 11.0, Color(shaft, 0.45), 11.0, true)
                    if bool(arrow.get("enchanted", false)):
                        BattleVisuals.draw_staff_aura(canvas, point, 11.0, float(arrow.get("age", 0.0)), int(arrow.get("vfx_tier", 0)))
                    elif bool(arrow.get("fire_enchanted", false)):
                        BattleVisuals.draw_fire_wrap(canvas, point, direction, 18.0, float(arrow.get("age", 0.0)), int(arrow.get("fire_tier", 0)))
                    elif bool(arrow.get("thunder_enchanted", false)):
                        BattleVisuals.draw_thunder_wrap(canvas, point, 14.0, float(arrow.get("age", 0.0)), int(arrow.get("thunder_tier", 0)), is_red_arrow)
                canvas.draw_line(point - direction * 29.0, point + direction * 9.0, INK, 7.0, true)
                canvas.draw_line(point - direction * 29.0, point + direction * 9.0, shaft, 3.5, true)
                outlined_polygon(canvas, PackedVector2Array([point + direction * 19.0, point + direction * 4.0 + side * 7.0, point + direction * 6.0, point + direction * 4.0 - side * 7.0]), tip)
                canvas.draw_line(point - direction * 20.0, point - direction * 29.0 + side * 7.0, INK, 4.0, true)
                canvas.draw_line(point - direction * 20.0, point - direction * 29.0 - side * 7.0, INK, 4.0, true)
        "firepot":
            for pot in state["pots"]:
                var progress: float = clampf(pot["age"] / pot["flight"], 0.0, 1.0)
                var ground: Vector2 = pot["from"].lerp(pot["position"], progress)
                canvas.draw_circle(ground + Vector2(0, 6), 9.0, Color(0.2, 0.13, 0.08, 0.18))
                draw_pot(canvas, ground + Vector2(0, -sin(progress * PI) * 58.0))
            for fire in state["fires"]:
                if fire["age"] < 0.0:
                    draw_pot(canvas, fire["position"])
                    canvas.draw_arc(fire["position"], 17.0, 0, TAU, 24, Color("#f0c26c"), 2.0, true)
                    continue
                var point: Vector2 = fire["position"]
                var radius: float = fire["radius"]
                canvas.draw_texture_rect(CombatArt.texture("fire",fmod(float(fire.age)*2.5,1.0)),Rect2(point-Vector2(radius*1.2,radius*1.0),Vector2(radius*2.4,radius*1.7)),false)
        "wardrum":
            for wave in state["waves"]:
                var alpha: float = 0.85 * (1.0 - wave["radius"] / (wave["maximum"] + 25.0))
                var extent: float=wave.radius*1.30
                canvas.draw_texture_rect(CombatArt.texture("drum",float(wave.beat)*0.13),Rect2(wave.position-Vector2.ONE*extent,Vector2.ONE*extent*2),false,Color(1,1,1,alpha))
            if state["phase"] == "playing":
                var point: Vector2 = state["position"]
                var lift: float = absf(sin(state["age"] / 0.24 * PI)) * 12.0
                canvas.draw_line(point + Vector2(-11, -16 - lift), point + Vector2(4, -2), INK, 5.0, true)
                canvas.draw_circle(point + Vector2(-11, -16 - lift), 4.0, Color("#ecd8a6"))
        "crystal":
            for mine in state["mines"]:
                var point: Vector2 = mine["position"]
                if mine["age"] < 0.32:
                    var progress: float = mine["age"] / 0.32
                    point = mine["from"].lerp(point, progress) + Vector2(0, -sin(progress * PI) * 34.0)
                else:
                    var ready: bool = mine["age"] >= 0.60
                    CombatArt.draw(canvas,"crystal",point+Vector2(0,5),27.0,fmod(float(mine.age)*0.7,1.0),Vector2.RIGHT,0.38 if ready else 0.18)
                var is_charged_mine: bool = bool(mine.get("charged", false))
                if is_charged_mine:
                    BattleVisuals.draw_thunder_wrap(canvas, point + Vector2(0, -6), 24.0, float(mine.get("age", 0.0)) * 2.0, 2, false)
                outlined_polygon(canvas, PackedVector2Array([point + Vector2(-15, 5), point + Vector2(-19, -10), point + Vector2(-10, -18), point + Vector2(-4, -9), point + Vector2(0, -29), point + Vector2(10, -16), point + Vector2(9, -3), point + Vector2(19, -13), point + Vector2(17, 8), point + Vector2(0, 12)]), Color("#e2eeff") if is_charged_mine else Color("#b8a2d8"))
                canvas.draw_line(point + Vector2(0, -21), point + Vector2(1, 5), Color("#ffffff") if is_charged_mine else Color("#e8d9fa"), 3.0, true)
            for shard in state["shards"]:
                var point: Vector2 = shard["position"]
                var direction: Vector2 = shard["direction"]
                var side: Vector2 = direction.orthogonal()
                var charged_shard: bool = bool(shard.get("charged", false))
                outlined_polygon(canvas, PackedVector2Array([point + direction * 13, point + side * 5, point - direction * 9, point - side * 5]), Color("#dceeff") if charged_shard else Color("#baa7e1"), 2.5)
                canvas.draw_line(point - direction * 4, point + direction * 8, Color("#ffffff") if charged_shard else Color("#f0e4ff"), 2.4 if charged_shard else 2.0, true)

static func outlined_polygon(canvas: Node2D, points: PackedVector2Array, color: Color, width: float = 3.0) -> void:
    canvas.draw_colored_polygon(points, color)
    var edge: PackedVector2Array = points.duplicate()
    edge.append(points[0])
    canvas.draw_polyline(edge, INK, width, true)

static func draw_pot(canvas: Node2D, point: Vector2) -> void:
    outlined_polygon(canvas, PackedVector2Array([point + Vector2(-6, -9), point + Vector2(6, -9), point + Vector2(7, -4), point + Vector2(12, 1), point + Vector2(10, 12), point + Vector2(1, 16), point + Vector2(-10, 11), point + Vector2(-12, 1), point + Vector2(-7, -4)]), Color("#bb7648"))
    canvas.draw_line(point + Vector2(-8, 4), point + Vector2(9, 5), Color("#e7bb77"), 3.0, true)
    canvas.draw_line(point + Vector2(0, -9), point + Vector2(1, -18), INK, 3.0, true)
    canvas.draw_circle(point + Vector2(1, -18), 3.0, Color("#ffcc62"))

static func try_fire_pillar(state: Dictionary, item: Dictionary, target: Dictionary, damage: float, area: float, dt: float, stage: int) -> Array:
    var level: int = clampi(int(item.get("level", 1)), 1, 5)
    var profile: Dictionary = Evolution.fire_pillar_profile(level)
    state["pillar_cooldown"] = maxf(0.0, float(state.get("pillar_cooldown", 0.0)) - maxf(0.0, dt))
    if not bool(profile.get("unlocked", false)) or state["pillar_cooldown"] > 0.0 or target.is_empty():
        return []
    state["pillar_cooldown"] = float(profile["cooldown"])
    return [{
        "type": "fire_pillar",
        "position": target["position"],
        "radius": float(profile["radius"]) * area,
        "damage": damage * float(profile["damage_multiplier"]),
        "weapon_id": "firepot",
        "tier": stage
    }]
