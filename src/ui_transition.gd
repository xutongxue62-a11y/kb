extends Control

var previous: Texture2D
var effect := "compose"
var progress := 1.0
var duration := 0.36
var going_back := false
const BURN_STEPS := 72

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS

func play(texture: Texture2D, mode: String = "compose") -> void:
    previous = texture
    effect = mode
    duration = 1.08 if mode == "burn" else (0.58 if mode == "page" else (0.22 if mode == "fade" else 0.36))
    progress = 0.0
    visible = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    queue_redraw()

func active() -> bool:
    return visible and progress < 1.0

func finish() -> void:
    progress = 1.0
    previous = null
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _process(delta: float) -> void:
    if not active():
        return
    progress = minf(1.0, progress + delta / duration)
    if progress >= 1.0:
        finish()
    else:
        queue_redraw()

func burn_boundary(amount: float) -> PackedVector2Array:
    var center := size * Vector2(0.53, 0.52)
    var radius: float = lerpf(-20.0, size.length() * 0.63, clampf(amount, 0, 1))
    var contour := PackedVector2Array()
    for i in range(BURN_STEPS):
        var angle: float = TAU * i / BURN_STEPS
        var torn: float = sin(i * 1.81 + amount * 7.0) * 11.0 + sin(i * 0.67) * 17.0
        contour.append(center + Vector2.from_angle(angle) * maxf(0.5, radius + torn))
    return contour

func _outside_point(direction: Vector2, center: Vector2) -> Vector2:
    var dx: float = INF
    var dy: float = INF
    if absf(direction.x) > 0.00001:
        dx = ((size.x - center.x) if direction.x > 0 else -center.x) / direction.x
    if absf(direction.y) > 0.00001:
        dy = ((size.y - center.y) if direction.y > 0 else -center.y) / direction.y
    return center + direction * minf(dx, dy)

func _old_polygon(points: PackedVector2Array, alpha: float = 1.0) -> void:
    if points.size() < 3:
        return
    if previous == null:
        draw_colored_polygon(points, Color(0.94, 0.90, 0.80, alpha))
        return
    var uv := PackedVector2Array()
    for point in points:
        uv.append(point / size)
    draw_colored_polygon(points, Color(1, 1, 1, alpha), uv, previous)

func _full_old(alpha: float = 1.0, offset: Vector2 = Vector2.ZERO) -> void:
    if previous != null:
        draw_texture_rect(previous, Rect2(offset, size), false, Color(1, 1, 1, alpha))

func flame_polygon(at: Vector2, normal: Vector2, length: float, curl: float) -> PackedVector2Array:
    var tangent: Vector2 = normal.orthogonal()
    var tip: Vector2 = at + normal * maxf(length, 19) + tangent * clampf(curl, -6, 6)
    return PackedVector2Array([at - tangent * 9, at + normal * 10 - tangent * 8, tip - tangent * 2, tip + normal * 4, at + normal * 9 + tangent * 8, at + tangent * 9])

