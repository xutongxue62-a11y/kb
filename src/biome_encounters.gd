extends RefCounted
## Encounter patterns are authored in world units. A locked attack drives both ink and collision.
const Ink = preload("res://src/encounter_ink.gd")
const Tactics = preload("res://src/encounter_tactics.gd")

const BOSSES := ["fernmask", "cinderback", "drumjaw"]
const BOSS_NAMES := {"fernmask":"蕨面猎王", "cinderback":"熔背岩王", "drumjaw":"裂喉鼓龙"}
const GROVE := ["leafstalker", "sporeback", "bonecaller", "reedspitter"]
const VOLCANO := ["embersnout", "ashhound", "basaltroller", "cindertusk"]
const GRASS_ART := {"raptor":"sidesnap", "thrower":"stonecrest", "armored":"shieldback"}
const MOBS := {
    "leafstalker":{"hp":9.0,"speed":97.0,"radius":20.0,"size":70.0,"damage":1.15},
    "sporeback":{"hp":12.0,"speed":45.0,"radius":24.0,"size":72.0,"damage":1.15},
    "bonecaller":{"hp":15.0,"speed":69.0,"radius":22.0,"size":79.0,"damage":1.35},
    "embersnout":{"hp":14.0,"speed":58.0,"radius":24.0,"size":76.0,"damage":1.35},
    "ashhound":{"hp":11.0,"speed":108.0,"radius":20.0,"size":73.0,"damage":1.3},
    "basaltroller":{"hp":23.0,"speed":51.0,"radius":28.0,"size":81.0,"damage":1.55},
    "reedspitter":{"hp":11.0,"speed":68.0,"radius":21.0,"size":71.0,"damage":1.18},
    "cindertusk":{"hp":18.0,"speed":53.0,"radius":25.0,"size":78.0,"damage":1.42},
}
const PALE := Color("#a46c38")
const MOSS := Color("#687a3a")
const CLAY := Color("#ad5039")
const SHADE := Color("#71394d")
const IDLE := {"handled":false}

static func boss_form(wave: int) -> String:
    @warning_ignore("integer_division")
    var milestone: int = maxi(0, wave / 5 - 1)
    return BOSSES[milestone % BOSSES.size()] + ("_dark" if milestone >= BOSSES.size() else "")

static func boss_name(form: String) -> String:
    return ("魔化·" if form.ends_with("_dark") else "") + str(BOSS_NAMES.get(form.trim_suffix("_dark"), "首领"))

static func art_form(kind: String, form: String, wave: int) -> String:
    if kind == "boss" or MOBS.has(kind):
        return form
    return str(GRASS_ART.get(kind, "")) if wave < 5 else ""

static func _move(shape: String, reach: float, width: float, tell: float, color: Color, mode: String = "") -> Dictionary:
    return {"shape":shape,"reach":reach,"width":width,"tell":tell,"paint":color,"mode":mode}

