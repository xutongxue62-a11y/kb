extends Control

var previous: Texture2D
var effect := "compose"
var progress := 1.0
var duration := 0.36
var going_back := false
var shard_rect := Rect2(52, 134, 1176, 520)
var shards: Array = []
var crumple_seed: float = 0.0
var crumple_spin_dir: float = 1.0
var crumple_drift_x: float = 22.0
const BURN_STEPS := 72
const PAPER_GRAIN: Texture2D = preload("res://assets/ui/paper_grain_v01.png")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS

func play(texture: Texture2D, mode: String = "compose") -> void:
    previous = texture
    effect = mode
    match mode:
        "burn":
            duration = 0.92
        "crumple_drop":
            duration = 0.68
            crumple_seed = randf_range(0.0, 100.0)
            crumple_spin_dir = 1.0 if randf() < 0.5 else -1.0
            crumple_drift_x = randf_range(-44.0, 44.0)
        "shard_assemble":
            duration = 0.56
        "shard_scatter":
            duration = 0.46
        "chronicle_enter":
            duration = 0.28
        "book_flip_next", "book_flip_prev":
            duration = 0.48
        "scroll_open":
            duration = 0.56
        "scroll_close":
            duration = 0.50
        "brush_sweep", "brush_back":
            duration = 0.44
        "page":
            duration = 0.52
        "fade":
            duration = 0.22
        _:
            duration = 0.28
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
    var radius: float = lerpf(-20.0, size.length() * 0.63, clampf(amount, 0.0, 1.0))
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

func _old_polygon(points: PackedVector2Array, alpha: float = 1.0, uv_override: PackedVector2Array = PackedVector2Array()) -> void:
    if points.size() < 3:
        return
    if previous == null:
        draw_colored_polygon(points, Color(0.94, 0.90, 0.80, alpha))
        return
    var uv: PackedVector2Array = uv_override
    if uv.size() != points.size():
        uv = PackedVector2Array()
        for point in points:
            uv.append(Vector2(clampf(point.x / size.x, 0.0, 1.0), clampf(point.y / size.y, 0.0, 1.0)))
    draw_colored_polygon(points, Color(1.0, 1.0, 1.0, alpha), uv, previous)

func _full_old(alpha: float = 1.0, offset: Vector2 = Vector2.ZERO) -> void:
    if previous != null:
        draw_texture_rect(previous, Rect2(offset, size), false, Color(1.0, 1.0, 1.0, alpha))

func flame_polygon(at: Vector2, normal: Vector2, length: float, curl: float) -> PackedVector2Array:
    var tangent: Vector2 = normal.orthogonal()
    var tip: Vector2 = at + normal * maxf(length, 19.0) + tangent * clampf(curl, -6.0, 6.0)
    return PackedVector2Array([
        at - tangent * 9.0,
        at + normal * 10.0 - tangent * 8.0,
        tip - tangent * 2.0,
        tip + normal * 4.0,
        at + normal * 9.0 + tangent * 8.0,
        at + tangent * 9.0
    ])

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
        var diff_edges: bool = absf(oa.x - ob.x) > 0.5 and absf(oa.y - ob.y) > 0.5
        if a_clipped and b_clipped and not diff_edges:
            continue
        var sector := PackedVector2Array([oa])
        if diff_edges:
            var oa_horiz: bool = oa.y <= 0.5 or oa.y >= size.y - 0.5
            var corner := Vector2(ob.x, oa.y) if oa_horiz else Vector2(oa.x, ob.y)
            if not (a_clipped and b_clipped and center.distance_to(corner) <= minf(center.distance_to(contour[i]), center.distance_to(contour[j]))):
                sector.append(corner)
            elif a_clipped and b_clipped:
                continue
        sector.append(ob)
        if not b_clipped:
            sector.append(ib)
        if not a_clipped:
            sector.append(ia)
        if sector.size() >= 3:
            _old_polygon(sector)
    var hot_line := PackedVector2Array()
    var glow_line := PackedVector2Array()
    for i in range(BURN_STEPS):
        var j: int = (i + 1) % BURN_STEPS
        var n: Vector2 = (contour[i] - center).normalized()
        var next_n: Vector2 = (contour[j] - center).normalized()
        var rough: float = 10.0 + sin(i * 2.83) * 5.0
        var rough_next: float = 10.0 + sin(j * 2.83) * 5.0
        var outer_a: Vector2 = contour[i] + n * rough
        var outer_b: Vector2 = contour[j] + next_n * rough_next
        var inner_a: Vector2 = contour[i] - n * 4.0
        var inner_b: Vector2 = contour[j] - next_n * 4.0
        draw_colored_polygon(PackedVector2Array([outer_a, outer_b, inner_b, inner_a]), Color("#3b2a20"))
        draw_line(contour[i] + n * 2.0, contour[j] + next_n * 2.0, Color("#a8552d"), 2.5, true)
        hot_line.append(inner_a)
        glow_line.append(contour[i] - n * 8.0)
        if i % 2 == 0:
            var tear: Vector2 = contour[i] + n * (rough + 12.0 + i % 4 * 3.0)
            draw_line(outer_a, tear, Color("#59402c"), 1.5, true)
    hot_line.append(hot_line[0])
    glow_line.append(glow_line[0])
    draw_polyline(glow_line, Color(0.95, 0.56, 0.18, 0.28), 7.0, true)
    draw_polyline(hot_line, Color("#f2c777"), 1.8, true)
    for i in range(48):
        var k: int = (i * 7 + 1) % BURN_STEPS
        var at: Vector2 = contour[k]
        var normal: Vector2 = (at - center).normalized()
        var tangent: Vector2 = normal.orthogonal()
        var flicker: float = 0.5 + 0.5 * sin(progress * 73.0 + i * 2.399)
        var length: float = 19.0 + pow(flicker, 1.6) * 62.0
        var curl: float = sin(progress * 41.0 + i * 1.7) * 6.0
        var tip: Vector2 = at + normal * length + tangent * curl
        draw_colored_polygon(flame_polygon(at, normal, length, curl), Color("#cd6d30"))
        draw_colored_polygon(flame_polygon(at + tangent * 2.0, normal, maxf(19.0, length * 0.65), -curl * 0.6), Color("#edac54"))
        draw_colored_polygon(PackedVector2Array([at - tangent * 4.0, at.lerp(tip, 0.53), at + normal * 7.0 + tangent * 4.0]), Color("#ffe3a3"))
        var life: float = fmod(i * 0.173 + progress * 2.3, 1.0)
        var ash: Vector2 = at - normal * (24.0 + life * 125.0) + tangent * sin(life * 5.0 + i) * 19.0 + Vector2(0.0, -life * life * 95.0)
        var spin: Vector2 = Vector2.from_angle(i + progress * 11.0) * (3.0 + i % 4)
        var across: Vector2 = spin.orthogonal() * 0.5
        draw_colored_polygon(PackedVector2Array([ash - spin, ash - across, ash + spin, ash + across]), Color(0.24, 0.18, 0.13, (1.0 - life) * 0.75))
        if i % 2 == 0:
            draw_colored_polygon(PackedVector2Array([ash - spin, ash - across, ash + spin * 0.4]), Color(0.89, 0.75, 0.53, (1.0 - life) * 0.85))
        var spark: Vector2 = at - normal * life * 54.0 + tangent * sin(i * 1.4 + progress * 9.0) * 14.0 + Vector2(0.0, -life * 58.0)
        draw_line(spark, spark + Vector2(-2.0, -4.0 - flicker * 6.0), Color(1.0, 0.75, 0.34, (1.0 - life) * 0.8), 1.3, true)
        if i % 4 == 0:
            var smoke := PackedVector2Array()
            for n in range(9):
                var rise: float = n / 8.0
                smoke.append(at - normal * (8.0 + rise * 25.0) + Vector2(sin(rise * 6.0 + progress * 12.0 + i) * rise * 13.0, -rise * 60.0))
            draw_polyline(smoke, Color(0.30, 0.25, 0.20, 0.14), 2.2, true)
        if i % 3 == 0:
            draw_line(at - normal * 15.0, at - normal * 24.0 + Vector2(-3.0, -8.0), Color("#e5a75a"), 1.5, true)

