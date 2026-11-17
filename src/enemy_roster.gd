extends RefCounted
## New enemy AI returns base velocity only. Main owns timer subtraction, speed
## multipliers, separation, knock, terrain movement, animation and contact hits.

const IDS = ["raptor", "thrower", "armored"]
const NEW_DATA = {
    "raptor": {"hp": 7.5, "speed": 88.0, "radius": 18.0, "size": 70.0},
    "thrower": {"hp": 10.0, "speed": 48.0, "radius": 21.0, "size": 75.0},
    "armored": {"hp": 24.0, "speed": 29.0, "radius": 29.0, "size": 98.0}
}
const NAMES = {"raptor": "镰爪迅龙", "thrower": "投掷兽", "armored": "岩甲兽"}
const DAMAGE = {"raptor": 1.1, "thrower": 1.2, "armored": 1.75}
const POUNCE_SPEED: float = 360.0
const POUNCE_TIME: float = 0.36
const POUNCE_WARNING: float = 0.58
const FAN_WARNING: float = 0.78
const STONE_SPEED: float = 172.0
const STONE_LIFE: float = 3.0
const FAN_ANGLES = [-0.23, 0.0, 0.23]
const QUAKE_WARNING: float = 1.0
const QUAKE_RADIUS: float = 112.0
const PLAYER_RADIUS: float = 18.0

static func base_damage(kind: String) -> float:
    return float(DAMAGE.get(kind, 1.0))

static func spawn_pool(wave: int, elapsed: float, trial: bool, boss_round: bool) -> Array:
    if trial:
        return ["hunter", "hunter", "charger", "spitter", "tank", "raptor", "thrower", "armored"]
    if boss_round:
        var adds: Array = ["hunter", "hunter", "charger"]
        if wave >= 5:
            adds.append("raptor")
        if wave >= 10:
            adds.append("thrower")
        return adds
    if wave <= 1:
        return ["hunter", "hunter"] if elapsed < 12.0 else ["hunter", "hunter", "charger"]
    var pool: Array = ["hunter", "hunter", "charger", "spitter", "tank", "raptor"]
    if wave >= 3:
        pool.append("thrower")
    if wave >= 4:
        pool.append("armored")
    return pool

# Shared read-only result for the common "not handled" path: advance() runs
# once per enemy per physics frame, and a fresh dictionary literal for the
# four legacy kinds was pure allocation churn. Main only reads the result.
const NOT_HANDLED := {"handled": false}

static func advance(world, enemy: Dictionary, delta: float) -> Dictionary:
    var kind: String = str(enemy.get("kind", ""))
    if not NEW_DATA.has(kind):
        return NOT_HANDLED
    var difference: Vector2 = world.player_position - enemy["position"]
    var distance: float = difference.length()
    var direction: Vector2 = difference / distance if distance > 0.001 else Vector2.RIGHT
    match kind:
        "raptor":
            return _raptor(enemy, direction, distance, delta)
        "thrower":
            return _thrower(world, enemy, direction, distance)
        "armored":
            return _armored(world, enemy, direction, distance)
    return NOT_HANDLED

static func _motion(velocity: Vector2, pose: String = "walk") -> Dictionary:
    return {"handled": true, "velocity": velocity, "pose": pose}

static func _begin(enemy: Dictionary, state: String, duration: float) -> void:
    enemy["state"] = state
    enemy["timer"] = duration

static func _active_fraction(timer: float, delta: float) -> float:
    # Main has already subtracted delta. Limit the last movement slice to the
    # actual time left, so a pounce never travels beyond its warning lane.
    return clampf((timer + delta) / maxf(delta, 0.000001), 0.0, 1.0)