static func _pattern(enemy: Dictionary) -> Array:
    var form: String = str(enemy.get("form", enemy.kind))
    var base: String = form.trim_suffix("_dark")
    var dark: bool = form.ends_with("_dark")
    var fierce: bool = dark or (enemy.kind == "boss" and float(enemy.hp) <= float(enemy.max_hp) * 0.5)
    var turn: int = int(enemy.attack_cycle) % 3
    var elite: bool = bool(enemy.get("elite", false))
    match base:
        "fernmask":
            var pounce := _move("lane", 278.0, 40.0, 0.62, MOSS, "dash")
            var tail := _move("fan", 204.0, 1.30, 0.51, PALE)
            if dark:
                return [pounce, _move("lane", 250.0, 40.0, 0.82, SHADE, "echo"), tail]
            if turn == 1:
                return [tail, pounce]
            if turn == 2 and fierce:
                return [_move("lane", 145.0, 27.0, 0.53, MOSS, "feint"), pounce, tail]
            return [pounce, _move("lane", 226.0, 37.0, 0.46, MOSS, "dash")]
        "cinderback":
            var sweep := _move("fan", 244.0, 1.35, 0.76, CLAY)
            var fissure := _move("lane", 348.0, 45.0, 0.68, CLAY)
            var rocks := Tactics.boss_ranged(form)
            if dark:
                return [sweep, rocks, _move("ring", 223.0, 92.0, 0.66, SHADE)]
            if fierce or turn == 2:
                return [rocks, _move("lane", 250.0, 51.0, 0.57, CLAY, "dash")]
            return [sweep, fissure] if turn == 0 else [fissure, rocks]
        "drumjaw":
            var inner := _move("ring", 185.0, 58.0, 0.68, PALE)
            var outer := _move("ring", 306.0, 185.0, 0.48, CLAY, "anchor")
            var bite := _move("lane", 254.0, 44.0, 0.55, CLAY, "dash")
            var turn_sweep := _move("fan", 216.0, 1.27, 0.52, PALE)
            if dark:
                return [inner, outer, bite, _move("lane", 250.0, 43.0, 0.78, SHADE, "echo")]
            if turn == 0:
                return [inner, outer, bite]
            return [bite, turn_sweep, inner] if fierce else [bite, turn_sweep]
        "leafstalker":
            return [_move("lane", 145.0, 20.0, 0.64, MOSS, "dash")]
        "sporeback":
            if turn == 1:
                return [Tactics.volley("spore",315.0,1,0.0,168.0,0.76,MOSS,0.82)]
            return [_move("circle", 60.0, 0.0, 0.83, MOSS, "target"),
                _move("circle", 60.0, 0.0, 0.8, MOSS, "anchor")]
        "reedspitter":
            return [Tactics.volley("reed",370.0,1,0.0,240.0,0.67,MOSS,0.88)]
        "bonecaller":
            var call_ := _move("circle", 150.0, 0.0, 0.8, PALE, "rally")
            return [call_, _move("fan", 111.0, 0.72, 0.52, CLAY)] if elite else [call_]
        "embersnout":
            return [_move("fan", 177.0, 0.56, 0.63, CLAY)] if turn == 1 else [_move("lane", 160.0, 25.0, 0.67, CLAY)]
        "cindertusk":
            return [Tactics.volley("fire",362.0,3,0.16,188.0,0.81,CLAY,0.73)]
        "ashhound":
            return [_move("lane", 140.0, 22.0, 0.57, CLAY, "dash")]
        "basaltroller":
            var roll := _move("lane", 174.0, 27.0, 0.77, CLAY, "dash")
            return [roll, _move("lane", 174.0, 27.0, 0.56, PALE, "reverse")] if elite else [roll]
        "armored":
            return [_move("fan", 105.0, 0.92, 0.72, PALE, "guard"),
                _move("lane", 116.0, 27.0, 0.54, CLAY, "dash")]
    return []

static func active(enemy: Dictionary) -> bool:
    var kind: String = enemy.kind
    return (kind == "boss" and enemy.has("form")) or MOBS.has(kind) or (kind == "armored" and bool(enemy.get("elite", false)))

static func _can_reach(world, enemy: Dictionary, attack: Dictionary, distance: float) -> bool:
    if attack.mode in ["target", "summon"]:
        return distance <= float(attack.get("cast_range", 210.0))
    if distance > float(attack.reach):
        return false
    if attack.shape == "ring" and distance < float(attack.width):
        return false
    if attack.mode == "dash" and distance > 1.0:
        var origin: Vector2 = enemy.position
        var aim: Vector2 = origin.direction_to(world.player_position)
        return _dash_reach(world, enemy, origin, aim, attack.reach) + 0.5 >= distance
    return true

static func _dash_reach(world, enemy: Dictionary, origin: Vector2, aim: Vector2, reach: float) -> float:
    var travel: Vector2 = world.map_view.move_body(origin, origin + aim * reach, float(enemy.radius)) - origin
    return clampf(travel.dot(aim), 0.0, reach)

