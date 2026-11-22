extends RefCounted

const INK: Color = Color("#272524")
# Parked/orbiting weapons must not draw rotating wrap or aura rings.
const WEAPON_ORBIT_RINGS := false
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
            var sling_ench: bool = bool(projectile.get("enchanted", false)) or bool(projectile.get("fire_enchanted", false)) or bool(projectile.get("thunder_enchanted", false))
            var sling_body: Color = _shot_body_color(projectile, Color("#c6bfa9"))
            var sling_shine: Color = _shot_shine_color(projectile, Color("#fff4d7"))
            if sling_ench:
                canvas.draw_circle(point, 11.0, Color(sling_body.r, sling_body.g, sling_body.b, 0.34))
            canvas.draw_line(point - direction * 19, point - direction * 5, Color(0.14, 0.12, 0.10, 0.55), 4.0, true)
            canvas.draw_line(point - direction * 18, point - direction * 6, sling_body if sling_ench else sling_shine, 2.2 if sling_ench else 1.7, true)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(8, -1), Vector2(3, -7), Vector2(-4, -6), Vector2(-7, 1), Vector2(-2, 7), Vector2(5, 5)]), INK)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(5.8, -0.7), Vector2(2.2, -4.9), Vector2(-2.7, -4.2), Vector2(-4.8, 0.7), Vector2(-1.2, 4.8), Vector2(3.4, 3.4)]), sling_body)
            canvas.draw_line(point - direction * 2 - normal * 3.6, point + direction * 2.8 - normal * 3.2, sling_shine, 1.8, true)
            canvas.draw_polyline(PackedVector2Array([point + direction * 2 + normal * 0.2, point - direction * 1.5 + normal * 1.5, point - direction * 0.5 + normal * 4]), sling_body.darkened(0.35), 1.2, true)
        "powder":
            var enchanted: bool = bool(projectile.get("enchanted", false))
            var any_ench: bool = enchanted or bool(projectile.get("fire_enchanted", false)) or bool(projectile.get("thunder_enchanted", false))
            var rune_color: Color = _shot_body_color(projectile, Color("#ff8e36"))
            var rune_core: Color = _shot_shine_color(projectile, Color("#fff0a1"))
            var flicker: float = sin(elapsed * 33.0 + point.x * 0.13) * 3.0
            if any_ench:
                canvas.draw_circle(point, 15.5, Color(rune_color.r, rune_color.g, rune_color.b, 0.30))
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(-4, -6), Vector2(-18, -7), Vector2(-14, -3), Vector2(-34 - flicker, 0), Vector2(-20, 3), Vector2(-24, 7), Vector2(-5, 6)]), INK)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(-5, -4), Vector2(-17, -5), Vector2(-13, -1), Vector2(-29 - flicker, 0), Vector2(-17, 2), Vector2(-20, 5), Vector2(-5, 4)]), rune_color)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(-5, -2), Vector2(-22 - flicker * 0.5, 0), Vector2(-6, 2.5)]), rune_core)
            canvas.draw_circle(point, 10.0, INK)
            canvas.draw_circle(point, 7.6, rune_color.darkened(0.22) if any_ench else Color("#57534c"))
            canvas.draw_arc(point, 7.7, 0.0, TAU, 12, rune_color if any_ench else Color("#c6a366"), 1.8 if any_ench else 1.6, true)
            canvas.draw_arc(point + Vector2(-1.0, -1.4), 4.7, -2.8, -0.4, 8, rune_core if any_ench else Color("#e3dbc4"), 1.8 if any_ench else 1.7, true)
            if enchanted:
                var rune := _shape(point, direction.rotated(sin(elapsed * 5.0) * 0.15), [Vector2(14, 0), Vector2(0, 11), Vector2(-14, 0), Vector2(0, -11), Vector2(14, 0)])
                canvas.draw_polyline(rune, INK, 3.5, true)
                canvas.draw_polyline(rune, rune_core, 1.5, true)
                canvas.draw_circle(point, 2.1, rune_core)
        "staff":
            var staff_tier: int = int(projectile.get("vfx_tier", 0))
            var body: Color = staff_tint(staff_tier)
            var core: Color = staff_core(staff_tier)
            var shine: Color = staff_highlight(staff_tier)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(-4, -4.8), Vector2(-32, 0), Vector2(-4, 4.8)]), INK)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(-5, -2.9), Vector2(-28, 0), Vector2(-5, 2.9)]), body)
            canvas.draw_line(point - direction * 23, point - direction * 4, shine, 1.3, true)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(12, 0), Vector2(0, -8), Vector2(-9, 0), Vector2(0, 8)]), INK)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(8.8, 0), Vector2(0, -5.6), Vector2(-6.1, 0), Vector2(0, 5.6)]), core)
            canvas.draw_colored_polygon(_shape(point, direction, [Vector2(8.8, 0), Vector2(0, -5.6), Vector2(-1, 0)]), shine)
            canvas.draw_line(point - direction * 15 - normal * 4, point - direction * 15 + normal * 4, shine, 1.4, true)
            if staff_tier >= 1:
                var spark: float = 1.0 + 0.35 * sin(elapsed * 18.0 + point.x)
                canvas.draw_circle(point + direction * 2.0, 3.2 * spark, Color(core, 0.55))
                if staff_tier >= 2:
                    canvas.draw_arc(point, 11.0 + spark, elapsed * 6.0, elapsed * 6.0 + 4.2, 10, Color(body, 0.7), 1.4, true)
        "hostile":
            # High-contrast crimson danger aura + pulsing warning ring so ALL enemy projectiles stand out unmistakably from coins & XP!
            var danger_pulse: float = 1.0 + 0.16 * sin(elapsed * 20.0 + point.x * 0.05)
            canvas.draw_circle(point, 15.5 * danger_pulse, Color(1.0, 0.14, 0.24, 0.30))
            canvas.draw_arc(point, 13.0 * danger_pulse, 0.0, TAU, 12, Color(1.0, 0.22, 0.30, 0.88), 2.2, true)
            canvas.draw_line(point - direction * 28.0, point - direction * 4.0, Color(0.96, 0.18, 0.28, 0.62), 5.2, true)
            var style: String = str(projectile.get("hostile_style",""))
            if style in ["quill", "reed"]:
                var pigment := Color("#ff4c4c") if style == "quill" else Color("#ff3868")
                canvas.draw_colored_polygon(_shape(point,direction,[Vector2(15,0),Vector2(2,-6.5),Vector2(-13,-3),Vector2(-11,5),Vector2(2,7)]),INK)
                canvas.draw_colored_polygon(_shape(point,direction,[Vector2(11.5,0),Vector2(1.5,-4),Vector2(-9,0),Vector2(0.5,4)]),pigment)
                canvas.draw_line(point - direction * 6.0,point + direction * 8.0,Color("#fff0f2"),2.2,true)
                return true
            if style == "sonic":
                for i in range(3):
                    var center: Vector2 = point - direction * (12.0 + 7.0 * i)
                    var edge : Color = Color("#ff4655", 0.96 - 0.18 * i)
                    var sweep: float = direction.angle()
                    canvas.draw_arc(center,21.0,sweep-0.68,sweep+0.68,10,Color("#3b0e18",edge.a),7.2,true)
                    canvas.draw_arc(center,21.0,sweep-0.68,sweep+0.68,10,edge,3.6,true)
                return true
            if style in ["spore","fire"]:
                var pigment: Color = Color("#ff4d24") if style == "fire" else Color("#ff3366")
                var glow: Color = Color("#fff0c4") if style == "fire" else Color("#ffd9e8")
                for i in range(3):
                    var spot: Vector2 = point - direction * (8.0 + i * 6.5) + normal * sin(elapsed * 21.0 + i * 2.0) * (i + 1)
                    canvas.draw_circle(spot,5.8-i,Color(pigment,0.72-i*0.14),true,-1.0,false)
                canvas.draw_circle(point,10.8,INK,true,-1.0,false)
                canvas.draw_circle(point,8.0,pigment,true,-1.0,false)
                canvas.draw_circle(point + Vector2(-1.8,-2.0),3.4,glow,true,-1.0,false)
                return true
            if projectile.get("hostile_style","")=="stone":
                canvas.draw_line(point-direction*26,point-direction*4,Color("#ff3a2e", 0.72),6.2,true)
                canvas.draw_line(point-direction*24,point-direction*6,Color("#ffcf8a"),2.6,true)
                canvas.draw_colored_polygon(_shape(point,direction,[Vector2(12,0),Vector2(6,-11),Vector2(-7,-9),Vector2(-11,5),Vector2(0,11)]),INK)
                canvas.draw_colored_polygon(_shape(point,direction,[Vector2(9,0),Vector2(4.5,-8),Vector2(-4.5,-6),Vector2(-7.5,3.5),Vector2(0,7.5)]),Color("#e05a3a"))
                canvas.draw_line(point+Vector2(-4,-4),point+Vector2(2,-5),Color("#fff2cc"),2.2,true)
                return true
            canvas.draw_line(point - direction * 26, point, INK, 6.8, true)
            canvas.draw_line(point - direction * 24, point, Color("#ff2e63"), 3.4, true)
            var outer := PackedVector2Array()
            var inner := PackedVector2Array()
            for index in range(12):
                var spike: Vector2 = Vector2.from_angle(float(index) * TAU / 12.0) * (12.8 if index % 2 == 0 else 7.6)
                outer.append(point + spike)
                inner.append(point + spike * 0.76)
            canvas.draw_colored_polygon(outer, INK)
            canvas.draw_colored_polygon(inner, Color("#ff2a6d"))
            canvas.draw_circle(point + Vector2(-1.2, -1.6), 4.0, Color("#fff0f5"))
    return true