func _draw_scroll_roller(x_pos: float, alpha: float) -> void:
    if alpha <= 0.01:
        return
    var half_w: float = 11.5
    var cap_h: float = 28.0
    var top_y: float = 6.0
    var bot_y: float = size.y - 6.0
    # Cylindrical walnut wood rod body
    draw_rect(Rect2(x_pos - half_w, top_y + cap_h * 0.5, half_w * 2.0, (bot_y - top_y) - cap_h), Color(0.30, 0.19, 0.12, alpha))
    draw_rect(Rect2(x_pos - half_w + 3.0, top_y + cap_h * 0.5, half_w * 1.15, (bot_y - top_y) - cap_h), Color(0.46, 0.30, 0.18, alpha))
    draw_rect(Rect2(x_pos - half_w + 6.0, top_y + cap_h * 0.5, 4.0, (bot_y - top_y) - cap_h), Color(0.72, 0.53, 0.33, alpha * 0.75))
    draw_line(Vector2(x_pos - half_w, top_y + cap_h * 0.5), Vector2(x_pos - half_w, bot_y - cap_h * 0.5), Color(0.16, 0.10, 0.06, alpha), 2.0, true)
    draw_line(Vector2(x_pos + half_w, top_y + cap_h * 0.5), Vector2(x_pos + half_w, bot_y - cap_h * 0.5), Color(0.16, 0.10, 0.06, alpha), 2.0, true)
    # Leather & bronze strap rings along the scroll rod
    for frac in [0.16, 0.5, 0.84]:
        var ry: float = lerpf(top_y + cap_h, bot_y - cap_h, frac)
        draw_rect(Rect2(x_pos - half_w - 2.0, ry - 7.0, (half_w + 2.0) * 2.0, 14.0), Color(0.68, 0.44, 0.21, alpha))
        draw_rect(Rect2(x_pos - half_w - 2.0, ry - 2.5, (half_w + 2.0) * 2.0, 5.0), Color(0.89, 0.71, 0.41, alpha * 0.85))
        draw_rect(Rect2(x_pos - half_w - 2.0, ry - 7.0, (half_w + 2.0) * 2.0, 14.0), Color(0.18, 0.11, 0.07, alpha), false, 1.6)
    # Carved bone/ivory end-caps at top and bottom
    for cap_y in [top_y, bot_y - cap_h]:
        var cap_rect := Rect2(x_pos - half_w - 4.0, cap_y, (half_w + 4.0) * 2.0, cap_h)
        draw_rect(cap_rect, Color(0.89, 0.82, 0.68, alpha))
        draw_rect(Rect2(cap_rect.position.x + 4.0, cap_y + 3.0, 6.0, cap_h - 6.0), Color(0.98, 0.94, 0.85, alpha * 0.7))
        draw_rect(cap_rect, Color(0.20, 0.13, 0.08, alpha), false, 2.0)
        draw_line(Vector2(cap_rect.position.x + 2.0, cap_y + cap_h * 0.5), Vector2(cap_rect.end.x - 2.0, cap_y + cap_h * 0.5), Color(0.64, 0.34, 0.20, alpha * 0.85), 2.2, true)

func _draw_tribal_margin(x_edge: float, dir: float, alpha: float) -> void:
    # dir = -1.0 for left scroll (trim sits to the left of x_edge), +1.0 for right scroll
    if alpha <= 0.01:
        return
    var strip_x: float = x_edge + (dir * 16.0 if dir < 0.0 else 0.0)
    draw_rect(Rect2(strip_x, 0.0, 16.0, size.y), Color(0.89, 0.80, 0.63, alpha * 0.94))
    var inner_line_x: float = x_edge + dir * 16.0
    draw_line(Vector2(inner_line_x, 0.0), Vector2(inner_line_x, size.y), Color(0.29, 0.19, 0.12, alpha * 0.85), 2.0, true)
    # Repeating primitive chevron / diamond frieze
    var zig := PackedVector2Array()
    var step: float = 24.0
    var count: int = int(ceil(size.y / step)) + 1
    for i in range(count):
        var y: float = i * step
        var x_off: float = (4.5 if i % 2 == 0 else 11.5) * dir
        zig.append(Vector2(x_edge + x_off, y))
    if zig.size() >= 2:
        draw_polyline(zig, Color(0.66, 0.27, 0.16, alpha * 0.82), 2.0, true)

