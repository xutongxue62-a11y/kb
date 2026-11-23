extends Node2D

const CreatureFrames = preload("res://src/creature_frames.gd")
const BOSS_ATLAS = preload("res://assets/encounters/bosses.png")
const MOB_ATLAS = preload("res://assets/encounters/creatures.png")
const GAIT_PADDING := 56
static var isolated_art: Dictionary = {}

const ENCOUNTER_ART := {
    "fernmask": Rect2(35, 40, 709, 428),
    "cinderback": Rect2(784, 54, 729, 394),
    "drumjaw": Rect2(27, 532, 706, 457),
    "fernmask_dark": Rect2(780, 529, 729, 456),
    "sidesnap": Rect2(43, 34, 466, 257),
    "stonecrest": Rect2(577, 18, 321, 268),
    "shieldback": Rect2(1021, 8, 462, 283),
    "leafstalker": Rect2(23, 317, 508, 351),
    "sporeback": Rect2(572, 340, 391, 321),
    "bonecaller": Rect2(1052, 314, 374, 358),
    "embersnout": Rect2(26, 753, 437, 237),
    "ashhound": Rect2(487, 720, 502, 276),
    "basaltroller": Rect2(1032, 711, 451, 284),
}

var sprite: Sprite2D
var surface: Sprite2D
var base_scale: Vector2
var kind: String
var walk_time: float = 0.0
var hit_time: float = 0.0
var health_fraction: float = 1.0:
    set(value):
        var fraction: float = clampf(value, 0.0, 1.0)
        if health_fraction != fraction:
            health_fraction = fraction
            queue_redraw()
var elite: bool = false:
    set(value):
        elite = value
        _update_outline()
        queue_redraw()
var asset_library
var display_width: float = 60.0
var shell: String = ""
var crack_progress: float = 0.0
var encounter_art: String = ""
var encounter_tint: Color = Color.WHITE
var pose_clock: float = 0.0
var last_pose: String = ""
var body_dimensions := Vector2.ZERO
var foot_phase: float = 0.0
var gait_amount: float = 0.0
var frames: Node2D
var facing: float = 1.0
var _egg_draw_accum: float = 0.0

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
    body_dimensions = dimensions
    base_scale = Vector2.ONE * size / maxf(dimensions.x, dimensions.y)
    sprite.scale = base_scale
    display_width = size
    add_child(sprite)
    surface=Sprite2D.new()
    surface.name="SurfaceArt"
    surface.texture=library.EnemyArt.surface_texture(kind,dimensions)
    sprite.add_child(surface)
    surface.material = library.EnemyArt.surface_material(sprite.texture)
    frames = CreatureFrames.new()
    frames.configure(kind, size)
    frames.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(frames)
    facing = -1.0 if kind in ["tank", "boss"] else 1.0
    _update_outline()
    set_shell(shell)

func _update_outline() -> void:
    if sprite != null:
        sprite.material = asset_library.team_material("dinosaurs", kind, "elite" if elite else "enemy", (2.2 if elite else 1.2) / base_scale.x)
    if frames != null:
        frames.set_elite_outline(asset_library.team_shader if elite else null)

func set_encounter_art(form: String) -> void:
    var key: String = form if ENCOUNTER_ART.has(form) else form.trim_suffix("_dark")
    if not ENCOUNTER_ART.has(key):
        frames.configure(form, display_width)
        if frames.ready_to_draw:
            encounter_art = form
            set_shell(shell)
        return
    var bounds := Rect2i(ENCOUNTER_ART[key])
    if not isolated_art.has(key):
        var atlas: Texture2D = BOSS_ATLAS if key in ["fernmask", "cinderback", "drumjaw", "fernmask_dark"] else MOB_ATLAS
        var padded := Image.create(bounds.size.x + GAIT_PADDING * 2, bounds.size.y + GAIT_PADDING * 2, false, Image.FORMAT_RGBA8)
        padded.blit_rect(atlas.get_image(), bounds, Vector2i.ONE * GAIT_PADDING)
        padded.fix_alpha_edges()
        isolated_art[key] = ImageTexture.create_from_image(padded)
    encounter_art = form
    if form != key:
        encounter_tint = Color("#ad8b9c")
    sprite.texture = isolated_art[key]
    body_dimensions = Vector2(bounds.size)
    base_scale = Vector2.ONE * display_width / maxf(body_dimensions.x, body_dimensions.y)
    _update_outline()
    sprite.scale = base_scale
    surface.hide()
    frames.configure(form, display_width)
    facing = 1.0
    sprite.flip_h = false
    set_shell(shell)