static func staff_tint(tier: int) -> Color:
    # Stay cyan/blue through base and 进阶 (levels 1-4). Only 觉醒 (level 5+) turns purple.
    if tier >= 2:
        return Color("#b46cf0")
    return Color("#57dce8")

static func staff_core(tier: int) -> Color:
    if tier >= 2:
        return Color("#c99bff")
    return Color("#63edee")

static func staff_highlight(tier: int) -> Color:
    if tier >= 2:
        return Color("#f0e6ff")
    return Color("#ecffed")

static func fire_tint(tier: int) -> Color:
    if tier >= 2:
        return Color("#2ee67a")
    if tier >= 1:
        return Color("#ff5e1a")
    return Color("#ff8e36")

static func fire_core(tier: int) -> Color:
    if tier >= 2:
        return Color("#c8ff9e")
    if tier >= 1:
        return Color("#ffd36a")
    return Color("#fff0a1")

static func fire_highlight(tier: int) -> Color:
    if tier >= 2:
        return Color("#ebffd8")
    if tier >= 1:
        return Color("#ffe9a8")
    return Color("#fff4c8")

static func thunder_tint(tier: int) -> Color:
    # Bright electric silver-white (distinct from blue/cyan staff magic!)
    if tier >= 2:
        return Color("#ffffff")
    if tier >= 1:
        return Color("#eef6ff")
    return Color("#dce8f2")

