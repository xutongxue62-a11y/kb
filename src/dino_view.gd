extends Node2D

var sprite: Sprite2D
var surface: Sprite2D
var base_scale: Vector2
var kind: String
var walk_time: float = 0.0
var hit_time: float = 0.0
var health_fraction: float = 1.0
var elite: bool = false:
    set(value):
        elite = value
        _update_outline()
        queue_redraw()
var asset_library
var display_width: float = 60.0
var shell: String = ""
var crack_progress: float = 0.0

func setup(library, creature_kind: String, size: float, is_elite: bool) -> void:
    asset_library = library
    kind = creature_kind
    elite = is_elite
    sprite = Sprite2D.new()
    sprite.texture = library.texture("dinosaurs", kind)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    # Padding enlarges only the draw quad. Body scale, origin and combat radius
    # continue to use the original region so silhouettes do not shrink.
    var dimensions: Vector2 = library.region("dinosaurs", kind).size
    base_scale = Vector2.ONE * size / maxf(dimensions.x, dimensions.y)
    _update_outline()
    sprite.scale = base_scale
    display_width = size
    add_child(sprite)
    surface=Sprite2D.new()
    surface.name="SurfaceArt"
    surface.texture=library.EnemyArt.surface_texture(kind,dimensions)
    surface.material=library.EnemyArt.surface_material(sprite.texture)
    sprite.add_child(surface)
    set_shell(shell)

func _update_outline() -> void:
    if sprite != null and asset_library != null:
        sprite.material = asset_library.team_material("dinosaurs", kind, "elite" if elite else "enemy", (2.2 if elite else 1.2) / base_scale.x)

func set_crack(progress: float) -> void:
    crack_progress = clampf(progress, 0.0, 1.0)
    queue_redraw()

func set_shell(mode: String) -> void:
    shell = mode
    if mode != "egg":
        crack_progress = 0.0
    if sprite != null:
        sprite.visible = mode != "egg"
    queue_redraw()

func animate(velocity: Vector2, delta: float, state: String = "walk") -> void:
    hit_time = maxf(hit_time - delta, 0.0)
    if shell == "egg":
        walk_time += delta * 2.2
        queue_redraw()
        return
    if absf(velocity.x) > 3.0:
        sprite.flip_h = velocity.x > 0.0 if kind == "tank" else velocity.x < 0.0
    if surface!=null: surface.flip_h=sprite.flip_h
    walk_time += velocity.length() * delta * 0.065
    var amount: float = clampf(velocity.length() / 90.0, 0.0, 1.0)
    var squash: float = sin(walk_time) * 0.035 * amount
    if state == "windup":
        squash = 0.13
    elif state == "recover":
        squash = 0.07
    if hit_time > 0.0:
        squash += hit_time * 0.5
    sprite.scale = base_scale * Vector2(1.0 + squash, 1.0 - squash)
    sprite.position.y = -absf(sin(walk_time)) * 1.3 * amount
    sprite.rotation = sin(walk_time) * 0.022 * amount
    sprite.modulate = Color(2.2, 2.0, 1.8) if hit_time > 0.13 else Color.WHITE
    queue_redraw()

func hit() -> void:
    hit_time = 0.2

func _draw_egg() -> void:
    var amount: float = crack_progress
    var bob: float = sin(walk_time) * (1.4 + 1.8 * amount)
    var radius: float = maxf(16.0, display_width * 0.42)
    var origin: Vector2 = Vector2(0.0, 4.0 + bob) + Vector2(sin(walk_time * 31.0), cos(walk_time * 27.0)) * (1.8 * amount)
    var pts: PackedVector2Array = PackedVector2Array()
    for index in range(24):
        var angle: float = -PI * 0.5 + TAU * float(index) / 24.0
        var oval: Vector2 = Vector2(cos(angle) * radius * 0.78, sin(angle) * radius * 1.05)
        if oval.y < 0.0:
            oval.y *= 1.12
        pts.append(origin + oval)
    if elite:
        var edge: PackedVector2Array = pts.duplicate()
        edge.append(pts[0])
        draw_polyline(edge, Color("#e31b28"), 5.0, true)
    draw_colored_polygon(pts, Color("#3a2c22"))
    var inner: PackedVector2Array = PackedVector2Array()
    for point in pts:
        inner.append(origin + (point - origin) * 0.88)
    draw_colored_polygon(inner, Color("#f3e0b8"))
    draw_colored_polygon(_egg_highlight(origin, radius), Color("#fff6df", 0.7))
    for spot in [Vector2(-7, -4), Vector2(6, 3), Vector2(-2, 8), Vector2(8, -7), Vector2(-8, 4)]:
        var color: Color = Color("#c45b3a") if int(absf(spot.x) + absf(spot.y)) % 2 == 0 else Color("#6d7f55")
        draw_circle(origin + spot * (radius / 16.0), maxf(2.2, radius * 0.13), color)
        draw_circle(origin + spot * (radius / 16.0) + Vector2(-0.6, -0.6), maxf(0.8, radius * 0.05), Color("#fff6df", 0.45))
    if amount > 0.0:
        _draw_egg_cracks(origin, radius, amount)

