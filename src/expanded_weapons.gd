extends RefCounted
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
    var level: int = clampi(int(item.get("level", 1)), 1, 5)
    var stage: int=Evolution.tier(level)
    state["evolution"]=stage
    var damage: float = data["damage"] * (1.0 + (level - 1) * 0.35)
    var area: float = maxf(0.1, float(stats.get("area_multiplier", 1.0)))
    var bullet_speed: float = maxf(0.1, float(stats.get("bullet_speed", 1.0)))
    var mount: Vector2 = mount_point if mount_point.is_finite() else hero + MOUNTS[key]
    state["cooldown"] = maxf(0.0, state["cooldown"] - dt)
    state["age"] += dt
    var target_origin: Vector2=mount if key=="bonebow" else hero
    var reach: float = Rules.scaled_range(data, stats) * (area if key == "wardrum" else 1.0)
    var target: Dictionary = Rules.choose_target(target_origin, reach, targets, prefer_elite)
    if not target.is_empty():
        var aim: Vector2 = target["position"] - mount
        state["direction"] = aim.normalized() if aim.length_squared() > 0.01 else Vector2.RIGHT
    view.position = mount
    view.rotation = state["direction"].angle() + PI / 2.0 if key == "bonebow" else 0.0
    var hold_aim: Vector2 = state["direction"] if Vector2(state.get("direction", Vector2.RIGHT)).length() > 0.01 else (mount - hero)
    var idle_presentation: bool = key != "bonebow" or (target.is_empty() and (not state["has_fired"] or state["age"] > 0.16))
    Rules.apply_parked_hold(view, key, hero, hold_aim, idle_presentation)
    if state["cooldown"] <= 0.0 and not target.is_empty() and not (key == "wardrum" and state["phase"] == "playing"):
        state["cooldown"] = data["cooldown"] / (1.0 + (level - 1) * 0.08)
        if key==stats.get("reload_weapon",""): state.cooldown*=float(stats.get("reload_multiplier",1.0))
        state["age"] = 0.0
        state["has_fired"] = true
        events.append({"type": "flash", "weapon_id": key})
        match key:
            "bonebow":
                for arrow in range(1+stage):
                    var side: Vector2=Vector2(state.direction).orthogonal()*((arrow-stage*0.5)*11.0)
                    var shot: Dictionary=projectile(mount+state.direction*22.0+side,state.direction,damage*(1.0 if stage==0 else (0.70 if stage==1 else 0.58)),data.speed*bullet_speed,reach,[])
                    shot["pierce_limit"]=5 if stage>=2 else 3
                    state.arrows.append(shot)
            "firepot":
                var flight: float = clampf(mount.distance_to(target["position"]) / data["speed"], 0.32, 0.65)
                for pot in range(1+stage):
                    var offset: Vector2=Vector2(state.direction).orthogonal()*((pot-stage*0.5)*48.0)
                    state.pots.append({"from":mount,"position":target.position+offset,"age":0.0,"flight":flight,"damage":damage*(1.0 if stage==0 else (0.65 if stage==1 else 0.50)),"radius":56.0*area,"life":2.4 if stage>=2 else 1.85})
            "wardrum":
                state["phase"] = "playing"
                state["beat_count"] = 0
            "crystal":
                state["mines"].append({"from": mount, "position": target["position"], "age": 0.0, "damage": damage, "speed": data["speed"] * bullet_speed, "trigger": 54.0 * area,"fragments":8 if stage>=1 else 6,"bursts_left":2 if stage>=2 else 1})
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
            if stats.get("link_kind","")=="fire_drum": state["fan_fire"]=true
            view.position.y -= maxf(0.0, sin(state["age"] / 0.24 * TAU)) * 3.5 if state["phase"] == "playing" else 0.0
        "crystal":
            advance_projectiles(state["shards"], dt, targets, events, key)
            advance_crystals(state, dt, targets)
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
            shot["hit_count"] += 1
            events.append(hit(target, shot["damage"], key, shot["direction"]))
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
            fire["next_tick"] += 0.35
        if fire["age"] > float(fire.get("life",1.85)):
            fires.remove_at(index)
    var pots: Array = state["pots"]
    for index in range(pots.size() - 1, -1, -1):
        var pot: Dictionary = pots[index]
        pot["age"] += dt
        if pot["age"] >= pot["flight"]:
            fires.append({"position": pot["position"], "age": -0.18 + pot["age"] - pot["flight"], "next_tick": 0.0, "damage": pot["damage"], "radius": pot["radius"],"life":pot.get("life",1.85)})
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

static func advance_crystals(state: Dictionary, dt: float, targets: Array) -> void:
    var mines: Array = state["mines"]
    for index in range(mines.size() - 1, -1, -1):
        var mine: Dictionary = mines[index]
        mine["age"] += dt
        if mine["age"] < 0.60:
            continue
        var triggered: bool = bool(mine.get("charged",false))
        for target in targets:
            if target["hp"] > 0.0 and mine["position"].distance_to(target["position"]) <= mine["trigger"] + target["radius"]:
                triggered = true
                break
        if triggered:
            # Sibling shards share the budget so their common origin is one hit.
            var shared_hits: Array = []
            var fragments: int=int(mine.get("fragments",6))+(4 if mine.get("charged",false) else 0)
            for shard in range(fragments):
                var direction: Vector2 = Vector2.from_angle(TAU * shard / float(fragments))
                state["shards"].append(projectile(mine["position"], direction, mine["damage"], mine["speed"], 160.0, shared_hits))
            mine["bursts_left"]=int(mine.get("bursts_left",1))-1
            if mine.bursts_left>0:
                mine.age=0.15
                mine["charged"]=false
                mine.damage*=0.55
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
                canvas.draw_line(point - direction * 29.0, point + direction * 9.0, INK, 7.0, true)
                canvas.draw_line(point - direction * 29.0, point + direction * 9.0, Color("#e5c794"), 3.5, true)
                outlined_polygon(canvas, PackedVector2Array([point + direction * 19.0, point + direction * 4.0 + side * 7.0, point + direction * 6.0, point + direction * 4.0 - side * 7.0]), Color("#f1dfb9"))
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
                outlined_polygon(canvas, PackedVector2Array([point + Vector2(-15, 5), point + Vector2(-19, -10), point + Vector2(-10, -18), point + Vector2(-4, -9), point + Vector2(0, -29), point + Vector2(10, -16), point + Vector2(9, -3), point + Vector2(19, -13), point + Vector2(17, 8), point + Vector2(0, 12)]), Color("#b8a2d8"))
                canvas.draw_line(point + Vector2(0, -21), point + Vector2(1, 5), Color("#e8d9fa"), 3.0, true)
            for shard in state["shards"]:
                var point: Vector2 = shard["position"]
                var direction: Vector2 = shard["direction"]
                var side: Vector2 = direction.orthogonal()
                outlined_polygon(canvas, PackedVector2Array([point + direction * 13, point + side * 5, point - direction * 9, point - side * 5]), Color("#baa7e1"), 2.5)
                canvas.draw_line(point - direction * 4, point + direction * 8, Color("#f0e4ff"), 2.0, true)

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