static func _combo(world, enemy: Dictionary, distance: float) -> Array:
    var boss: bool = enemy.kind == "boss"
    if boss and distance <= Tactics.BOSS_DISTANCE and Tactics.can_summon(world, enemy):
        return [Tactics.summon()]
    var ranged: Dictionary = Tactics.boss_ranged(enemy.form) if boss else {}
    if boss and int(enemy.attack_cycle) % 4 == 2 and _can_reach(world,enemy,ranged,distance):
        return [ranged]
    var pattern: Array = _pattern(enemy)
    for i in range(pattern.size()):
        var attack: Dictionary = pattern[i]
        if attack.mode in ["echo", "anchor", "reverse"]:
            continue
        if _can_reach(world,enemy,attack,distance):
            return pattern.slice(i)
    if boss and _can_reach(world,enemy,ranged,distance):
        return [ranged]
    if enemy.kind == "sporeback" and distance <= 315.0:
        return [Tactics.volley("spore",315.0,1,0.0,168.0,0.76,MOSS,0.82)]
    return []

static func _begin(world, enemy: Dictionary) -> void:
    var attack: Dictionary = enemy.combo.pop_front()
    var mode: String = attack.mode
    var origin: Vector2 = enemy.position
    var aim: Vector2 = origin.direction_to(world.player_position)
    if aim == Vector2.ZERO:
        aim = enemy.direction
    var previous: Dictionary = enemy.get("attack", {})
    if mode == "echo":
        origin = previous.origin
        aim = previous.direction
        attack.reach = previous.reach
    elif mode == "anchor":
        origin = previous.origin
    elif mode == "target":
        origin = world.player_position
    elif mode == "reverse":
        aim = -previous.direction
    elif mode == "summon":
        attack.summon_positions = Tactics.summon_points(world, enemy, aim)
    if mode in ["dash", "reverse"]:
        # Use the same terrain solver as body movement to shorten blocked lanes.
        attack.reach = _dash_reach(world,enemy,origin,aim,attack.reach)
    attack.origin = origin
    attack.direction = aim
    enemy.direction = aim
    enemy.attack = attack
    enemy.state = "encounter_aim"
    enemy.timer = attack.tell

static func _pose(velocity: Vector2, pose: String) -> Dictionary:
    return {"handled":true,"velocity":velocity,"pose":pose}

static func _windup_pose(attack: Dictionary, enemy: Dictionary) -> String:
    if attack.mode in ["summon", "volley"]:
        return "inhale"
    if Ink.family(attack, enemy) == "fissure":
        return "stomp_prep"
    var form: String = str(enemy.get("form", enemy.kind))
    if form == "fernmask" and attack.shape == "fan":
        return "sweep_prep"
    if form == "drumjaw" and attack.mode == "dash":
        return "bite_prep"
    if attack.mode in ["dash", "reverse", "feint"]:
        return "coil"
    if attack.shape == "ring" or Ink.family(attack, enemy) in ["fire", "rally"]:
        return "inhale"
    if attack.shape == "fan" or attack.mode == "guard":
        return "brace"
    return "windup"

static func _strike_pose(attack: Dictionary, enemy: Dictionary) -> String:
    if attack.mode == "feint":
        return "recover"
    if attack.mode in ["summon", "volley"]:
        return "roar" if enemy.kind == "boss" else "breath"
    if Ink.family(attack, enemy) == "fissure":
        return "stomp"
    if attack.mode in ["dash", "reverse"]:
        var form: String = str(enemy.get("form", enemy.kind)).trim_suffix("_dark")
        if form == "basaltroller":
            return "roll"
        if form in ["fernmask", "leafstalker", "drumjaw"]:
            return "pounce"
        return "charge"
    if attack.shape == "ring" or attack.mode == "rally":
        return "roar"
    if Ink.family(attack, enemy) == "fire":
        return "breath"
    if attack.shape == "fan":
        return "sweep"
    return "strike"

