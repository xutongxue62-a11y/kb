extends RefCounted

const INK: Color = Color("#272524")
const COIN_UNIT = preload("res://assets/pickups/coin_unit.svg")
const XP_UNIT = preload("res://assets/pickups/xp_unit.svg")

static func _ellipse(canvas, center: Vector2, extent: Vector2, color: Color) -> void:
    var points := PackedVector2Array()
    for index in range(28):
        var angle: float = float(index) * TAU / 28.0
        points.append(center + Vector2(cos(angle), sin(angle)) * extent)
    canvas.draw_colored_polygon(points, color)

static func _shape(center: Vector2, direction: Vector2, coordinates: Array) -> PackedVector2Array:
    var points := PackedVector2Array()
    var normal: Vector2 = direction.orthogonal()
    for local in coordinates:
        points.append(center + direction * local.x + normal * local.y)
    return points

# One cached transparent texture per resource; one draw call per visible unit.
static func draw_pickups(canvas, drops: Array, bounds: Rect2, elapsed: float) -> void:
    # Order GPU submissions by texture. Objects/positions/values stay independent;
    # no resource is removed, credited, or combined for rendering performance.
    for kind in ["xp", "coin"]:
        for drop in drops:
            if drop.get("kind", "xp") == kind and bounds.has_point(drop["position"]):
                draw_pickup(canvas,drop,elapsed)

static func draw_pickup(canvas, drop: Dictionary, elapsed: float) -> void:
    var ground: Vector2 = drop["position"]
    var bob: float = sin(elapsed * 4.0 + ground.x) * 1.6
    var icon: Texture2D = COIN_UNIT if drop.get("kind", "xp") == "coin" else XP_UNIT
    canvas.draw_texture_rect(icon, Rect2(ground + Vector2(-16, -20 + bob), Vector2(32,36)), false)