func face_attack(direction: Vector2) -> void:
    if absf(direction.x) > 0.05:
        facing = signf(direction.x)
        var source_left: bool = encounter_art.is_empty() and kind in ["tank", "boss"]
        sprite.flip_h = facing > 0.0 if source_left else facing < 0.0

func set_crack(progress: float) -> void:
    crack_progress = clampf(progress, 0.0, 1.0)
    queue_redraw()

func set_shell(mode: String) -> void:
    shell = mode
    if mode != "egg":
        crack_progress = 0.0
    if frames != null:
        frames.visible = mode != "egg" and frames.ready_to_draw
        sprite.visible = mode != "egg" and not frames.ready_to_draw
    _update_tint()
    queue_redraw()

func animate(velocity: Vector2, delta: float, state: String = "walk", travelled: float = -1.0) -> void:
    hit_time = maxf(hit_time - delta, 0.0)
    if shell == "egg":
        walk_time += delta * 2.2
        _egg_draw_accum += delta
        if _egg_draw_accum >= 0.065:
            _egg_draw_accum = 0.0
            queue_redraw()
        return
    if absf(velocity.x) > 3.0:
        face_attack(velocity)
    if surface!=null: surface.flip_h=sprite.flip_h
    var distance: float = velocity.length() * delta if travelled < 0.0 else travelled
    var amount: float = clampf(distance / maxf(delta * 85.0, 0.001), 0.0, 1.0)
    var stepping: bool = state in ["walk", "dash", "charge"]
    if stepping:
        foot_phase = fposmod(foot_phase + distance * TAU / (display_width * 0.43), TAU)
    gait_amount = move_toward(gait_amount, amount if stepping else 0.0, delta * 10.0)
    if last_pose != state:
        pose_clock = 0.0
        last_pose = state
    pose_clock += delta
    frames.pose(foot_phase, stepping and distance > 0.001, state, pose_clock, facing)
    _update_tint()

func _update_tint() -> void:
    var tint: Color = encounter_tint.lerp(Color("#f49b8b"), hit_time * 2.4)
    if frames != null:
        frames.modulate = tint
    if sprite != null:
        sprite.modulate = tint

func hit() -> void:
    hit_time = 0.10

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
    draw_set_transform(foot, 0.0, Vector2(width * 1.28, width * 0.27 * 1.28))
    draw_circle(Vector2.ZERO, 1.0, Color(0.10, 0.07, 0.06, 0.09), true, -1, true)
    draw_set_transform(foot, 0.0, Vector2(width, width * 0.27))
    draw_circle(Vector2.ZERO, 1.0, Color(0.10, 0.07, 0.06, 0.13), true, -1, true)
    draw_set_transform(Vector2.ZERO)

func _draw() -> void:
    _draw_ground_shadow()
    if shell == "egg":
        _draw_egg()
        if health_fraction < 1.0:
            var bar_width: float = minf(display_width * 0.75, 55.0)
            var height: float = -display_width * 0.46 - 7.0
            draw_line(Vector2(-bar_width / 2, height), Vector2(bar_width / 2, height), Color("#4c2937"), 5.5, true)
            draw_line(Vector2(-bar_width / 2, height), Vector2(-bar_width / 2 + bar_width * maxf(0.0, health_fraction), height), Color("#f1798c"), 3.5, true)
        return
    if elite or encounter_art.ends_with("_dark"):
        var spot := Vector2(0, display_width * 0.30)
        var color := Color("#ead5ac") if elite else Color("#71394d")
        for x in [-1.0, 0.0, 1.0]:
            var mark: Vector2 = spot + Vector2(x * 7.0, absf(x) * 2.0)
            draw_line(mark + Vector2(-2.0, 4.0), mark + Vector2(2.0, -3.0), Color("#36271f"), 5.0, true)
            draw_line(mark + Vector2(-2.0, 4.0), mark + Vector2(2.0, -3.0), color, 2.5, true)
    if health_fraction < 1.0:
        var bar_width: float = minf(display_width * 0.75, 55.0)
        var height: float = -display_width * 0.46 - 7.0
        draw_line(Vector2(-bar_width / 2, height), Vector2(bar_width / 2, height), Color("#4c2937"), 5.5, true)
        draw_line(Vector2(-bar_width / 2, height), Vector2(-bar_width / 2 + bar_width * maxf(0.0, health_fraction), height), Color("#f1798c"), 3.5, true)