func _draw_scroll_open() -> void:
    # Epic twin-roller parchment scroll unfurling outward from the center!
    var ease_out: float = 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 3.0)
    var half_w: float = size.x * 0.5
    var left_x: float = lerpf(half_w, -36.0, ease_out)
    var right_x: float = lerpf(half_w, size.x + 36.0, ease_out)
    var edge_alpha: float = 1.0 - smoothstep(0.82, 1.0, progress)
    var shadow_alpha: float = sin(clampf(progress, 0.0, 1.0) * PI) * 0.42

    # Subtle warm parchment flash right as the scroll seam parts
    if progress < 0.35:
        var seam_glow: float = (1.0 - progress / 0.35) * 0.35
        var gap_w: float = maxf(6.0, right_x - left_x)
        draw_rect(Rect2(left_x, 0.0, gap_w, size.y), Color(0.95, 0.84, 0.58, seam_glow))

    # Left scroll panel sliding outward left
    if left_x > 0.0:
        var shift_l: float = half_w - left_x
        var u0_l: float = clampf(shift_l / size.x, 0.0, 0.5)
        var pts_l := PackedVector2Array([
            Vector2(0.0, 0.0),
            Vector2(left_x, 0.0),
            Vector2(left_x, size.y),
            Vector2(0.0, size.y)
        ])
        var uv_l := PackedVector2Array([
            Vector2(u0_l, 0.0),
            Vector2(0.5, 0.0),
            Vector2(0.5, 1.0),
            Vector2(u0_l, 1.0)
        ])
        _old_polygon(pts_l, 1.0, uv_l)
        # Cast drop shadow onto newly revealed screen on the right of left_x
        for s in range(4):
            var sw: float = 8.0 + s * 7.0
            draw_rect(Rect2(left_x + s * 6.0, 0.0, sw, size.y), Color(0.14, 0.09, 0.05, shadow_alpha * (1.0 - s * 0.24)))
        _draw_tribal_margin(left_x, -1.0, edge_alpha)

    # Right scroll panel sliding outward right
    if right_x < size.x:
        var shift_r: float = right_x - half_w
        var u1_r: float = clampf(1.0 - shift_r / size.x, 0.5, 1.0)
        var pts_r := PackedVector2Array([
            Vector2(right_x, 0.0),
            Vector2(size.x, 0.0),
            Vector2(size.x, size.y),
            Vector2(right_x, size.y)
        ])
        var uv_r := PackedVector2Array([
            Vector2(0.5, 0.0),
            Vector2(u1_r, 0.0),
            Vector2(u1_r, 1.0),
            Vector2(0.5, 1.0)
        ])
        _old_polygon(pts_r, 1.0, uv_r)
        # Cast drop shadow onto newly revealed screen on the left of right_x
        for s in range(4):
            var sw: float = 8.0 + s * 7.0
            draw_rect(Rect2(right_x - sw - s * 6.0, 0.0, sw, size.y), Color(0.14, 0.09, 0.05, shadow_alpha * (1.0 - s * 0.24)))
        _draw_tribal_margin(right_x, 1.0, edge_alpha)

    # Twin carved wooden & bone rollers
    if left_x > -30.0:
        _draw_scroll_roller(left_x, edge_alpha)
    if right_x < size.x + 30.0:
        _draw_scroll_roller(right_x, edge_alpha)

    # Golden ochre dust motes & parchment flecks drifting off the unfurling seam
    for i in range(20):
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var origin_x: float = left_x if side < 0.0 else right_x
        var seed_f: float = float(i) * 1.618
        var y_pos: float = fmod(seed_f * 237.0, size.y) + sin(progress * 9.0 + seed_f) * 14.0
        var drift: float = (16.0 + fmod(seed_f * 41.0, 44.0)) * progress
        var mote := Vector2(origin_x - side * drift, y_pos)
        var mote_alpha: float = sin(clampf(progress, 0.0, 1.0) * PI) * 0.78
        var r: float = 2.0 + float(i % 3) * 1.1
        draw_circle(mote, r, Color(0.92, 0.76, 0.44, mote_alpha))
        if i % 3 == 0:
            draw_line(mote, mote + Vector2(-side * 8.0, -3.0), Color(0.84, 0.56, 0.26, mote_alpha * 0.65), 1.3, true)

func _draw_scroll_close() -> void:
    # Distinct reverse transition: heavy ancient chronicle parchment page turning back right-to-left!
    var t: float = smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0))
    var tilt: float = sin(t * PI) * 92.0
    var spine_top_x: float = lerpf(size.x + 24.0, -size.x * 0.16, t) - tilt * 0.45
    var spine_bot_x: float = lerpf(size.x + 24.0, -size.x * 0.16, t) + tilt * 0.55
    var flap_w: float = sin(t * PI) * size.x * 0.23
    var curl_alpha: float = 1.0 - smoothstep(0.86, 1.0, progress)

    # Remaining flat old screen to the LEFT of the turning crease
    var top_clip: float = clampf(spine_top_x, 0.0, size.x)
    var bot_clip: float = clampf(spine_bot_x, 0.0, size.x)
    if top_clip > 0.5 or bot_clip > 0.5:
        var remain := PackedVector2Array([
            Vector2(0.0, 0.0),
            Vector2(top_clip, 0.0),
            Vector2(bot_clip, size.y),
            Vector2(0.0, size.y)
        ])
        _old_polygon(remain, 1.0)
        # Subtle crease shading along the left side of the fold
        var crease_w: float = 24.0 * sin(t * PI)
        if crease_w > 1.0:
            var crease_poly := PackedVector2Array([
                Vector2(maxf(0.0, top_clip - crease_w), 0.0),
                Vector2(top_clip, 0.0),
                Vector2(bot_clip, size.y),
                Vector2(maxf(0.0, bot_clip - crease_w), size.y)
            ])
            draw_colored_polygon(crease_poly, Color(0.20, 0.13, 0.07, 0.20 * curl_alpha))

    # Cast drop shadow falling rightward onto the newly revealed Title screen
    var shadow_w: float = 56.0 * sin(t * PI) + 14.0
    for s in range(4):
        var f0: float = float(s) / 4.0
        var f1: float = float(s + 1) / 4.0
        var sh_poly := PackedVector2Array([
            Vector2(spine_top_x + shadow_w * f0, 0.0),
            Vector2(spine_top_x + shadow_w * f1, 0.0),
            Vector2(spine_bot_x + shadow_w * f1, size.y),
            Vector2(spine_bot_x + shadow_w * f0, size.y)
        ])
        draw_colored_polygon(sh_poly, Color(0.10, 0.07, 0.04, (0.34 - s * 0.075) * curl_alpha))

    # Curled parchment underside (back face of the turned chronicle page)
    if flap_w > 2.0 and curl_alpha > 0.01:
        var edge_top := Vector2(spine_top_x - flap_w * 0.92, -10.0 * sin(t * PI))
        var edge_mid := Vector2((spine_top_x + spine_bot_x) * 0.5 - flap_w * 1.12, size.y * 0.5)
        var edge_bot := Vector2(spine_bot_x - flap_w * 0.86, size.y + 10.0 * sin(t * PI))
        var flap := PackedVector2Array([
            Vector2(spine_top_x, 0.0),
            edge_top,
            edge_mid,
            edge_bot,
            Vector2(spine_bot_x, size.y)
        ])
        draw_colored_polygon(flap, Color(0.91, 0.84, 0.68, 0.96 * curl_alpha))
        # Inner curved highlight band simulating paper thickness & cylindrical bend
        var hi := PackedVector2Array([
            Vector2(spine_top_x, 0.0),
            Vector2(spine_top_x - flap_w * 0.28, 0.0),
            Vector2(spine_bot_x - flap_w * 0.28, size.y),
            Vector2(spine_bot_x, size.y)
        ])
        draw_colored_polygon(hi, Color(0.76, 0.64, 0.45, 0.42 * curl_alpha))
        # Subtle ancient chronicle ink ruling lines on the parchment underside
        for r in range(1, 9):
            var frac: float = float(r) / 9.0
            var sy: float = size.y * frac
            var sx: float = lerpf(spine_top_x, spine_bot_x, frac)
            var ex: float = sx - flap_w * (0.72 + 0.22 * sin(frac * PI))
            draw_line(Vector2(sx - 10.0, sy), Vector2(ex + 10.0, sy), Color(0.45, 0.33, 0.20, 0.22 * curl_alpha), 1.4, true)
        # Crisp ink fold spine and deckle curled rim
        draw_line(Vector2(spine_top_x, 0.0), Vector2(spine_bot_x, size.y), Color(0.28, 0.19, 0.11, 0.78 * curl_alpha), 2.4, true)
        draw_polyline(PackedVector2Array([edge_top, edge_mid, edge_bot]), Color(0.42, 0.28, 0.16, 0.82 * curl_alpha), 2.2, true)
        draw_polyline(PackedVector2Array([edge_top + Vector2(3.0, 0.0), edge_mid + Vector2(3.0, 0.0), edge_bot + Vector2(3.0, 0.0)]), Color(0.98, 0.93, 0.80, 0.68 * curl_alpha), 1.6, true)

    # Trailing parchment & ochre flecks off the sweeping edge
    for i in range(12):
        var frac: float = (float(i) + 0.5) / 12.0
        var sy: float = size.y * frac + sin(progress * 11.0 + i * 1.9) * 12.0
        var sx: float = lerpf(spine_top_x, spine_bot_x, frac) + 18.0 + float(i % 3) * 16.0
        var speck_a: float = sin(t * PI) * 0.65
        draw_circle(Vector2(sx, sy), 2.2 + float(i % 2), Color(0.88, 0.72, 0.42, speck_a))