func _draw_egg_cracks(origin: Vector2, radius: float, amount: float) -> void:
    var ink: Color = Color("#2a1c14", 0.55 + 0.45 * amount)
    var glow: Color = Color("#fff1c8", 0.4 + 0.5 * amount)
    var paths: Array = [
        [Vector2(0.0, -1.05), Vector2(-0.08, -0.55), Vector2(0.12, -0.15), Vector2(-0.06, 0.35), Vector2(0.04, 0.9)],
        [Vector2(-0.08, -0.55), Vector2(-0.42, -0.22), Vector2(-0.58, 0.08)],
        [Vector2(0.12, -0.15), Vector2(0.4, 0.08), Vector2(0.52, 0.42)]
    ]
    var shown: int = 1 + int(floor(amount * 2.15))
    for index in range(mini(shown, paths.size())):
        var pts: PackedVector2Array = PackedVector2Array()
        for point in paths[index]:
            pts.append(origin + Vector2(point.x, point.y) * radius)
        draw_polyline(pts, glow, 3.4 + amount * 2.4, true)
        draw_polyline(pts, ink, 1.6 + amount * 1.5, true)
    if amount > 0.4:
        var open: float = (amount - 0.4) / 0.6
        var top: Vector2 = origin + Vector2(0.0, -radius * 0.72)
        var left: Vector2 = top + Vector2(-2.4 - 5.0 * open, 2.0)
        var right: Vector2 = top + Vector2(2.4 + 5.0 * open, 2.0)
        draw_colored_polygon(PackedVector2Array([top, right, left]), Color("#5a3d2a", 0.35 + 0.4 * open))
        draw_line(top, left, ink, 1.4, true)
        draw_line(top, right, ink, 1.4, true)
        draw_line(left, right, Color("#fff4d6", 0.35 + 0.4 * open), 1.2, true)

func _egg_highlight(origin: Vector2, radius: float) -> PackedVector2Array:
    var pts: PackedVector2Array = PackedVector2Array()
    for index in range(8):
        var angle: float = -2.4 + 1.2 * float(index) / 7.0
        pts.append(origin + Vector2(cos(angle) * radius * 0.32, sin(angle) * radius * 0.55 - radius * 0.25))
    return pts

# Ground contact stays fixed while the body/egg bobs above it.
func _draw_ground_shadow() -> void:
    var width: float = display_width * (0.33 if shell == "egg" else 0.37)
    var foot := Vector2(0,display_width * (0.33 if shell == "egg" else 0.28))
    for layer in range(6,0,-1):
        var extent: float = 1.0 + float(layer)*0.07
        draw_set_transform(foot,0,Vector2(width*extent,width*0.27*extent))
        draw_circle(Vector2.ZERO,1.0,Color(0.10,0.07,0.06,0.035),true,-1,true)
    draw_set_transform(Vector2.ZERO)

func _draw() -> void:
    _draw_ground_shadow()
    if shell == "egg":
        _draw_egg()
        if health_fraction < 0.99:
            var bar_width: float = minf(display_width * 0.75, 55.0)
            var height: float = -display_width * 0.46 - 7.0
            draw_line(Vector2(-bar_width / 2, height), Vector2(bar_width / 2, height), Color("#4c2937"), 5.5, true)
            draw_line(Vector2(-bar_width / 2, height), Vector2(-bar_width / 2 + bar_width * maxf(0.0, health_fraction), height), Color("#f1798c"), 3.5, true)
        return
    # Back plates and horns already come from the body sprite and surface layer.
    # A second pass of triangular crests used to be drawn here; later-tier bosses
    # scale this node up, so those leftover spikes became obvious.
    if elite:
        var face: float = -1.0 if sprite.flip_h else 1.0
        var mid: Vector2 = Vector2(face * display_width * 0.13, sprite.position.y - display_width * 0.15)
        for offset in [Vector2(face * -5.2, 0.6), Vector2(face * 6.0, -0.4)]:
            var eye: Vector2 = mid + offset
            draw_circle(eye, 4.5, Color("#2a0a0c"))
            draw_circle(eye, 3.35, Color("#e01420"))
            draw_circle(eye + Vector2(face * 0.8, -0.9), 1.15, Color("#ffd6d4"))
    if health_fraction < 0.99:
        var bar_width: float = minf(display_width * 0.75, 55.0)
        var height: float = -display_width * 0.46 - 7.0
        draw_line(Vector2(-bar_width / 2, height), Vector2(bar_width / 2, height), Color("#4c2937"), 5.5, true)
        draw_line(Vector2(-bar_width / 2, height), Vector2(-bar_width / 2 + bar_width * maxf(0.0, health_fraction), height), Color("#f1798c"), 3.5, true)