static func advance(world, enemy: Dictionary, delta: float) -> Dictionary:
    if not active(enemy):
        return IDLE
    var boss: bool = enemy.kind == "boss"
    var to_player: Vector2 = world.player_position - enemy.position
    var speed: float = float(MOBS.get(enemy.kind, {}).get("speed", 54.0))
    if boss:
        speed = 81.0 if str(enemy.form).begins_with("fernmask") else (69.0 if str(enemy.form).begins_with("drumjaw") else 57.0)
        if str(enemy.form).ends_with("_dark"):
            speed += 10.0
    match str(enemy.state):
        "encounter_aim":
            if float(enemy.timer) <= 0.0:
                var attack: Dictionary = enemy.attack
                enemy.state = "encounter_strike"
                enemy.timer = 0.28
                enemy.strike_hit = false
                if attack.mode not in ["dash", "reverse", "feint"]:
                    _impact(world, enemy, attack)
                return _pose(Vector2.ZERO, _strike_pose(attack, enemy))
            return _pose(Vector2.ZERO, _windup_pose(enemy.attack, enemy))
        "encounter_strike":
            var attack: Dictionary = enemy.attack
            var remains: float = maxf(0.0, float(enemy.timer) + delta)
            if attack.mode == "volley" and int(attack.waves) > 1 and float(enemy.timer) <= 0.13 and not bool(attack.get("second_wave",false)):
                Tactics.fire(world,enemy,attack,1)
                attack.second_wave = true
            if remains <= 0.0001:
                var distance: float = to_player.length()
                while not enemy.combo.is_empty():
                    var next: Dictionary = enemy.combo[0]
                    if next.mode in ["echo","anchor","reverse"] or _can_reach(world,enemy,next,distance):
                        break
                    enemy.combo.pop_front()
                if not enemy.combo.is_empty():
                    _begin(world, enemy)
                    return _pose(Vector2.ZERO, _windup_pose(enemy.attack, enemy))
                enemy.state = "encounter_recover"
                enemy.timer = 0.62 if boss else 1.05
                return _pose(Vector2.ZERO, "recover")
            if attack.mode in ["dash", "reverse"]:
                var motion: Vector2 = Vector2(attack.direction) * float(attack.reach) / 0.28
                return _pose(motion * minf(remains / delta, 1.0) / float(enemy.speed_multiplier), _strike_pose(attack, enemy))
            return _pose(Vector2.ZERO, _strike_pose(attack, enemy))
        "encounter_recover":
            if float(enemy.timer) <= 0.0:
                enemy.state = "walk"
                enemy.timer = 0.15 if boss else 0.7
            return _pose(Vector2.ZERO, "recover")
    var distance: float = to_player.length()
    if float(enemy.timer) <= 0.0 and distance <= Tactics.BOSS_DISTANCE:
        enemy.combo = _combo(world, enemy, distance)
        if not enemy.combo.is_empty():
            enemy.attack_cycle += 1
            _begin(world, enemy)
            return _pose(Vector2.ZERO, _windup_pose(enemy.attack, enemy))
    var movement: Vector2 = to_player.normalized()
    if enemy.kind in ["reedspitter","cindertusk","sporeback"] and distance < 210.0:
        movement = -movement * 0.67
    if boss and str(enemy.form).begins_with("fernmask") and distance < 410.0:
        movement = (movement + movement.orthogonal() * (0.42 if int(enemy.id) % 2 == 0 else -0.42)).normalized()
    elif enemy.kind in ["ashhound", "leafstalker"] and distance < 325.0:
        movement = (movement + movement.orthogonal() * (0.7 if int(enemy.id) % 2 == 0 else -0.7)).normalized()
    return _pose(movement * speed, "walk")