func _draw_brush_sweep(reverse: bool = false) -> void:
    # Dynamic primitive tribal ink-brush diagonal wipe (6 staggered dry-brush strokes)
    # reverse=false: sweeps left-to-right; reverse=true: sweeps right-to-left for return transitions!
    var bands: int = 6
    var band_h: float = size.y / float(bands)
    for b in range(bands):
        var order_idx: int = (bands - 1 - b) if reverse else b
        var stagger: float = float(order_idx) * 0.042 + (0.025 if order_idx % 2 == 1 else 0.0)
        var local_t: float = clampf((progress - stagger) / (1.0 - 0.26), 0.0, 1.0)
        var ease_t: float = 1.0 - pow(1.0 - local_t, 2.5)
        var y0: float = b * band_h
        var y1: float = minf(size.y, (b + 1) * band_h + 1.0)
        var skew: float = 38.0
        var brush_alpha: float = sin(clampf(local_t, 0.0, 1.0) * PI)
        var brush_w: float = 78.0 + float(b % 3) * 16.0

        if not reverse:
            var front_top: float = lerpf(-95.0, size.x + 125.0, ease_t)
            var front_bot: float = front_top - skew
            var clip_top: float = clampf(front_top, 0.0, size.x)
            var clip_bot: float = clampf(front_bot, 0.0, size.x)
            if clip_top < size.x - 0.5 or clip_bot < size.x - 0.5:
                _old_polygon(PackedVector2Array([
                    Vector2(clip_top, y0),
                    Vector2(size.x, y0),
                    Vector2(size.x, y1),
                    Vector2(clip_bot, y1)
                ]), 1.0)
            if brush_alpha > 0.02:
                draw_colored_polygon(PackedVector2Array([
                    Vector2(front_top - brush_w, y0 - 2.0),
                    Vector2(front_top + 16.0, y0 - 2.0),
                    Vector2(front_bot + 16.0, y1 + 2.0),
                    Vector2(front_bot - brush_w, y1 + 2.0)
                ]), Color(0.15, 0.11, 0.08, 0.90 * brush_alpha))
                draw_colored_polygon(PackedVector2Array([
                    Vector2(front_top - 16.0, y0),
                    Vector2(front_top + 20.0, y0),
                    Vector2(front_bot + 20.0, y1),
                    Vector2(front_bot - 16.0, y1)
                ]), Color(0.79, 0.42, 0.21, 0.76 * brush_alpha))
                for r in range(3):
                    var ry: float = lerpf(y0 + 10.0, y1 - 10.0, float(r) / 2.0)
                    var rx: float = lerpf(front_top, front_bot, float(r) / 2.0)
                    draw_line(Vector2(rx - brush_w * 0.85, ry), Vector2(rx + 28.0, ry), Color(0.94, 0.77, 0.44, 0.66 * brush_alpha), 2.3, true)
                var drop_pos := Vector2(front_top + 34.0 + float(b % 2) * 18.0, lerpf(y0, y1, 0.35 + 0.12 * float(b % 3)))
                draw_circle(drop_pos, 3.2, Color(0.20, 0.14, 0.10, 0.78 * brush_alpha))
                draw_circle(drop_pos + Vector2(14.0, 9.0), 2.1, Color(0.86, 0.52, 0.24, 0.72 * brush_alpha))
        else:
            var front_top: float = lerpf(size.x + 95.0, -125.0, ease_t)
            var front_bot: float = front_top + skew
            var clip_top: float = clampf(front_top, 0.0, size.x)
            var clip_bot: float = clampf(front_bot, 0.0, size.x)
            if clip_top > 0.5 or clip_bot > 0.5:
                _old_polygon(PackedVector2Array([
                    Vector2(0.0, y0),
                    Vector2(clip_top, y0),
                    Vector2(clip_bot, y1),
                    Vector2(0.0, y1)
                ]), 1.0)
            if brush_alpha > 0.02:
                draw_colored_polygon(PackedVector2Array([
                    Vector2(front_top - 16.0, y0 - 2.0),
                    Vector2(front_top + brush_w, y0 - 2.0),
                    Vector2(front_bot + brush_w, y1 + 2.0),
                    Vector2(front_bot - 16.0, y1 + 2.0)
                ]), Color(0.15, 0.11, 0.08, 0.90 * brush_alpha))
                draw_colored_polygon(PackedVector2Array([
                    Vector2(front_top - 20.0, y0),
                    Vector2(front_top + 16.0, y0),
                    Vector2(front_bot + 16.0, y1),
                    Vector2(front_bot - 20.0, y1)
                ]), Color(0.75, 0.45, 0.22, 0.76 * brush_alpha))
                for r in range(3):
                    var ry: float = lerpf(y0 + 10.0, y1 - 10.0, float(r) / 2.0)
                    var rx: float = lerpf(front_top, front_bot, float(r) / 2.0)
                    draw_line(Vector2(rx - 28.0, ry), Vector2(rx + brush_w * 0.85, ry), Color(0.94, 0.77, 0.44, 0.66 * brush_alpha), 2.3, true)
                var drop_pos := Vector2(front_top - 34.0 - float(b % 2) * 18.0, lerpf(y0, y1, 0.35 + 0.12 * float(b % 3)))
                draw_circle(drop_pos, 3.2, Color(0.20, 0.14, 0.10, 0.78 * brush_alpha))
                draw_circle(drop_pos + Vector2(-14.0, 9.0), 2.1, Color(0.86, 0.52, 0.24, 0.72 * brush_alpha))

func page_strip_points(u0: float, u1: float, amount: float) -> PackedVector2Array:
    var ease_v: float = (1.0 - cos(clampf(amount, 0.0, 1.0) * PI)) * 0.5
    var lift: float = sin(ease_v * PI) * size.y * 0.095
    var points := PackedVector2Array()
    for pair in [Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0)]:
        var u: float = pair.x
        var bend: float = u * u
        var x: float = size.x * u - size.x * 0.12 * pow(u, 1.6) * ease_v - 24.0 * ease_v
        var y: float = lerpf(lift * bend + size.y * 0.065 * ease_v * bend, size.y - lift * bend * 0.4 + size.y * 0.035 * ease_v, pair.y)
        points.append(Vector2(x, y))
    return points

