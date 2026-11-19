extends RefCounted
## Matte pigment shapes, kept in world space so effects read under the actors.

const DARK := Color("#3d2c2c")
const BONE := Color("#edd29d")
const EMBER := Color("#d68141")

static func family(attack: Dictionary, enemy: Dictionary) -> String:
    var kind: String = str(enemy.get("form", enemy.kind)).trim_suffix("_dark")
    if attack.mode == "echo":
        return "echo"
    if attack.mode == "rally":
        return "rally"
    if attack.mode == "guard":
        return "guard"
    if attack.get("style") == "rockfall":
        return "rockfall"
    match kind:
        "sporeback": return "spores"
        "embersnout": return "fire"
        "basaltroller": return "debris"
        "cinderback":
            return "fissure" if attack.shape == "lane" and attack.mode != "dash" else "debris"
    match str(attack.shape):
        "ring": return "roar"
        "fan": return "sweep"
        "lane": return "claws"
    return "debris"

static func impact(canvas, attack: Dictionary, enemy: Dictionary, t: float) -> void:
    var origin: Vector2 = attack.origin
    var forward: Vector2 = attack.direction
    var reach: float = attack.reach
    var width: float = attack.width
    var pigment: Color = attack.paint
    var flake := Color(BONE, 1.0 - t)
    var ink := Color(pigment, 0.94 * (1.0 - t))
    var key: String = family(attack, enemy)
    match key:
        "echo":
            var span: float = maxf(0.01, reach * minf(1.0, 0.32 + t * 3.8))
            _brush(canvas,origin,forward,span,width * 0.72,Color("#322530", 0.84 * (1.0 - t)),0.75)
            _brush(canvas,origin + forward.orthogonal() * width * 0.3,forward,span * 0.86,width * 0.47,ink,-0.8)
            _chips(canvas,origin,forward,span,width,flake,t,7)
        "fire":
            var span: float = reach * clampf(t * 5.0 + 0.27, 0.27, 1.0)
            if attack.shape == "fan":
                for i in range(5):
                    var tongue: Vector2 = forward.rotated((i - 2) * width * 0.40)
                    _brush(canvas,origin,tongue,span * (0.77 + i % 2 * 0.18),13.0,Color(EMBER, 0.86 * (1.0 - t)),0.22)
                    _brush(canvas,origin + tongue * 7.0,tongue,span * 0.55,4.0,flake,-0.38)
                return
            _brush(canvas,origin,forward,span,width,Color("#9a482e", 0.87 * (1.0 - t)),0.1)
            _brush(canvas,origin + forward * 5.0,forward,span * 0.84,width * 0.58,Color(EMBER, 1.0 - t),0.35)
            _brush(canvas,origin + forward * 8.0,forward,span * 0.65,width * 0.33,flake,-0.5)
            _chips(canvas,origin,forward,span,width,Color(EMBER, 1.0 - t),t,8)
        "claws":
            var advance: float = minf(1.0, 0.16 + 2.8 * t)
            var tip: Vector2 = origin + forward * reach * advance
            var streak: float = minf(reach * 0.65, origin.distance_to(tip))
            for i in range(3):
                var at: Vector2 = tip - forward * streak + forward.orthogonal() * (i - 1) * width * 0.54
                _brush(canvas,at,forward,streak,width * 0.29,ink,(i - 1) * 0.9)
                _brush(canvas,at + forward * streak * 0.25,forward,streak * 0.63,width * 0.12,flake,0.26)
        "fissure":
            var normal: Vector2 = forward.orthogonal()
            var span: float = reach * clampf(0.28 + t * 4.0, 0.28, 1.0)
            var crack := PackedVector2Array([origin])
            for i in range(1,9):
                var shift: float = sin(float(i) * 2.7) * width * 0.34
                crack.append(origin + forward * span * (i / 8.0) + normal * shift)
            canvas.draw_polyline(crack,Color(DARK, 1.0 - t),9.0,true)
            canvas.draw_polyline(crack,Color(EMBER, 1.0 - t),4.0,true)
            for i in range(1,8,2):
                canvas.draw_line(crack[i],crack[i] + forward * 11.0 + normal * sin(float(i)) * width * 0.5,ink,3.0,true)
            _chips(canvas,origin,forward,span,width,flake,t,8)
        "rockfall":
            for i in range(5):
                var angle: float = i * TAU / 5.0
                var rock: Vector2 = origin + Vector2.from_angle(angle) * reach * 0.50
                canvas.draw_circle(rock,11.0,Color(DARK,0.32 * (1.0-t)),true,-1.0,true)
                var height: float = maxf(0.0, 1.0 - t * 3.2) * (36.0 + i * 4.0)
                _chip(canvas,rock - Vector2(0,height),Vector2.from_angle(angle+0.46),9.0 + i,
                    Color("#d6b984",0.96*(1.0-t)),Color(DARK,1.0-t))
        "sweep":
            _sweep(canvas,origin,forward,reach,width,ink,flake,t)
        "spores":
            for i in range(13):
                var angle: float = 2.399 * float(i)
                var distance: float = reach * sqrt((i + 1.0) / 14.0) * (0.40 + 0.48 * t)
                var at: Vector2 = origin + Vector2.from_angle(angle) * distance - Vector2(0, t * 16.0)
                var r: float = (4.5 + fmod(i * 3.0, 6.0)) * (0.8 + t)
                canvas.draw_circle(at,r,Color(pigment, (1.0 - t) * 0.43),true,-1.0,true)
                canvas.draw_circle(at + Vector2(-1, -2), r * 0.36, flake,true,-1.0,true)
        "rally", "guard", "roar":
            var inner: float = width if attack.shape == "ring" else reach * 0.38
            var r: float = lerpf(inner, reach, minf(1.0, t * 1.22))
            for band in range(3):
                var ring: float = maxf(4.0, r - band * (reach - inner) * 0.21)
                var start: float = float(band) * 0.19
                var color: Color = flake if band == 1 else ink
                for i in range(6):
                    var a: float = start + i * TAU / 6.0
                    canvas.draw_arc(origin,ring,a,a + 0.87,12,color,5.0 - band,true)
        "debris":
            if attack.shape == "fan":
                _sweep(canvas,origin,forward,reach,width,ink,flake,t)
            var radial: bool = attack.shape in ["circle","ring"]
            if radial:
                for i in range(9):
                    var bearing: Vector2 = Vector2.from_angle(i * TAU / 9.0)
                    var start: Vector2 = origin + bearing * reach * (0.23 + t * 0.62)
                    _chip(canvas,start,bearing,5.0 + fmod(i * 3.0, 6.0),flake,ink)
            else:
                var span: float = reach * minf(1.0, 0.24 + 3.0 * t)
                _chips(canvas,origin,forward,span,maxf(14.0, width * 0.17 if attack.shape == "fan" else width),flake,t,8)

