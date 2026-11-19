extends RefCounted
## Ranged volleys and reinforcement calls share the attack state machine,
## but keep their own ground telegraphs and effects.

const MAX_SUMMONS := 2
const BOSS_DISTANCE := 520.0
const BONE := Color("#b3935d")
const MOSS := Color("#68845d")
const COAL := Color("#a9563c")
const REINFORCEMENTS := {
    "fernmask":["leafstalker","leafstalker"],
    "cinderback":["basaltroller"],
    "drumjaw":["bonecaller","ashhound"],
}

static func boss_ranged(form: String) -> Dictionary:
    match form.trim_suffix("_dark"):
        "fernmask":
            return volley("quill", 460.0, 3, 0.23, 294.0, 0.69, MOSS, 0.78)
        "cinderback":
            return {"shape":"circle","mode":"target","reach":96.0,"width":0.0,"tell":0.82,
                "paint":COAL,"cast_range":BOSS_DISTANCE,"style":"rockfall"}
    return volley("sonic", BOSS_DISTANCE, 3, 0.19, 255.0, 0.73, BONE, 0.80, 2)

static func volley(style: String, reach: float, count: int, spacing: float, speed: float,
        tell: float, pigment: Color, harm: float, waves: int = 1) -> Dictionary:
    return {"shape":"fan","mode":"volley","reach":reach,"width":maxf(0.026, spacing * (count - 1) * 0.5),
        "tell":tell,"paint":pigment,"style":style,"count":count,"spacing":spacing,
        "speed":speed,"harm":harm,"waves":waves}

static func summon() -> Dictionary:
    return {"shape":"summon","mode":"summon","reach":0.0,"width":0.0,"tell":0.93,"paint":BONE,
        "cast_range":BOSS_DISTANCE}

static func can_summon(world, enemy: Dictionary) -> bool:
    if int(enemy.attack_cycle) < 3 or float(world.elapsed) < float(enemy.get("next_summon",0.0)):
        return false
    if world.boss_defeated or world.enemies.size() >= world.enemy_limit():
        return false
    for other in world.enemies:
        if int(other.get("summoner_id",0)) == int(enemy.id) and float(other.hp) > 0.0:
            return false
    return true

static func summon_points(world, enemy: Dictionary, forward: Vector2) -> Array[Vector2]:
    var form: String = str(enemy.form).trim_suffix("_dark")
    var group: Array = REINFORCEMENTS.get(form, [])
    var origin: Vector2 = enemy.position
    var side := forward.orthogonal()
    var points: Array[Vector2] = []
    var allowed: int = mini(MAX_SUMMONS, world.enemy_limit() - world.enemies.size())
    for i in range(mini(group.size(), allowed)):
        var sign_: float = -1.0 if i == 0 else 1.0
        var target: Vector2 = origin + side * sign_ * 116.0 - forward * 26.0
        var resolved: Vector2 = world.map_view.move_body(target,target,30.0)
        if resolved.distance_to(world.player_position) >= 84.0 and resolved.distance_to(origin) >= 70.0:
            points.append(resolved)
    return points

static func call_reinforcements(world, enemy: Dictionary, attack: Dictionary) -> void:
    var dark: bool = str(enemy.form).ends_with("_dark")
    enemy.next_summon = float(world.elapsed) + (11.0 if dark else 16.0)
    if world.boss_defeated:
        return
    var group: Array = REINFORCEMENTS.get(str(enemy.form).trim_suffix("_dark"), [])
    var positions: Array = attack.get("summon_positions", [])
    for i in range(mini(positions.size(), group.size())):
        if world.enemies.size() >= world.enemy_limit():
            break
        world.spawn_enemy(group[i], positions[i])
        var ally: Dictionary = world.enemies.back()
        ally.summoner_id = enemy.id
        ally.timer = maxf(float(ally.timer), 1.1)
        if world.effects != null:
            world.effects.burst(ally.position, attack.paint, 29.0, "ring")

static func ray(attack: Dictionary, i: int, wave_index: int = 0) -> Vector2:
    var center: float = (float(attack.count) - 1.0) * 0.5
    var offset: float = (float(i) - center + wave_index * 0.5) * float(attack.spacing)
    return Vector2(attack.direction).rotated(offset)

static func fire(world, enemy: Dictionary, attack: Dictionary, wave_index: int = 0) -> void:
    var origin: Vector2 = attack.origin
    var speed: float = float(attack.speed) * float(enemy.get("bullet_multiplier",1.0))
    var radius: float = 8.0 if attack.style in ["fire","sonic"] else 6.0
    for i in range(int(attack.count)):
        var direction: Vector2 = ray(attack, i, wave_index)
        var mouth: float = minf(minf(32.0, float(enemy.radius) * 0.63), origin.distance_to(world.player_position) * 0.72)
        world.projectiles.append({"position":origin + direction * mouth,"velocity":direction * speed,
            "life":maxf(0.1, (float(attack.reach) - mouth) / speed),"radius":radius,
            "damage":float(enemy.damage) * float(attack.harm),"kind":"hostile","boss":enemy.kind == "boss",
            "hostile_style":attack.style,"source_kind":enemy.kind})

static func draw_tell(canvas, attack: Dictionary, edge: Color, wash: Color, progress: float) -> bool:
    if attack.mode == "summon":
        for point in attack.get("summon_positions", []):
            canvas.draw_circle(point,32.0,wash)
            for i in range(4):
                var start: float = i * PI * 0.5 + 0.18
                canvas.draw_arc(point,32.0,start,start + 1.12,10,edge,3.0,true)
            var extent: float = 7.0 + 7.0 * progress
            var diamond := PackedVector2Array([point+Vector2(0,-extent),point+Vector2(extent,0),
                point+Vector2(0,extent),point+Vector2(-extent,0),point+Vector2(0,-extent)])
            canvas.draw_polyline(diamond,edge,2.5,true)
        return true
    if attack.mode != "volley":
        return false
    for wave_index in range(int(attack.waves)):
        var pigment := Color(edge, edge.a if wave_index == 0 else edge.a * 0.56)
        for i in range(int(attack.count)):
            var forward: Vector2 = ray(attack,i,wave_index)
            var origin: Vector2 = attack.origin
            var aim_end: Vector2 = origin + forward * float(attack.reach)
            var across: Vector2 = forward.orthogonal() * 4.0
            canvas.draw_line(origin,aim_end,pigment,1.8,true)
            canvas.draw_polyline(PackedVector2Array([aim_end - forward * 11.0 + across,aim_end,aim_end - forward * 11.0 - across]),pigment,2.4,true)
    return true