func _draw_page() -> void:
    var opacity: float = 1.0 - smoothstep(0.05, 0.98, progress)
    if previous == null:
        return
    var edge := page_strip_points(0.97, 1.0, progress)
    var softness: float = sin(progress * PI) * opacity
    # Warm drop shadow cast behind the lifting parchment edge
    var shadow_poly := PackedVector2Array([
        edge[1],
        edge[1] + Vector2(36.0, 10.0),
        edge[2] + Vector2(36.0, 10.0),
        edge[2]
    ])
    draw_colored_polygon(shadow_poly, Color(0.12, 0.08, 0.04, softness * 0.34))
    for i in range(20):
        var u0: float = i / 20.0
        var u1: float = (i + 1) / 20.0
        var shade: float = 1.0 - sin(progress * PI) * u1 * 0.075
        draw_colored_polygon(
            page_strip_points(u0, u1, progress),
            Color(shade, shade * 0.98, shade * 0.94, opacity),
            PackedVector2Array([Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0)]),
            previous
        )
    draw_colored_polygon(edge, Color(0.94, 0.87, 0.71, softness * 0.35))
    draw_line(edge[1], edge[2], Color(0.46, 0.31, 0.17, softness * 0.72), 2.8, true)
    draw_line(edge[1] - Vector2(3.0, 0.0), edge[2] - Vector2(3.0, 0.0), Color(0.96, 0.89, 0.72, softness * 0.80), 1.8, true)

func _draw_fade() -> void:
    # Clean, silky backdrop dissolve (no intrusive full-screen stripes or tint flash)
    var alpha: float = pow(1.0 - clampf(progress, 0.0, 1.0), 1.8)
    _full_old(alpha)

func _draw_chronicle_enter() -> void:
    # Smooth backdrop dissolve while the cast parchment composes on top
    var alpha: float = pow(1.0 - clampf(progress, 0.0, 1.0), 1.7)
    _full_old(alpha)

func _clip_poly_halfplane(poly: PackedVector2Array, normal: Vector2, max_d: float, keep_less: bool) -> PackedVector2Array:
    var out := PackedVector2Array()
    var n: int = poly.size()
    if n < 3:
        return out
    for i in range(n):
        var a: Vector2 = poly[i]
        var b: Vector2 = poly[(i + 1) % n]
        var da: float = a.dot(normal) - max_d
        var db: float = b.dot(normal) - max_d
        var in_a: bool = (da <= 0.0) if keep_less else (da >= 0.0)
        var in_b: bool = (db <= 0.0) if keep_less else (db >= 0.0)
        if in_a:
            out.append(a)
        if in_a != in_b:
            var denom: float = da - db
            if absf(denom) > 0.00001:
                var frac: float = clampf(da / denom, 0.0, 1.0)
                out.append(a.lerp(b, frac))
    return out

func _draw_book_flip(forward: bool) -> void:
    # Clean diagonal storybook corner-peel page turn (ZERO dark border lines, ZERO rubber distortion):
    # Forward (>): bottom-right corner peels diagonally up-left across the entire sheet.
    # Backward (<): exact mirror — bottom-left corner peels diagonally up-right across the entire sheet.
    var t: float = smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0))
    var fade_end: float = 1.0 - smoothstep(0.92, 1.0, progress)
    if fade_end <= 0.01:
        return

    var rect_pts := PackedVector2Array([
        Vector2(0.0, 0.0),
        Vector2(size.x, 0.0),
        Vector2(size.x, size.y),
        Vector2(0.0, size.y)
    ])
    # Diagonal axis pointing toward the starting peel corner (bottom-right for next, bottom-left for prev)
    var axis: Vector2 = Vector2(0.84, 0.54).normalized() if forward else Vector2(-0.84, 0.54).normalized()
    var min_d: float = INF
    var max_d: float = -INF
    for p in rect_pts:
        var d: float = p.dot(axis)
        min_d = minf(min_d, d)
        max_d = maxf(max_d, d)
    var fold_d: float = lerpf(max_d, min_d - 24.0, t)

    # 1. Undistorted remaining old character page (on the un-peeled side: p.dot(axis) <= fold_d)
    var keep_poly: PackedVector2Array = _clip_poly_halfplane(rect_pts, axis, fold_d, true)
    if keep_poly.size() >= 3:
        _old_polygon(keep_poly, fade_end)

    # 2. Peeled corner polygon (p.dot(axis) >= fold_d) mirrored across the fold line to form the curled page back!
    var peeled_poly: PackedVector2Array = _clip_poly_halfplane(rect_pts, axis, fold_d, false)
    if peeled_poly.size() < 3:
        return

    # Find exact fold crease endpoints along the rectangle boundary
    var crease_pts := PackedVector2Array()
    for p in peeled_poly:
        if absf(p.dot(axis) - fold_d) < 1.2:
            crease_pts.append(p)
    var fold_a: Vector2 = crease_pts[0] if crease_pts.size() >= 1 else peeled_poly[0]
    var fold_b: Vector2 = crease_pts[crease_pts.size() - 1] if crease_pts.size() >= 2 else peeled_poly[1]

    # 3. Soft feathered cast drop shadow falling onto the newly uncovered character page
    var arc: float = sin(t * PI)
    var sh_len: float = 52.0 * arc + 8.0
    if crease_pts.size() >= 2:
        for s in range(4):
            var s0: float = float(s) / 4.0
            var s1: float = float(s + 1) / 4.0
            var sh_poly := PackedVector2Array([
                fold_a + axis * (sh_len * s0),
                fold_a + axis * (sh_len * s1),
                fold_b + axis * (sh_len * s1),
                fold_b + axis * (sh_len * s0)
            ])
            draw_colored_polygon(sh_poly, Color(0.11, 0.08, 0.04, (0.24 - s * 0.055) * fade_end))

    # 4. Curled parchment back-face (mirrored across fold line with gentle 3D curve foreshortening)
    var curl_poly := PackedVector2Array()
    var curl_uv := PackedVector2Array()
    var curl_sh := PackedVector2Array()
    for p in peeled_poly:
        var dist: float = maxf(0.0, p.dot(axis) - fold_d)
        # Mirror across fold line & foreshorten slightly so it reads as a soft curved parchment curl
        var mirrored: Vector2 = p - axis * (dist * 1.78)
        curl_poly.append(mirrored)
        curl_sh.append(mirrored + Vector2(3.0, 5.0) * arc)
        curl_uv.append(Vector2(clampf(p.x / size.x, 0.0, 1.0), clampf(p.y / size.y, 0.0, 1.0)))
    # Reverse winding since reflection flips polygon orientation
    curl_poly.reverse()
    curl_uv.reverse()
    curl_sh.reverse()

    # Soft shadow cast by the curled flap onto the old page behind it
    draw_colored_polygon(curl_sh, Color(0.14, 0.10, 0.05, 0.16 * arc * fade_end))
    # Warm aged parchment underside textured with real PAPER_GRAIN (NO harsh borders!)
    draw_colored_polygon(curl_poly, Color(0.95, 0.89, 0.76, 0.98 * fade_end), curl_uv, PAPER_GRAIN)

    # 5. Subtle cylindrical highlight & soft trough shading right along the curved fold crest
    if crease_pts.size() >= 2:
        var crest_w: float = minf(34.0, 12.0 + 24.0 * arc)
        draw_colored_polygon(PackedVector2Array([
            fold_a,
            fold_a - axis * crest_w,
            fold_b - axis * crest_w,
            fold_b
        ]), Color(0.76, 0.65, 0.48, 0.24 * fade_end))
        draw_line(fold_a - axis * (crest_w * 0.35), fold_b - axis * (crest_w * 0.35), Color(1.0, 0.97, 0.88, 0.45 * arc * fade_end), 4.0, true)