# Only visual dimensions live here. Never mutate the projectile or read its
# collision radius to size an effect; buffs must not inflate it over the hero.
static func draw_projectile(canvas, projectile: Dictionary, elapsed: float) -> bool:
    var key: String = str(projectile.get("kind", ""))
    if key not in ["sling", "powder", "staff", "hostile"]:
        return false
    var point: Vector2 = projectile["position"]
    var velocity: Vector2 = projectile.get("velocity", Vector2.ZERO)
    var direction: Vector2 = velocity.normalized() if velocity.length_squared() > 0.01 else Vector2.RIGHT
    var normal: Vector2 = direction.orthogonal()
    match key:
        "sling":
            canvas.draw_line(point - direction * 19, point - direction * 5, Color(0.14, 0.12, 0.10, 0.55), 4.0, true)
            canvas.draw_line(point - direction * 18, point - direction * 6, Color("#e8dfc7"), 1.7, true)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(8, -1), Vector2(3, -7), Vector2(-4, -6), Vector2(-7, 1), Vector2(-2, 7), Vector2(5, 5)]), INK)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(5.8, -0.7), Vector2(2.2, -4.9), Vector2(-2.7, -4.2), Vector2(-4.8, 0.7), Vector2(-1.2, 4.8), Vector2(3.4, 3.4)]), Color("#c6bfa9"))
            canvas.draw_line(point - direction * 2 - normal * 3.6, point + direction * 2.8 - normal * 3.2, Color("#fff4d7"), 1.8, true)
            canvas.draw_polyline(PackedVector2Array([point + direction * 2 + normal * 0.2, point - direction * 1.5 + normal * 1.5, point - direction * 0.5 + normal * 4]), Color("#776c5b"), 1.2, true)
        "powder":
            var enchanted: bool = bool(projectile.get("enchanted", false))
            var flicker: float = sin(elapsed * 33.0 + point.x * 0.13) * 3.0
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(-4, -6), Vector2(-18, -7), Vector2(-14, -3), Vector2(-34 - flicker, 0), Vector2(-20, 3), Vector2(-24, 7), Vector2(-5, 6)]), INK)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(-5, -4), Vector2(-17, -5), Vector2(-13, -1), Vector2(-29 - flicker, 0), Vector2(-17, 2), Vector2(-20, 5), Vector2(-5, 4)]), Color("#51e6ed") if enchanted else Color("#ff8e36"))
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(-5, -2), Vector2(-22 - flicker * 0.5, 0), Vector2(-6, 2.5)]), Color("#eaffd3") if enchanted else Color("#fff0a1"))
            canvas.draw_circle(point, 10.0, INK)
            canvas.draw_circle(point, 7.6, Color("#57534c"))
            canvas.draw_arc(point, 7.7, 0.0, TAU, 24, Color("#c6a366"), 1.6, true)
            canvas.draw_arc(point + Vector2(-1.0, -1.4), 4.7, -2.8, -0.4, 12, Color("#e3dbc4"), 1.7, true)
            if enchanted:
                var rune := _shape(point, direction.rotated(sin(elapsed * 5.0) * 0.15), [Vector2(14, 0), Vector2(0, 11), Vector2(-14, 0), Vector2(0, -11), Vector2(14, 0)])
                canvas.draw_polyline(rune, INK, 3.5, true)
                canvas.draw_polyline(rune, Color("#a0ffff"), 1.5, true)
                canvas.draw_circle(point, 2.1, Color("#bcfdff"))
        "staff":
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(-4, -4.8), Vector2(-32, 0), Vector2(-4, 4.8)]), INK)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(-5, -2.9), Vector2(-28, 0), Vector2(-5, 2.9)]), Color("#57dce8"))
            canvas.draw_line(point - direction * 23, point - direction * 4, Color("#e2ffff"), 1.3, true)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(12, 0), Vector2(0, -8), Vector2(-9, 0), Vector2(0, 8)]), INK)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(8.8, 0), Vector2(0, -5.6), Vector2(-6.1, 0), Vector2(0, 5.6)]), Color("#63edee"))
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(8.8, 0), Vector2(0, -5.6), Vector2(-1, 0)]), Color("#ecffed"))
            canvas.draw_line(point - direction * 15 - normal * 4, point - direction * 15 + normal * 4, Color("#a7ffff"), 1.4, true)
        "hostile":
            var style: String = str(projectile.get("hostile_style",""))
            if style in ["quill", "reed"]:
                var pigment := Color("#a7a66a") if style == "quill" else Color("#83aa80")
                canvas.draw_line(point - direction * 23.0, point - direction * 3.0, Color(pigment,0.55),3.0,true)
                canvas.draw_colored_polygon(_shape(point,direction,[Vector2(13,0),Vector2(1,-5),Vector2(-12,-2),Vector2(-10,4),Vector2(1,6)]),INK)
                canvas.draw_colored_polygon(_shape(point,direction,[Vector2(10,0),Vector2(1,-3),Vector2(-8,0),Vector2(0,3)]),pigment)
                canvas.draw_line(point - direction * 6.0,point + direction * 7.0,Color("#efe0b0"),1.6,true)
                return true
            if style == "sonic":
                for i in range(3):
                    var center: Vector2 = point - direction * (13.0 + 7.0 * i)
                    var edge : Color = Color("#e4b170",0.90 - 0.19 * i)
                    var sweep: float = direction.angle()
                    canvas.draw_arc(center,19.0,sweep-0.63,sweep+0.63,10,Color("#684637",edge.a),6.2,true)
                    canvas.draw_arc(center,19.0,sweep-0.63,sweep+0.63,10,edge,3.0,true)
                return true
            if style in ["spore","fire"]:
                var pigment: Color = Color("#d47c42") if style == "fire" else Color("#8fa25b")
                var glow: Color = Color("#f0c074") if style == "fire" else Color("#d6db9d")
                for i in range(3):
                    var spot: Vector2 = point - direction * (7.0 + i * 6.0) + normal * sin(elapsed * 21.0 + i * 2.0) * (i + 1)
                    canvas.draw_circle(spot,5.0-i,Color(pigment,0.60-i*0.13),true,-1.0,true)
                canvas.draw_circle(point,9.0,INK,true,-1.0,true)
                canvas.draw_circle(point,6.6,pigment,true,-1.0,true)
                canvas.draw_circle(point + Vector2(-1.8,-2.0),2.7,glow,true,-1.0,true)
                return true
            if projectile.get("hostile_style","")=="stone":
                canvas.draw_line(point-direction*24,point-direction*4,Color("#4f3e31"),5.5,true)
                canvas.draw_line(point-direction*22,point-direction*6,Color("#d7b17f"),2.5,true)
                canvas.draw_colored_polygon(_shape(point,direction,[Vector2(11,0),Vector2(5,-10),Vector2(-6,-8),Vector2(-10,4),Vector2(0,10)]),INK)
                canvas.draw_colored_polygon(_shape(point,direction,[Vector2(8,0),Vector2(4,-7),Vector2(-4,-5),Vector2(-7,3),Vector2(0,7)]),Color("#be9c78"))
                canvas.draw_line(point+Vector2(-4,-4),point+Vector2(2,-5),Color("#ffe0ac"),2.0,true)
                return true
            canvas.draw_line(point - direction * 23, point, INK, 6.0, true)
            canvas.draw_line(point - direction * 21, point, Color("#bd4e8e"), 2.8, true)
            var outer := PackedVector2Array()
            var inner := PackedVector2Array()
            for index in range(12):
                var spike: Vector2 = Vector2.from_angle(float(index) * TAU / 12.0) * (11.0 if index % 2 == 0 else 6.6)
                outer.append(point + spike)
                inner.append(point + spike * 0.76)
            canvas.draw_colored_polygon(outer, INK)
            canvas.draw_colored_polygon(inner, Color("#c4377e"))
            canvas.draw_circle(point + Vector2(-1.3, -1.8), 3.0, Color("#ffcade"))
    return true