static func strike_travel(world, enemy: Dictionary, previous: Vector2) -> void:
    if enemy.state != "encounter_strike" or bool(enemy.get("strike_hit", false)):
        return
    var attack: Dictionary = enemy.attack
    if attack.mode not in ["dash", "reverse"]:
        return
    var current: Vector2 = enemy.position
    var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(world.player_position, previous, current) if previous != current else current
    if contains(attack, world.player_position) and world.player_position.distance_to(nearest) <= float(attack.width):
        enemy.strike_hit = true
        world.hurt_player(Vector2(attack.direction), float(enemy.damage))

static func blocks(enemy: Dictionary, point: Vector2) -> bool:
    return enemy.get("state") == "encounter_aim" and enemy.get("attack", {}).get("mode") == "guard" and contains(enemy.attack, point)

static func contains(attack: Dictionary, point: Vector2) -> bool:
    var offset: Vector2 = point - Vector2(attack.origin)
    var reach: float = attack.reach
    var width: float = attack.width
    match str(attack.shape):
        "lane":
            var forward: Vector2 = attack.direction
            var along: float = offset.dot(forward)
            return along >= 0.0 and along <= reach and absf(offset.cross(forward)) <= width
        "fan":
            return offset.length_squared() <= reach * reach and absf(Vector2(attack.direction).angle_to(offset)) <= width
        "ring":
            var radius_sq: float = offset.length_squared()
            return radius_sq <= reach * reach and radius_sq >= width * width
    return offset.length_squared() <= reach * reach

static func _impact(world, enemy: Dictionary, attack: Dictionary) -> void:
    if attack.mode == "summon":
        Tactics.call_reinforcements(world,enemy,attack)
        return
    if attack.mode == "volley":
        Tactics.fire(world,enemy,attack)
        return
    if attack.mode == "guard":
        return
    if attack.mode == "rally":
        for ally in world.enemies:
            if ally != enemy and ally.kind != "boss" and ally.state == "walk" and ally.position.distance_to(attack.origin) <= float(attack.reach):
                ally.timer = maxf(0.12, minf(float(ally.timer), 0.28))
        return
    if contains(attack, world.player_position):
        var knock: Vector2 = Vector2(attack.origin).direction_to(world.player_position)
        world.hurt_player(knock, float(enemy.damage) * (0.82 if attack.mode == "echo" else 1.0))

static func _sector(origin: Vector2, radius: float, start: float, span: float, segments: int) -> PackedVector2Array:
    var rim := PackedVector2Array()
    for i in range(segments + 1):
        rim.append(origin + Vector2.from_angle(start + span * float(i) / segments) * radius)
    return rim