func play_shards(texture: Texture2D, target_rect: Rect2, mode: String = "shard_assemble") -> void:
    shard_rect = target_rect
    _build_jigsaw_shards(target_rect)
    play(texture, mode)

func _hash_f(seed_val: float) -> float:
    return fposmod(sin(seed_val * 127.1 + 311.7) * 43758.5453, 1.0)

func _append_shard(pts: PackedVector2Array, rect_size: Vector2, idx: int) -> void:
    if pts.size() < 3:
        return
    var centroid := Vector2.ZERO
    for p in pts:
        centroid += p
    centroid /= float(pts.size())
    var local_pts := PackedVector2Array()
    var uvs := PackedVector2Array()
    for p in pts:
        local_pts.append(p - centroid)
        uvs.append(Vector2(clampf(p.x / rect_size.x, 0.0, 1.0), clampf(p.y / rect_size.y, 0.0, 1.0)))
    var sheet_center := rect_size * 0.5
    var radial: Vector2 = centroid - sheet_center
    if radial.length_squared() < 16.0:
        radial = Vector2.from_angle(_hash_f(float(idx) * 3.17) * TAU)
    else:
        radial = radial.normalized()
    var angle_jitter: float = (_hash_f(float(idx) * 7.13) - 0.5) * 0.95
    var dir: Vector2 = radial.rotated(angle_jitter)
    var dist_norm: float = clampf(centroid.distance_to(sheet_center) / (rect_size.length() * 0.5), 0.0, 1.0)
    var fly_dist: float = lerpf(240.0, 560.0, _hash_f(float(idx) * 11.41)) * (0.72 + dist_norm * 0.45)
    var scatter_rot: float = (_hash_f(float(idx) * 19.73) - 0.5) * 2.5
    var scatter_scale: float = lerpf(0.68, 1.12, _hash_f(float(idx) * 23.19))
    var stagger: float = _hash_f(float(idx) * 5.89) * 0.22
    var tone: float = lerpf(0.95, 1.03, _hash_f(float(idx) * 29.31))
    shards.append({
        "local_pts": local_pts,
        "uvs": uvs,
        "centroid": centroid,
        "offset": dir * fly_dist,
        "rot": scatter_rot,
        "scale": scatter_scale,
        "stagger": stagger,
        "tone": tone
    })

func _torn_edge(a: Vector2, b: Vector2, key: int, reverse: bool = false, is_outer: bool = false) -> PackedVector2Array:
    var pts := PackedVector2Array()
    var dir: Vector2 = b - a
    var len_v: float = dir.length()
    if len_v < 4.0:
        return pts
    var normal: Vector2 = Vector2(-dir.y, dir.x) / len_v
    var tangent: Vector2 = dir / len_v
    var segs: int = 4
    var amp: float = minf(5.0, len_v * 0.05) if is_outer else minf(18.0, len_v * 0.17)
    for s in range(1, segs):
        var f: float = float(s) / float(segs)
        var jn: float = (_hash_f(float(key * 17 + s * 31)) - 0.5) * 2.0 * amp
        var jt: float = (_hash_f(float(key * 23 + s * 19)) - 0.5) * (len_v * 0.08)
        pts.append(a.lerp(b, f) + normal * jn + tangent * jt)
    if reverse:
        pts.reverse()
    return pts

func _append_torn_chain(out: PackedVector2Array, a: Vector2, b: Vector2, id_a: int, id_b: int, is_outer: bool = false) -> void:
    out.append(a)
    var lo: int = mini(id_a, id_b)
    var hi: int = maxi(id_a, id_b)
    var key: int = lo * 97 + hi * 13 + 7
    var rev: bool = id_a > id_b
    var p0: Vector2 = a if not rev else b
    var p1: Vector2 = b if not rev else a
    var mids: PackedVector2Array = _torn_edge(p0, p1, key, rev, is_outer)
    for m in mids:
        out.append(m)

func _build_jigsaw_shards(rect: Rect2) -> void:
    shards.clear()
    var cols: int = 8
    var rows: int = 5
    var cw: float = rect.size.x / float(cols)
    var ch: float = rect.size.y / float(rows)
    var grid: Array = []
    var stride: int = cols + 1
    for r in range(rows + 1):
        var row_pts: Array = []
        for c in range(cols + 1):
            var x: float = float(c) * cw
            var y: float = float(r) * ch
            var h1: float = _hash_f(float(r * 13 + c * 7 + 1)) - 0.5
            var h2: float = _hash_f(float(r * 17 + c * 11 + 3)) - 0.5
            if c > 0 and c < cols:
                x += h1 * cw * 0.52
            if r > 0 and r < rows:
                y += h2 * ch * 0.52
            row_pts.append(Vector2(x, y))
        grid.append(row_pts)
    var idx: int = 0
    for r in range(rows):
        for c in range(cols):
            var id00: int = r * stride + c
            var id10: int = r * stride + (c + 1)
            var id11: int = (r + 1) * stride + (c + 1)
            var id01: int = (r + 1) * stride + c
            var p00: Vector2 = grid[r][c]
            var p10: Vector2 = grid[r][c + 1]
            var p11: Vector2 = grid[r + 1][c + 1]
            var p01: Vector2 = grid[r + 1][c]
            var top_out: bool = r == 0
            var bot_out: bool = r == rows - 1
            var left_out: bool = c == 0
            var right_out: bool = c == cols - 1
            var kind_h: float = _hash_f(float(r * 19 + c * 31 + 5))
            if kind_h < 0.44:
                # Large/medium irregular crooked 4-sided torn parchment chunk (16 vertices)
                var poly := PackedVector2Array()
                _append_torn_chain(poly, p00, p10, id00, id10, top_out)
                _append_torn_chain(poly, p10, p11, id10, id11, right_out)
                _append_torn_chain(poly, p11, p01, id11, id01, bot_out)
                _append_torn_chain(poly, p01, p00, id01, id00, left_out)
                _append_shard(poly, rect.size, idx)
                idx += 1
            elif kind_h < 0.72:
                # Split vertically along a crooked tear seam into two varied irregular scraps
                var t_top: float = lerpf(0.32, 0.68, _hash_f(float(r * 41 + c * 17 + 9)))
                var t_bot: float = lerpf(0.32, 0.68, _hash_f(float(r * 43 + c * 23 + 11)))
                var m_top: Vector2 = p00.lerp(p10, t_top)
                var m_bot: Vector2 = p01.lerp(p11, t_bot)
                var id_mt: int = 1000 + (r * stride + c) * 2
                var id_mb: int = 2000 + (r * stride + c) * 2
                var left_poly := PackedVector2Array()
                _append_torn_chain(left_poly, p00, m_top, id00, id_mt, top_out)
                _append_torn_chain(left_poly, m_top, m_bot, id_mt, id_mb, false)
                _append_torn_chain(left_poly, m_bot, p01, id_mb, id01, bot_out)
                _append_torn_chain(left_poly, p01, p00, id01, id00, left_out)
                _append_shard(left_poly, rect.size, idx)
                idx += 1
                var right_poly := PackedVector2Array()
                _append_torn_chain(right_poly, m_top, p10, id_mt, id10, top_out)
                _append_torn_chain(right_poly, p10, p11, id10, id11, right_out)
                _append_torn_chain(right_poly, p11, m_bot, id11, id_mb, bot_out)
                _append_torn_chain(right_poly, m_bot, m_top, id_mb, id_mt, false)
                _append_shard(right_poly, rect.size, idx)
                idx += 1
            else:
                # Split horizontally along a crooked tear seam into two varied irregular scraps
                var t_l: float = lerpf(0.32, 0.68, _hash_f(float(r * 53 + c * 29 + 13)))
                var t_r: float = lerpf(0.32, 0.68, _hash_f(float(r * 59 + c * 37 + 15)))
                var m_l: Vector2 = p00.lerp(p01, t_l)
                var m_r: Vector2 = p10.lerp(p11, t_r)
                var id_ml: int = 3000 + (r * stride + c) * 2
                var id_mr: int = 4000 + (r * stride + c) * 2
                var top_poly := PackedVector2Array()
                _append_torn_chain(top_poly, p00, p10, id00, id10, top_out)
                _append_torn_chain(top_poly, p10, m_r, id10, id_mr, right_out)
                _append_torn_chain(top_poly, m_r, m_l, id_mr, id_ml, false)
                _append_torn_chain(top_poly, m_l, p00, id_ml, id00, left_out)
                _append_shard(top_poly, rect.size, idx)
                idx += 1
                var bot_poly := PackedVector2Array()
                _append_torn_chain(bot_poly, m_l, m_r, id_ml, id_mr, false)
                _append_torn_chain(bot_poly, m_r, p11, id_mr, id11, right_out)
                _append_torn_chain(bot_poly, p11, p01, id11, id01, bot_out)
                _append_torn_chain(bot_poly, p01, m_l, id01, id_ml, left_out)
                _append_shard(bot_poly, rect.size, idx)
                idx += 1