static func _brush(canvas, at: Vector2, forward: Vector2, length: float, width: float, color: Color, curl: float) -> void:
    if length < 1.0 or width < 0.3:
        return
    var side: Vector2 = forward.orthogonal()
    var shape := PackedVector2Array([
        at - side * width * 0.3,
        at + forward * length * 0.22 - side * width * 0.76,
        at + forward * length * 0.61 - side * width * 0.39,
        at + forward * length + side * width * curl,
        at + forward * length * 0.53 + side * width * 0.63,
        at + forward * length * 0.27 + side * width * 0.54,
    ])
    canvas.draw_colored_polygon(shape,color)

static func _sweep(canvas, at: Vector2, direction: Vector2, reach: float, width: float, ink: Color, highlight: Color, t: float) -> void:
    var front: float = direction.angle() - width + 2.0 * width * minf(1.0, t * 3.8 + 0.35)
    var back: float = maxf(direction.angle() - width, front - width * 1.32)
    var shape := PackedVector2Array()
    for i in range(15):
        var f: float = i / 14.0
        shape.append(at + Vector2.from_angle(lerpf(back, front, f)) * (reach - 2.0 + sin(i * 1.9) * 1.8))
    for i in range(14,-1,-1):
        var f: float = i / 14.0
        var taper: float = sin(f * PI)
        shape.append(at + Vector2.from_angle(lerpf(back, front, f)) * (reach - 7.0 - reach * 0.23 * taper))
    if front - back > 0.01:
        canvas.draw_colored_polygon(shape,ink)
        canvas.draw_arc(at,reach * 0.91,back + 0.06,front - 0.04,16,highlight,2.8,true)

static func _chips(canvas, origin: Vector2, direction: Vector2, length: float, width: float, light: Color, time: float, count: int) -> void:
    var normal: Vector2 = direction.orthogonal()
    for i in range(count):
        var f: float = float(i + 1) / float(count + 1)
        var side: float = sin(i * 3.13 + 0.75) * width * (0.55 + time * 0.35)
        var at: Vector2 = origin + direction * length * f + normal * side
        _chip(canvas,at,direction,2.4 + fmod(i * 3.7, 4.6),light,Color(DARK, light.a * 0.6))

static func _chip(canvas, at: Vector2, forward: Vector2, width: float, light: Color, shadow: Color) -> void:
    var side: Vector2 = forward.orthogonal()
    canvas.draw_colored_polygon(PackedVector2Array([at - forward * width,at + side * width,at + forward * width * 1.5,at - side * width * 0.58]),shadow)
    canvas.draw_colored_polygon(PackedVector2Array([at - forward * width,at + side * width,at + forward * width * 0.75]),light)
