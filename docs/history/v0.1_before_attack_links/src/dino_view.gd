extends Node2D

var sprite: Sprite2D
var base_scale: Vector2
var kind: String
var walk_time: float = 0.0
var hit_time: float = 0.0
var health_fraction: float = 1.0
var elite: bool = false
var display_width: float = 60.0

func setup(library, creature_kind: String, size: float, is_elite: bool) -> void:
    kind = creature_kind
    elite = is_elite
    sprite = Sprite2D.new()
    sprite.texture = library.texture("dinosaurs", kind)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    var dimensions: Vector2 = sprite.texture.get_size()
    base_scale = Vector2.ONE * size / maxf(dimensions.x, dimensions.y)
    sprite.scale = base_scale
    display_width = size
    add_child(sprite)

func animate(velocity: Vector2, delta: float, state: String = "walk") -> void:
    hit_time = maxf(hit_time - delta, 0.0)
    if absf(velocity.x) > 3.0:
        sprite.flip_h = velocity.x > 0.0 if kind == "tank" else velocity.x < 0.0
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
    sprite.modulate = Color(1.0, 0.88, 0.69) if hit_time > 0.09 else Color.WHITE
    queue_redraw()

func hit() -> void:
    hit_time = 0.2

func _draw() -> void:
    if elite:
        draw_circle(Vector2(0, -26), 3.2, Color("#d5a747"))
        draw_arc(Vector2.ZERO, display_width * 0.37, 0, TAU, 28, Color(0.75, 0.51, 0.19, 0.45), 1.4, true)
    if health_fraction < 0.99:
        var bar_width: float = minf(display_width * 0.75, 55.0)
        draw_line(Vector2(-bar_width / 2, 27), Vector2(bar_width / 2, 27), Color("#705840"), 4.5, true)
        draw_line(Vector2(-bar_width / 2, 27), Vector2(-bar_width / 2 + bar_width * maxf(0.0, health_fraction), 27), Color("#a6b77e"), 3.0, true)