func _draw_shards(assembling: bool) -> void:
    if shards.is_empty():
        _build_jigsaw_shards(shard_rect)
    var tex: Texture2D = previous if (not assembling and previous != null) else PAPER_GRAIN
    var layer_fade: float = 1.0 - smoothstep(0.76, 1.0, progress) if assembling else 1.0
    if layer_fade <= 0.005:
        return
    for i in range(shards.size()):
        var sh: Dictionary = shards[i]
        var stagger: float = float(sh["stagger"])
        var local_t: float = clampf((progress - stagger) / (1.0 - stagger), 0.0, 1.0)
        var pos_factor: float
        var alpha: float
        if assembling:
            # 0.0 = scattered across screen, 1.0 = locked into exact jigsaw position
            pos_factor = 1.0 - pow(1.0 - local_t, 3.0)
            alpha = smoothstep(0.0, 0.22, local_t) * layer_fade
        else:
            # 1.0 = locked on sheet, 0.0 = scattered outward across screen
            pos_factor = 1.0 - pow(local_t, 1.75)
            alpha = (1.0 - smoothstep(0.42, 1.0, local_t))
        if alpha <= 0.01:
            continue
        var inv: float = 1.0 - pos_factor
        var center: Vector2 = shard_rect.position + sh["centroid"] + sh["offset"] * inv
        var angle: float = float(sh["rot"]) * inv
        var sc: float = lerpf(float(sh["scale"]), 1.0, pos_factor)
        var local_pts: PackedVector2Array = sh["local_pts"]
        var world_pts := PackedVector2Array()
        var shadow_pts := PackedVector2Array()
        var shadow_off := Vector2(4.0 + inv * 10.0, 6.0 + inv * 14.0)
        for lp in local_pts:
            var wp: Vector2 = center + (lp * sc).rotated(angle)
            world_pts.append(wp)
            shadow_pts.append(wp + shadow_off)
        # Soft floating drop-shadow underneath each flying parchment shard
        draw_colored_polygon(shadow_pts, Color(0.06, 0.04, 0.02, (0.14 + inv * 0.18) * alpha))
        # Textured parchment shard body
        var tone: float = lerpf(float(sh["tone"]), 1.0, pos_factor)
        var tint: Color = Color(tone, tone * 0.985, tone * 0.95, alpha) if assembling else Color(1.0, 1.0, 1.0, alpha)
        draw_colored_polygon(world_pts, tint, sh["uvs"], tex)
        # Crisp torn-paper ink rim that dissolves away as the puzzle snaps together
        var rim_a: float = (0.52 * (1.0 - smoothstep(0.75, 1.0, pos_factor)) + 0.10) * alpha if assembling else (0.18 + 0.45 * inv) * alpha
        if rim_a > 0.02:
            var closed := PackedVector2Array(world_pts)
            closed.append(world_pts[0])
            draw_polyline(closed, Color(0.28, 0.19, 0.11, rim_a), 1.4, true)
        # Subtle warm paper-dust speck trailing off flying shards
        if inv > 0.15 and i % 3 == 0:
            var speck_pos: Vector2 = center + sh["offset"].normalized() * (14.0 + inv * 24.0)
            draw_circle(speck_pos, 2.0, Color(0.93, 0.80, 0.52, inv * 0.55 * alpha))