static func thunder_core(tier: int) -> Color:
    if tier >= 2:
        return Color("#ffffff")
    if tier >= 1:
        return Color("#f7fbff")
    return Color("#edf5fc")

static func thunder_highlight(tier: int) -> Color:
    if tier >= 2:
        return Color("#ffffff")
    if tier >= 1:
        return Color("#ffffff")
    return Color("#f5faff")

static func _shot_body_color(projectile: Dictionary, fallback: Color) -> Color:
    if bool(projectile.get("enchanted", false)):
        return staff_tint(int(projectile.get("vfx_tier", 0)))
    if bool(projectile.get("fire_enchanted", false)):
        return fire_tint(int(projectile.get("fire_tier", 0)))
    if bool(projectile.get("thunder_enchanted", false)):
        if bool(projectile.get("thunder_red", false)):
            return Color("#ff3a2e")
        return thunder_tint(int(projectile.get("thunder_tier", 0)))
    return fallback

static func _shot_shine_color(projectile: Dictionary, fallback: Color) -> Color:
    if bool(projectile.get("enchanted", false)):
        return staff_highlight(int(projectile.get("vfx_tier", 0)))
    if bool(projectile.get("fire_enchanted", false)):
        return fire_highlight(int(projectile.get("fire_tier", 0)))
    if bool(projectile.get("thunder_enchanted", false)):
        if bool(projectile.get("thunder_red", false)):
            return Color("#ffd8cc")
        return thunder_highlight(int(projectile.get("thunder_tier", 0)))
    return fallback