static func _raptor(enemy: Dictionary, direction: Vector2, distance: float, delta: float) -> Dictionary:
    var state: String = str(enemy.get("state", "walk"))
    var timer: float = float(enemy.get("timer", 0.0))
    match state:
        "walk":
            if timer <= 0.0 and distance <= 225.0:
                enemy["attack_cycle"] = int(enemy.get("attack_cycle", 0)) + 1
                var side: float = 1.0 if (int(enemy.get("id", 0)) + int(enemy["attack_cycle"])) % 2 == 0 else -1.0
                enemy["step_direction"] = direction.orthogonal() * side
                _begin(enemy, "raptor_step", maxf(0.0, 0.32 - delta))
                return _motion(enemy["step_direction"] * 104.0 * minf(1.0, 0.32 / maxf(delta, 0.000001)))
            return _motion(direction * float(NEW_DATA["raptor"]["speed"]))
        "raptor_step":
            var velocity: Vector2 = enemy.get("step_direction", direction.orthogonal()) * 104.0 * _active_fraction(timer, delta)
            if timer <= 0.0:
                enemy["direction"] = direction
                _begin(enemy, "raptor_aim", POUNCE_WARNING)
            return _motion(velocity, "windup" if timer <= 0.0 else "walk")
        "raptor_aim":
            if timer <= 0.0:
                _begin(enemy, "raptor_lunge", POUNCE_TIME)
            return _motion(Vector2.ZERO, "windup")
        "raptor_lunge":
            var velocity: Vector2 = enemy.get("direction", Vector2.RIGHT) * POUNCE_SPEED * _active_fraction(timer, delta)
            if timer <= 0.0:
                _begin(enemy, "recover", 0.65)
            return _motion(velocity, "dash")
        "recover":
            if timer <= 0.0:
                _begin(enemy, "walk", 1.35)
            return _motion(Vector2.ZERO, "recover")
        "egg", "enter":
            return _motion(Vector2.ZERO, state)
        _:
            _begin(enemy, "walk", 0.6)
            return _motion(Vector2.ZERO)

static func _thrower(world, enemy: Dictionary, direction: Vector2, distance: float) -> Dictionary:
    var state: String = str(enemy.get("state", "walk"))
    var timer: float = float(enemy.get("timer", 0.0))
    match state:
        "walk":
            var velocity: Vector2 = Vector2.ZERO
            if distance > 315.0:
                velocity = direction * float(NEW_DATA["thrower"]["speed"])
            elif distance < 205.0:
                velocity = -direction * 52.0
            if timer <= 0.0 and distance >= 105.0 and distance <= 440.0:
                enemy["direction"] = direction
                enemy["shot_speed"] = STONE_SPEED * float(enemy.get("bullet_multiplier", 1.0))
                _begin(enemy, "thrower_aim", FAN_WARNING)
                return _motion(Vector2.ZERO, "windup")
            return _motion(velocity)
        "thrower_aim":
            if timer <= 0.0:
                var aim: Vector2 = enemy.get("direction", Vector2.RIGHT)
                var origin: Vector2 = _muzzle(enemy, aim)
                for angle in FAN_ANGLES:
                    world.projectiles.append({"position": origin, "velocity": aim.rotated(angle) * float(enemy.get("shot_speed", STONE_SPEED)),
                        "damage": float(enemy.get("damage", base_damage("thrower"))), "kind": "hostile", "life": STONE_LIFE,
                        "radius": 8.5, "weapon_id": "", "from_combo": false, "hostile_style": "stone", "source_kind": "thrower",
                        "source_enemy_id": int(enemy.get("id", 0))})
                if world.effects != null:
                    world.effects.puff(origin, Color("#bea17c"), 18.0)
                _begin(enemy, "recover", 0.52)
            return _motion(Vector2.ZERO, "windup" if timer > 0.0 else "recover")
        "recover":
            if timer <= 0.0:
                _begin(enemy, "walk", 2.45)
            return _motion(Vector2.ZERO, "recover")
        "egg", "enter":
            return _motion(Vector2.ZERO, state)
        _:
            _begin(enemy, "walk", 0.6)
            return _motion(Vector2.ZERO)

static func _armored(world, enemy: Dictionary, direction: Vector2, distance: float) -> Dictionary:
    var state: String = str(enemy.get("state", "walk"))
    var timer: float = float(enemy.get("timer", 0.0))
    match state:
        "walk":
            if timer <= 0.0 and distance <= 156.0:
                enemy["slam_at"] = enemy["position"]
                enemy["direction"] = direction
                _begin(enemy, "armored_slam", QUAKE_WARNING)
                return _motion(Vector2.ZERO, "windup")
            return _motion(direction * float(NEW_DATA["armored"]["speed"]))
        "armored_slam":
            if timer <= 0.0:
                var center: Vector2 = enemy.get("slam_at", enemy["position"])
                if world.effects != null:
                    world.effects.burst(center, Color("#df9b54"), QUAKE_RADIUS, "quake")
                if world.player_position.distance_to(center) <= QUAKE_RADIUS + PLAYER_RADIUS:
                    var hit_direction: Vector2 = (world.player_position - center).normalized()
                    world.hurt_player(hit_direction, float(enemy.get("damage", base_damage("armored"))))
                if world.audio != null:
                    world.audio.play("stone_hit", 0.0, 0.72)
                _begin(enemy, "recover", 1.1)
            return _motion(Vector2.ZERO, "windup" if timer > 0.0 else "recover")
        "recover":
            if timer <= 0.0:
                _begin(enemy, "walk", 2.2)
            return _motion(Vector2.ZERO, "recover")
        "egg", "enter":
            return _motion(Vector2.ZERO, state)
        _:
            _begin(enemy, "walk", 0.6)
            return _motion(Vector2.ZERO)