func _draw_crumple_drop() -> void:
    # Continuous 10x6 deformable paper-cloth crumple & gravity drop:
    # Outer edges/corners gather and buckle inward first into a naturally shaded crumpled wad (ZERO origami triangles,
    # ZERO hard stage-cut pops!), then drop briskly off the bottom of the screen.
    var t: float = clampf(progress, 0.0, 1.0)
    var alpha: float = 1.0 - smoothstep(0.88, 1.0, t)
    if alpha <= 0.01:
        return

    var crumple_end: float = 0.62
    var drop_t: float = clampf((t - crumple_end) / (1.0 - crumple_end), 0.0, 1.0)
    var hop_y: float = -sin(minf(drop_t * 3.0, 1.0) * PI) * 9.0 if drop_t > 0.0 else 0.0
    var fall_off := Vector2(drop_t * crumple_drift_x, drop_t * drop_t * (size.y * 0.86) + hop_y)
    var base_center: Vector2 = size * Vector2(0.50, 0.48)
    var center: Vector2 = base_center + fall_off
    var global_c: float = smoothstep(0.0, 1.0, clampf(t / crumple_end, 0.0, 1.0))
    var spin: float = (global_c * 0.28 + drop_t * 1.55) * crumple_spin_dir
    var ph1: float = crumple_seed * 1.37
    var ph2: float = crumple_seed * 2.13
    var ph3: float = crumple_seed * 0.79

    var cols: int = 10
    var rows: int = 6
    var ball_r: float = 78.0
    var grid_pos: Array = []
    var grid_h: Array = []

    # 1. Compute strongly buckled 10x6 vertex positions & deep organic wrinkle heights (randomized every run!)
    for r in range(rows + 1):
        var v: float = float(r) / float(rows)
        var row_p: Array = []
        var row_h: Array = []
        for c_i in range(cols + 1):
            var u: float = float(c_i) / float(cols)
            var orig := Vector2(u * size.x, v * size.y)
            var rel: Vector2 = orig - base_center
            # Outer edges & corners pull & fold inward FIRST, with slight per-corner random stagger
            var edge_w: float = maxf(absf(u - 0.5) * 2.0, absf(v - 0.5) * 2.0)
            var corner_bias: float = (sin(u * 3.1 + ph3) * cos(v * 2.9 + ph1)) * 0.04
            var delay: float = clampf((1.0 - edge_w) * 0.18 + corner_bias, 0.0, 0.22)
            var lc: float = smoothstep(0.0, 1.0, clampf((t - delay) / (crumple_end - delay), 0.0, 1.0))
            var h_val: float = sin(u * 12.6 + v * 5.8 + ph1) * 0.58 + cos(v * 10.4 - u * 7.1 + ph2) * 0.42
            var buckle_x: float = sin(v * 11.2 + u * 5.3 + ph2) * 58.0 + cos(u * 14.1 - v * 4.2 + ph1) * 28.0
            var buckle_y: float = cos(u * 10.3 + v * 6.7 + ph1) * 48.0 + sin(v * 12.9 + u * 5.9 + ph3) * 24.0
            var buckle_amp: float = sin(lc * PI * 0.86) * (0.42 + 0.58 * edge_w)

            # Target position inside the crumpled paper wad (unique irregular bumpy silhouette each time)
            var radial_dir: Vector2 = rel.normalized() if rel.length_squared() > 1.0 else Vector2.RIGHT
            var radial_frac: float = clampf(rel.length() / (size.length() * 0.5), 0.0, 1.0)
            var ang: float = radial_dir.angle()
            var lobe: float = 1.0 + 0.28 * sin(ang * 3.0 + ph1) + 0.18 * cos(ang * 5.0 + ph2) + 0.10 * sin(ang * 7.0 + ph3)
            var target_rel: Vector2 = radial_dir * (ball_r * pow(radial_frac, 0.74) * lobe) + Vector2(h_val * 16.0, -h_val * 14.0)
            var cur_rel: Vector2 = rel.lerp(target_rel, lc) + Vector2(buckle_x, buckle_y) * buckle_amp
            var final_pt: Vector2 = center + cur_rel.rotated(spin * lc)
            row_p.append(final_pt)
            row_h.append(h_val * lc)
        grid_pos.append(row_p)
        grid_h.append(row_h)

    # 2. Exact perimeter polygon of the crumpled paper (used for organic silhouette shadow & rim — ZERO round circle!)
    var perimeter := PackedVector2Array()
    for c_i in range(cols):
        perimeter.append(grid_pos[0][c_i])
    for r in range(rows):
        perimeter.append(grid_pos[r][cols])
    for c_i in range(cols, 0, -1):
        perimeter.append(grid_pos[rows][c_i])
    for r in range(rows, 0, -1):
        perimeter.append(grid_pos[r][0])

    if global_c > 0.08:
        var sh_off := Vector2(8.0 * global_c, 12.0 * global_c + drop_t * 14.0)
        var sh_poly := PackedVector2Array()
        for pt in perimeter:
            sh_poly.append(pt + sh_off)
        draw_colored_polygon(sh_poly, Color(0.06, 0.04, 0.02, 0.26 * global_c * alpha))

    # 3. Draw every quad with bold high-contrast crumpled ridge/valley lighting
    var paper_blend: float = smoothstep(0.14, 0.80, global_c) * 0.88
    for r in range(rows):
        var v0: float = float(r) / float(rows)
        var v1: float = float(r + 1) / float(rows)
        for c_i in range(cols):
            var u0: float = float(c_i) / float(cols)
            var u1: float = float(c_i + 1) / float(cols)
            var p00: Vector2 = grid_pos[r][c_i]
            var p10: Vector2 = grid_pos[r][c_i + 1]
            var p11: Vector2 = grid_pos[r + 1][c_i + 1]
            var p01: Vector2 = grid_pos[r + 1][c_i]
            var poly := PackedVector2Array([p00, p10, p11, p01])
            var uv := PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])
            var dh_x: float = (float(grid_h[r][c_i + 1]) + float(grid_h[r + 1][c_i + 1])) - (float(grid_h[r][c_i]) + float(grid_h[r + 1][c_i]))
            var dh_y: float = (float(grid_h[r + 1][c_i]) + float(grid_h[r + 1][c_i + 1])) - (float(grid_h[r][c_i]) + float(grid_h[r][c_i + 1]))
            var shade: float = clampf(0.92 - (dh_x * 0.34 + dh_y * 0.38), 0.44, 1.15)
            if previous != null:
                draw_colored_polygon(poly, Color(shade, shade * 0.98, shade * 0.94, alpha), uv, previous)
            if paper_blend > 0.01:
                draw_colored_polygon(poly, Color(0.94 * shade, 0.86 * shade, 0.70 * shade, paper_blend * alpha), uv, PAPER_GRAIN)
            # Crisp hand-inked crease lines along steep paper fold valleys
            var steepness: float = absf(dh_x) + absf(dh_y)
            if steepness > 0.48 and global_c > 0.16:
                var cr_a: float = clampf((steepness - 0.48) * 0.72, 0.0, 0.65) * global_c * alpha
                draw_line(p00, p11, Color(0.24, 0.16, 0.09, cr_a), 1.6, true)

    # 4. Hand-drawn bumpy outer silhouette rim appearing as the sheet crumples into a wad
    if global_c > 0.20:
        var rim_a: float = smoothstep(0.20, 0.72, global_c) * 0.78 * alpha
        var closed_perim := PackedVector2Array(perimeter)
        closed_perim.append(perimeter[0])
        draw_polyline(closed_perim, Color(0.24, 0.16, 0.09, rim_a), 2.1, true)

func _draw() -> void:
    if not active() or size.x < 4 or size.y < 4:
        return
    match effect:
        "burn":
            _draw_burn()
        "crumple_drop":
            _draw_crumple_drop()
        "shard_assemble":
            _draw_shards(true)
        "shard_scatter":
            _draw_shards(false)
        "chronicle_enter":
            _draw_chronicle_enter()
        "book_flip_next":
            _draw_book_flip(true)
        "book_flip_prev":
            _draw_book_flip(false)
        "scroll_open":
            _draw_scroll_open()
        "scroll_close":
            _draw_scroll_close()
        "brush_sweep":
            _draw_brush_sweep(false)
        "brush_back":
            _draw_brush_sweep(true)
        "page":
            _draw_page()
        "fade":
            _draw_fade()
        _:
            _full_old(1.0 - smoothstep(0.0, 0.82, progress), Vector2(0.0, -12.0 * progress))