static func weapon_enchant_modulate(kind: String, tier: int) -> Color:
    if kind == "fire":
        if tier >= 2:
            return Color(0.62, 1.24, 0.78)
        if tier >= 1:
            return Color(1.16, 0.78, 0.58)
        return Color(1.12, 0.84, 0.64)
    if kind == "rune":
        if tier >= 2:
            return Color(0.96, 0.78, 1.18)
        return Color(0.82, 0.96, 1.10)
    if kind == "thunder":
        if tier >= 2:
            return Color(1.12, 1.15, 1.20)
        if tier >= 1:
            return Color(1.08, 1.11, 1.16)
        return Color(1.04, 1.08, 1.13)
    return Color.WHITE

static func draw_fire_wrap(canvas, point: Vector2, direction: Vector2, size: float, elapsed: float, tier: int = 0) -> void:
    var axis: Vector2 = direction.normalized() if direction.length_squared() > 0.01 else Vector2.UP
    var side: Vector2 = axis.orthogonal()
    var flicker: float = 0.70 + 0.30 * sin(elapsed * 22.0 + point.x * 0.15)
    var radius: float = size * (1.05 + 0.22 * flicker + 0.12 * float(tier))
    var wrap: Color = fire_tint(tier)
    var core: Color = fire_core(tier)
    canvas.draw_circle(point, radius * 1.28, Color(wrap, 0.28 * flicker))
    canvas.draw_circle(point, radius * 0.92, Color(wrap, 0.20 * flicker))
    for index in range(8):
        var phase: float = elapsed * 9.0 + float(index) * 0.785
        var outward: Vector2 = (axis * cos(phase) + side * sin(phase * 1.3)).normalized()
        var tongue: Vector2 = point + outward * radius * (0.62 + 0.48 * absf(sin(phase * 1.7)))
        var width: Vector2 = outward.orthogonal() * (3.8 + 1.8 * flicker)
        canvas.draw_colored_polygon(PackedVector2Array([
            point + width * 0.28,
            tongue,
            point - width * 0.28
        ]), Color(wrap.r, clampf(wrap.g + 0.12 * float(index % 2), 0.0, 1.0), wrap.b, 0.86 * flicker))
    canvas.draw_circle(point + axis * 1.5, radius * 0.38, Color(core, 0.62 * flicker))

static func draw_thunder_wrap(canvas, point: Vector2, size: float, elapsed: float, tier: int = 0, is_red: bool = false) -> void:
    var tint: Color = Color("#ff3a2e") if is_red else thunder_tint(tier)
    var core: Color = Color("#ffd8cc") if is_red else thunder_highlight(tier)
    var pulse: float = 0.80 + 0.20 * sin(elapsed * 16.0)
    var radius: float = size * (0.95 + 0.12 * float(tier))
    canvas.draw_circle(point, radius * pulse, Color(tint, 0.16 + 0.05 * float(tier)))
    for index in range(3 + tier):
        var angle: float = elapsed * (4.0 + float(tier)) + float(index) * (TAU / 3.0)
        var tip: Vector2 = point + Vector2.from_angle(angle) * radius * 0.95
        canvas.draw_line(point, tip, Color(tint, 0.75), 1.6 + 0.4 * float(tier), true)
    canvas.draw_arc(point, radius * 0.85, elapsed * 5.0, elapsed * 5.0 + 3.6, 10, Color(core, 0.70), 1.5, true)

static func draw_staff_aura(canvas, point: Vector2, size: float, elapsed: float, tier: int) -> void:
    var tint: Color = staff_tint(tier)
    var pulse: float = 0.75 + 0.25 * sin(elapsed * 8.0)
    canvas.draw_circle(point, size * pulse, Color(tint, 0.16 if tier >= 2 else 0.12))
    canvas.draw_arc(point, size * (0.9 + 0.15 * pulse), elapsed * 3.0, elapsed * 3.0 + 4.0, 12, Color(tint, 0.55), 1.5, true)
    if tier >= 2:
        canvas.draw_arc(point, size * 1.2, -elapsed * 2.4, -elapsed * 2.4 + 3.4, 10, Color(staff_highlight(tier), 0.5), 1.2, true)