static func _muzzle(enemy: Dictionary, direction: Vector2) -> Vector2:
    return enemy["position"] + direction * (float(enemy.get("radius", 21.0)) + 10.0)

static func warning(enemy: Dictionary) -> Dictionary:
    var kind: String = str(enemy.get("kind", ""))
    var state: String = str(enemy.get("state", ""))
    var timer: float = float(enemy.get("timer", 0.0))
    var direction: Vector2 = enemy.get("direction", Vector2.RIGHT)
    var origin: Vector2 = enemy.get("position", Vector2.ZERO)
    if kind == "raptor" and state in ["raptor_aim", "raptor_lunge"]:
        var remaining: float = POUNCE_TIME if state == "raptor_aim" else maxf(timer, 0.0)
        return {"kind": "lane", "origin": origin, "end": origin + direction * POUNCE_SPEED * remaining * float(enemy.get("speed_multiplier", 1.0)),
            "direction": direction, "radius": float(enemy.get("radius", 18.0)) + PLAYER_RADIUS,
            "progress": 1.0 - clampf(timer / POUNCE_WARNING, 0.0, 1.0) if state == "raptor_aim" else 1.0}
    if kind == "thrower" and state == "thrower_aim":
        var directions: Array = []
        for angle in FAN_ANGLES:
            directions.append(direction.rotated(angle))
        return {"kind": "fan", "origin": _muzzle(enemy, direction), "directions": directions,
            "range": float(enemy.get("shot_speed", STONE_SPEED * float(enemy.get("bullet_multiplier", 1.0)))) * STONE_LIFE,
            "progress": 1.0 - clampf(timer / FAN_WARNING, 0.0, 1.0)}
    if kind == "armored" and state == "armored_slam":
        return {"kind": "circle", "origin": enemy.get("slam_at", origin), "radius": QUAKE_RADIUS,
            "progress": 1.0 - clampf(timer / QUAKE_WARNING, 0.0, 1.0)}
    return {}

static func draw_warning(canvas: Node2D, enemy: Dictionary) -> bool:
    # Call from Main._draw before its legacy charger/boss/spitter branches.
    var marker: Dictionary = warning(enemy)
    if marker.is_empty():
        return false
    var origin: Vector2 = marker["origin"]
    var progress: float = marker["progress"]
    var edge: Color = Color("#b34b32")
    var fill: Color = Color(0.78, 0.35, 0.20, 0.12 + progress * 0.07)
    match marker["kind"]:
        "lane":
            var direction: Vector2 = marker["direction"]
            var end: Vector2 = marker["end"]
            var radius: float = marker["radius"]
            var normal: Vector2 = direction.orthogonal() * radius
            var polygon := PackedVector2Array([origin - normal, end - normal, end + direction * radius, end + normal, origin + normal])
            canvas.draw_colored_polygon(polygon, fill)
            polygon.append(polygon[0])
            canvas.draw_polyline(polygon, edge, 2.3, true)
            canvas.draw_line(end - direction * 20 - normal * 0.25, end, edge, 3.0, true)
            canvas.draw_line(end - direction * 20 + normal * 0.25, end, edge, 3.0, true)
        "fan":
            var directions: Array = marker["directions"]
            var reach: float = marker["range"]
            canvas.draw_colored_polygon(PackedVector2Array([origin, origin + directions[0] * reach, origin + directions[2] * reach]), Color(0.64, 0.38, 0.16, 0.055))
            for ray in directions:
                canvas.draw_line(origin, origin + ray * reach, Color(0.62, 0.35, 0.16, 0.34 + 0.25 * progress), 2.0, true)
                canvas.draw_circle(origin + ray * (20.0 + 10.0 * progress), 4.0, Color("#e5bd76"))
            canvas.draw_arc(origin, 15.0 + progress * 4.0, 0, TAU, 24, edge, 2.3, true)
        "circle":
            var radius: float = marker["radius"]
            canvas.draw_circle(origin, radius, fill)
            canvas.draw_arc(origin, radius, 0, TAU, 56, edge, 3.1, true)
            canvas.draw_arc(origin, maxf(8.0, radius * progress), 0, TAU, 48, Color(0.86, 0.59, 0.29, 0.45), 2.0, true)
            for index in range(4):
                var ray: Vector2 = Vector2.from_angle(PI * 0.25 + float(index) * PI * 0.5)
                canvas.draw_line(origin + ray * 13.0, origin + ray * 28.0, edge, 3.0, true)
    return true
