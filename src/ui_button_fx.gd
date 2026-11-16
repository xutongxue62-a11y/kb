extends Control

var button: BaseButton
var hover := 0.0
var down := 0.0
var target_hover := 0.0
var target_down := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    button.mouse_entered.connect(func():
        if not button.disabled: target_hover = 1.0)
    button.mouse_exited.connect(func(): target_hover = 0.0)
    button.button_down.connect(func():
        if not button.disabled: target_down = 1.0)
    button.button_up.connect(func(): target_down = 0.0)

func _process(delta: float) -> void:
    if not is_instance_valid(button): return
    hover = move_toward(hover, 0.0 if button.disabled else target_hover, delta * 9)
    down = move_toward(down, target_down, delta * 22)
    button.pivot_offset = button.size * 0.5
    button.scale = Vector2.ONE * (1.0 - down * 0.018)
    queue_redraw()

func _draw() -> void:
    if not is_instance_valid(button): return
    if button.get_meta("quiet_chrome", false): return
    var primary: bool = button.get_meta("ink_primary", false)
    var ink := Color("#f2e8d2") if primary else Color("#af4833")
    if button.has_meta("ink_nav"):
        var direction: float = float(button.get_meta("ink_nav"))
        var center := size * 0.5 + Vector2(direction * hover * 3, down * 1.5)
        var tone := Color("#17253a")
        tone.a = 0.34 if button.disabled else 0.95
        var points := PackedVector2Array([center + Vector2(-direction * 5, -9), center + Vector2(direction * 5, 0), center + Vector2(-direction * 5, 9)])
        draw_polyline(points, tone, 3.2, true)
        if hover > 0.02:
            draw_line(center + Vector2(-12, 17), center + Vector2(12, 17), Color("#af4833"), 1.5 * hover, true)
        return
    if hover > 0.01:
        ink.a = hover * 0.88
        draw_line(Vector2(12, size.y - 7), Vector2(12 + (size.x - 24) * hover, size.y - 7), ink, 1.7, true)
        var n: float = 5 + 7 * hover
        for x in [6.0, size.x - 6]:
            var d: float = 1 if x < size.x * 0.5 else -1
            draw_polyline(PackedVector2Array([Vector2(x, 7 + n), Vector2(x, 7), Vector2(x + d * n, 7)]), ink, 1.5, true)
    if down > 0.01:
        draw_line(Vector2(8, size.y - 4), Vector2(size.x - 8, size.y - 4), Color(0.08, 0.12, 0.18, down * 0.5), 2, true)