func _draw_burn() -> void:
    if progress < 0.055:
        _full_old()
        return
    var center := size * Vector2(0.53, 0.52)
    var contour := burn_boundary(progress)
    for i in range(BURN_STEPS):
        var j: int = (i + 1) % BURN_STEPS
        var da: Vector2 = (contour[i] - center).normalized()
        var db: Vector2 = (contour[j] - center).normalized()
        var oa: Vector2 = _outside_point(da, center)
        var ob: Vector2 = _outside_point(db, center)
        var ia: Vector2 = center + da * minf(center.distance_to(contour[i]), center.distance_to(oa))
        var ib: Vector2 = center + db * minf(center.distance_to(contour[j]), center.distance_to(ob))
        var a_clipped: bool = ia.distance_squared_to(oa) < 0.1
        var b_clipped: bool = ib.distance_squared_to(ob) < 0.1
        if a_clipped and b_clipped:
            continue
        var sector := PackedVector2Array([oa, ob])
        if not b_clipped: sector.append(ib)
        if not a_clipped: sector.append(ia)
        _old_polygon(sector)
    var hot_line := PackedVector2Array()
    for i in range(BURN_STEPS):
        var j: int = (i + 1) % BURN_STEPS
        var n: Vector2 = (contour[i] - center).normalized()
        var next_n: Vector2 = (contour[j] - center).normalized()
        var rough: float = 10.0 + sin(i * 2.83) * 5.0
        var rough_next: float = 10.0 + sin(j * 2.83) * 5.0
        var outer_a: Vector2 = contour[i] + n * rough
        var outer_b: Vector2 = contour[j] + next_n * rough_next
        var inner_a: Vector2 = contour[i] - n * 4
        var inner_b: Vector2 = contour[j] - next_n * 4
        draw_colored_polygon(PackedVector2Array([outer_a, outer_b, inner_b, inner_a]), Color("#3b2a20"))
        draw_line(contour[i] + n * 2, contour[j] + next_n * 2, Color("#a8552d"), 2.5, true)
        hot_line.append(inner_a)
        if i % 2 == 0:
            var tear: Vector2 = contour[i] + n * (rough + 12 + i % 4 * 3)
            draw_line(outer_a, tear, Color("#59402c"), 1.5, true)
    hot_line.append(hot_line[0])
    draw_polyline(hot_line, Color("#e8b96a"), 1.6, true)
    for i in range(48):
        var k: int = (i * 7 + 1) % BURN_STEPS
        var at: Vector2 = contour[k]
        var normal: Vector2 = (at - center).normalized()
        var tangent: Vector2 = normal.orthogonal()
        var flicker: float = 0.5 + 0.5 * sin(progress * 73 + i * 2.399)
        var length: float = 19 + pow(flicker, 1.6) * 62
        var curl: float = sin(progress * 41 + i * 1.7) * 6
        var tip: Vector2 = at + normal * length + tangent * curl
        draw_colored_polygon(flame_polygon(at, normal, length, curl), Color("#cd6d30"))
        draw_colored_polygon(flame_polygon(at + tangent * 2, normal, maxf(19, length * 0.65), -curl * 0.6), Color("#edac54"))
        draw_colored_polygon(PackedVector2Array([at - tangent * 4, at.lerp(tip, 0.53), at + normal * 7 + tangent * 4]), Color("#ffe3a3"))
        var life: float = fmod(i * 0.173 + progress * 2.3, 1.0)
        var ash: Vector2 = at - normal * (24 + life * 125) + tangent * sin(life * 5 + i) * 19 + Vector2(0, -life * life * 95)
        var spin: Vector2 = Vector2.from_angle(i + progress * 11) * (3 + i % 4)
        var across: Vector2 = spin.orthogonal() * 0.5
        draw_colored_polygon(PackedVector2Array([ash - spin, ash - across, ash + spin, ash + across]), Color(0.24, 0.18, 0.13, (1 - life) * 0.75))
        if i % 2 == 0:
            draw_colored_polygon(PackedVector2Array([ash - spin, ash - across, ash + spin * 0.4]), Color(0.89, 0.75, 0.53, (1 - life) * 0.85))
        var spark: Vector2 = at - normal * life * 54 + tangent * sin(i * 1.4 + progress * 9) * 14 + Vector2(0, -life * 58)
        draw_line(spark, spark + Vector2(-2, -4 - flicker * 6), Color(1, 0.75, 0.34, (1 - life) * 0.8), 1.3, true)
        if i % 4 == 0:
            var smoke := PackedVector2Array()
            for n in range(9):
                var rise: float = n / 8.0
                smoke.append(at - normal * (8 + rise * 25) + Vector2(sin(rise * 6 + progress * 12 + i) * rise * 13, -rise * 60))
            draw_polyline(smoke, Color(0.30, 0.25, 0.20, 0.14), 2.2, true)
        if i % 3 == 0:
            draw_line(at - normal * 15, at - normal * 24 + Vector2(-3, -8), Color("#e5a75a"), 1.5, true)

func page_strip_points(u0: float, u1: float, amount: float) -> PackedVector2Array:
    var ease: float = (1.0 - cos(clampf(amount, 0, 1) * PI)) * 0.5
    var lift: float = sin(ease * PI) * size.y * 0.095
    var points := PackedVector2Array()
    for pair in [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]:
        var u: float = pair.x
        var bend: float = u * u
        var x: float = size.x * u - size.x * 0.12 * pow(u, 1.6) * ease - 24 * ease
        var y: float = lerpf(lift * bend + size.y * 0.065 * ease * bend, size.y - lift * bend * 0.4 + size.y * 0.035 * ease, pair.y)
        points.append(Vector2(x, y))
    return points

func _draw_page() -> void:
    var opacity: float = 1.0 - smoothstep(0.05, 0.98, progress)
    if previous == null: return
    for i in range(20):
        var u0: float = i / 20.0
        var u1: float = (i + 1) / 20.0
        var shade: float = 1 - sin(progress * PI) * u1 * 0.055
        draw_colored_polygon(page_strip_points(u0, u1, progress), Color(shade, shade, shade, opacity), PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]), previous)
    var edge := page_strip_points(0.97, 1, progress)
    var softness: float = sin(progress * PI) * opacity
    draw_colored_polygon(edge, Color(0.94, 0.88, 0.73, softness * 0.22))
    draw_line(edge[1], edge[2], Color(0.94, 0.87, 0.72, softness * 0.65), 2.5, true)

func _draw() -> void:
    if not active() or size.x < 4 or size.y < 4:
        return
    if effect == "burn":
        _draw_burn()
    elif effect == "page":
        _draw_page()
    elif effect == "fade":
        _full_old(pow(1.0 - progress, 2))
    else:
        _full_old(1.0 - smoothstep(0, 0.82, progress), Vector2(0, -12 * progress))