static func draw_attack(canvas, enemy: Dictionary) -> bool:
    if not active(enemy):
        return false
    var warning: bool = enemy.state == "encounter_aim"
    if not warning and enemy.state != "encounter_strike":
        return true
    var attack: Dictionary = enemy.attack
    if not warning:
        if attack.mode == "summon":
            Tactics.draw_tell(canvas,attack,Color("#efcd90",0.68),Color("#ae814b",0.22),1.0)
        elif attack.mode not in ["feint","volley"]:
            Ink.impact(canvas,attack,enemy,1.0 - clampf(float(enemy.timer) / 0.28, 0.0, 1.0))
        return true
    var origin: Vector2 = attack.origin
    var direction: Vector2 = attack.direction
    var reach: float = attack.reach
    var width: float = attack.width
    var phase: float = 1.0 - clampf(float(enemy.timer) / float(attack.tell), 0.0, 1.0)
    var is_boss: bool = str(enemy.get("kind", "")) == "boss"
    var pigment: Color = attack.paint
    var edge := Color("#ff4136", lerpf(0.82, 1.0, phase)) if is_boss else Color(pigment.lerp(Color("#f6d59c"), 0.62), lerpf(0.68, 0.98, phase))
    var wash := Color("#e02b24", lerpf(0.18, 0.36, phase)) if is_boss else Color(pigment.lerp(Color("#f6d59c"), 0.24), lerpf(0.19, 0.39, phase))
    var charge_fill := Color("#ff5b36", lerpf(0.16, 0.42, phase))
    if Tactics.draw_tell(canvas,attack,edge,wash,phase):
        return true
    match str(attack.shape):
        "lane":
            if reach < 1.0:
                return true
            var normal: Vector2 = direction.orthogonal()
            var end: Vector2 = origin + direction * reach
            var polygon := PackedVector2Array([origin - normal * width, end - normal * width, end + normal * width, origin + normal * width])
            canvas.draw_colored_polygon(polygon, wash)
            if is_boss and phase > 0.03:
                var fill_end: Vector2 = origin + direction * (reach * clampf(phase, 0.04, 1.0))
                var charge_poly := PackedVector2Array([origin - normal * width, fill_end - normal * width, fill_end + normal * width, origin + normal * width])
                canvas.draw_colored_polygon(charge_poly, charge_fill)
            polygon.append(polygon[0])
            canvas.draw_polyline(polygon, Color("#402b2a", edge.a * 0.72), 5.0, true)
            canvas.draw_polyline(polygon, edge, 3.2 if is_boss else 2.4, true)
            for offset in range(18, int(reach) - 8, 24):
                for side in [-1.0, 1.0]:
                    var mark: Vector2 = origin + direction * offset + normal * width * side * 0.79
                    canvas.draw_polyline(PackedVector2Array([mark - direction * 5.0 - normal * 4.0, mark, mark - direction * 5.0 + normal * 4.0]), edge, 2.3, true)
            if attack.mode == "echo":
                for offset in range(10, int(reach) - 4, 14):
                    canvas.draw_circle(origin + direction * offset,2.4,edge,true,-1.0,true)
        "fan":
            var start: float = direction.angle() - width
            var rim: PackedVector2Array = _sector(origin, reach, start, 2.0 * width, 18)
            var region: PackedVector2Array = rim.duplicate()
            region.insert(0, origin)
            canvas.draw_colored_polygon(region, wash)
            if is_boss:
                var inner_rim: PackedVector2Array = _sector(origin, reach * clampf(phase, 0.10, 1.0), start, 2.0 * width, 18)
                inner_rim.insert(0, origin)
                canvas.draw_colored_polygon(inner_rim, charge_fill)
                canvas.draw_polyline(rim, edge, 3.2, true)
            canvas.draw_line(origin, rim[0], edge, 2.6 if is_boss else 2.0, true)
            canvas.draw_line(origin, rim[-1], edge, 2.6 if is_boss else 2.0, true)
            for point in rim:
                canvas.draw_circle(point, 2.7, edge, true, -1.0, true)
        "ring":
            # Concentric outlines keep the inner safe area visible.
            canvas.draw_arc(origin, (reach + width) * 0.5, 0.0, TAU, 36, wash, reach - width, true)
            canvas.draw_arc(origin, width, 0.0, TAU, 36, edge, 3.0 if is_boss else 2.0, true)
            canvas.draw_arc(origin, reach, 0.0, TAU, 36, edge, 4.0 if is_boss else 3.0, true)
            if is_boss:
                canvas.draw_arc(origin, width + (reach - width) * phase, 0.0, TAU, 36, charge_fill, 4.0, true)
        _:
            canvas.draw_circle(origin, reach, wash, true, -1.0, true)
            if is_boss:
                canvas.draw_circle(origin, reach * clampf(phase, 0.08, 1.0), charge_fill, true, -1.0, true)
                canvas.draw_arc(origin, reach, 0.0, TAU, 36, edge, 3.5, true)
            for point in _sector(origin, reach, 0.0, TAU, 26):
                canvas.draw_circle(point, 2.5, edge, true, -1.0, true)
    return true
