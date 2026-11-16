extends PanelContainer
const GRAIN = preload("res://assets/ui/paper_grain_v01.png")
var tint := Color("#f4e7c9")
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_theme_stylebox_override("panel", StyleBoxEmpty.new())
func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED: queue_redraw()
func paper_outline() -> PackedVector2Array:
    var r: float = minf(12, minf(size.x, size.y) * 0.18)
    var points := PackedVector2Array()
    var corners := [Vector2(r, r), Vector2(size.x-r, r), Vector2(size.x-r, size.y-r), Vector2(r, size.y-r)]
    for corner in range(4):
        for i in range(6):
            var a: float = PI + corner * PI * 0.5 + i * PI / 10
            points.append(corners[corner] + Vector2.from_angle(a) * r)
        if corner == 2:
            points.append(Vector2(size.x * 0.54, size.y))
            points.append(Vector2(size.x * 0.52, size.y - 3))
            points.append(Vector2(size.x * 0.50, size.y))
    return points
func _draw() -> void:
    if size.x < 4 or size.y < 4: return
    var points := paper_outline()
    var shadow := PackedVector2Array()
    var uv := PackedVector2Array()
    for point in points:
        shadow.append(point + Vector2(1, 3))
        uv.append(point / size)
    draw_colored_polygon(shadow, Color(0.12, 0.10, 0.09, 0.22))
    draw_colored_polygon(points, tint, uv, GRAIN)
    points.append(points[0])
    draw_polyline(points, Color(0.20, 0.18, 0.13, 0.35), 1.1, true)
