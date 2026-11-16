extends Node2D
const GameFonts=preload("res://src/game_fonts.gd")
const Rules = preload("res://src/rules.gd")
const Catalog = preload("res://src/catalog.gd")

var library = null
var character_id: String = "caveman"
var parts: Dictionary = {}
var rest: Dictionary = {}
var body_scale: Vector2
var phase: float = 0.0
var amplitude: float = 0.0
var last_direction: Vector2 = Vector2.DOWN
var attack_impulse: Vector2 = Vector2.ZERO
var attack_hand: String = "right_hand"
var hurt_time: float = 0.0
var idle_time: float = 0.0
var ground_shadow_origin: Vector2 = Vector2(0, 47)

func setup(asset_library, start_character: String = "caveman") -> void:
    library = asset_library
    var body_region: Rect2 = library.region("hero", "body")
    var ratio: float = 66.0 / body_region.size.y
    var body_center: Vector2 = body_region.get_center()
    for key in ["left_foot", "right_foot", "body", "left_hand", "right_hand"]:
        var sprite: Sprite2D = Sprite2D.new()
        sprite.texture = library.texture("hero", key)
        sprite.material = library.team_material("hero", key, "hero", 1.2 / ratio)
        if key != "body":
            sprite.texture = library.hero_limb_texture(key)
        sprite.material = null
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        sprite.scale = Vector2.ONE * ratio
        var offset: Vector2 = (library.region("hero", key).get_center() - body_center) * ratio
        sprite.position = offset
        rest[key] = offset
        parts[key] = sprite
        add_child(sprite)
    body_scale = parts["body"].scale
    set_character(start_character)
    # Resting soles define the ground plane. Body breathing, foot gait and hurt
    # animation only move the sprites, never this projection.
    ground_shadow_origin = (rest["left_foot"] + rest["right_foot"]) * 0.5
    ground_shadow_origin.y += library.region("hero", "left_foot").size.y * ratio * 0.5 - 1.5
    z_index = 10
    var marker: Label = Label.new()
    marker.name = "PlayerMarker"
    marker.text = "▼ 我"
    marker.position = Vector2(-24, -67)
    marker.z_index = 32
    marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var font: SystemFont = GameFonts.create_system(PackedStringArray(["Microsoft YaHei", "Arial"]))
    font.font_names = PackedStringArray(["Microsoft YaHei", "Arial"])
    marker.add_theme_font_override("font", font)
    marker.add_theme_font_size_override("font_size", 18)
    marker.add_theme_color_override("font_color", Color("#b9fbff"))
    marker.add_theme_color_override("font_outline_color", Color("#214653"))
    marker.add_theme_constant_override("outline_size", 5)
    add_child(marker)

func animate(velocity: Vector2, distance: float, delta: float) -> void:
    idle_time += delta
    if velocity.length() > 1.0:
        last_direction = velocity.normalized()
    amplitude = move_toward(amplitude, 1.0 if velocity.length() > 3.0 else 0.0, delta * 7.0)
    phase = Rules.advance_gait(phase, distance, 96.0)
    var pose: Dictionary = Rules.gait_pose(phase, last_direction, amplitude)
    attack_impulse = attack_impulse.move_toward(Vector2.ZERO, delta * 31.0)
    hurt_time = maxf(0.0, hurt_time - delta)
    for key in ["left_hand", "right_hand", "left_foot", "right_foot"]:
        var impulse: Vector2 = attack_impulse if key == attack_hand else Vector2.ZERO
        parts[key].position = rest[key] + pose[key] + impulse
        parts[key].rotation = (sin(phase) * 0.10 * amplitude) * (-1.0 if key.begins_with("left") else 1.0)
    var breathing: float = sin(idle_time * 2.3) * 0.28 * (1.0 - amplitude)
    parts["body"].position = pose["body"] + Vector2(0.0, breathing)
    parts["body"].rotation = pose["rotation"]
    parts["body"].scale = body_scale * Vector2(1.0 + absf(sin(phase)) * 0.013 * amplitude, 1.0 - absf(sin(phase)) * 0.014 * amplitude)
    modulate = Color(1.0, 0.72, 0.62) if hurt_time > 0.14 else Color.WHITE
    queue_redraw()

func recoil(direction: Vector2) -> void:
    attack_hand = "left_hand" if direction.x < 0.0 else "right_hand"
    attack_impulse = -direction.normalized() * 3.5

func hurt() -> void:
    hurt_time = 0.28

func set_character(id: String) -> void:
    character_id = id if Catalog.CHARACTERS.has(id) else "caveman"
    if library == null or not parts.has("body"):
        return
    var body: Sprite2D = parts["body"]
    body.texture = library.hero_body_texture(character_id)
    var content_size: Vector2 = body.texture.get_meta("content_size",body.texture.get_size())
    var ratio: float = 66.0 / content_size.y
    body.scale = Vector2.ONE * ratio
    body_scale = body.scale
    body.material = null
    body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func body_resource_path() -> String:
    if not parts.has("body") or parts["body"].texture == null:
        return ""
    var tex: Texture2D = parts["body"].texture
    if tex.has_meta("source_path"):
        return str(tex.get_meta("source_path"))
    if tex is AtlasTexture:
        var atlas: Texture2D = (tex as AtlasTexture).atlas
        return atlas.resource_path if atlas != null else ""
    return tex.resource_path

func uses_default_hero_body() -> bool:
    return body_resource_path().ends_with("hero.png") or library != null and parts.has("body") and parts["body"].texture == library.texture("hero", "body")

func ground_shadow_anchor() -> Vector2:
    return ground_shadow_origin

func _draw() -> void:
    _draw_ground_shadow(self)

func _draw_ground_shadow(canvas) -> void:
    var anchor: Vector2 = ground_shadow_anchor()
    # Soft ground shadow stays, plus a fixed teal ring so the hero remains findable in crowds.
    for layer in range(5):
        var extent := Vector2(28.0 - layer * 3.1, 7.4 - layer * 0.85)
        var points := PackedVector2Array()
        for index in range(40):
            var angle: float = float(index) * TAU / 40.0
            points.append(anchor + Vector2(cos(angle), sin(angle)) * extent)
        canvas.draw_colored_polygon(points, Color(0.12, 0.10, 0.08, 0.035 + layer * 0.014))
    # The marker stays on the ground plane rather than following the body gait.
    var mark := PackedVector2Array()
    for index in range(41):
        var angle: float = float(index) * TAU / 40.0
        mark.append(anchor + Vector2(cos(angle) * 30.0, sin(angle) * 10.0))
    canvas.draw_polyline(mark, Color(0.36, 0.64, 0.55, 0.20), 7.0, true)
    canvas.draw_polyline(mark, Color(0.60, 0.82, 0.69, 0.82), 2.2, true)

