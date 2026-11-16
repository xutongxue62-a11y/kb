extends Node2D
const Rules = preload("res://src/rules.gd")

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

func setup(library) -> void:
    var body_region: Rect2 = library.region("hero", "body")
    var ratio: float = 66.0 / body_region.size.y
    var body_center: Vector2 = body_region.get_center()
    for key in ["left_foot", "right_foot", "body", "left_hand", "right_hand"]:
        var sprite: Sprite2D = Sprite2D.new()
        sprite.texture = library.texture("hero", key)
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        sprite.scale = Vector2.ONE * ratio
        var offset: Vector2 = (library.region("hero", key).get_center() - body_center) * ratio
        sprite.position = offset
        rest[key] = offset
        parts[key] = sprite
        add_child(sprite)
    body_scale = parts["body"].scale
    z_index = 10

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

func recoil(direction: Vector2) -> void:
    attack_hand = "left_hand" if direction.x < 0.0 else "right_hand"
    attack_impulse = -direction.normalized() * 3.5

func hurt() -> void:
    hurt_time = 0.28
