extends Control
## Reusable hand-drawn torn/frayed parchment card backdrop.
## Caches frayed polygon geometry on resize for zero per-frame overhead.

const Edge = preload("res://src/ui_paper_edge.gd")
const PAPER_GRAIN: Texture2D = preload("res://assets/ui/paper_grain_v01.png")

var fill_color: Color = Color("#f4e8cd")
var border_color: Color = Color("#6e5339")
var seed_id: int = 17
var fray_amp: float = 2.6
var border_width: float = 1.3
var shadow_offset: Vector2 = Vector2(2.0, 3.0)
var show_fibres: bool = false

var _cached_size: Vector2 = Vector2.ZERO
var _cached_pts: PackedVector2Array = PackedVector2Array()
var _cached_uv: PackedVector2Array = PackedVector2Array()
var _cached_shadow: PackedVector2Array = PackedVector2Array()
var _cached_outline: PackedVector2Array = PackedVector2Array()

static func apply(target: Control, fill: Color, border: Color = Color("#7a5c3d"), p_seed: int = 17, p_fray: float = 2.6, p_border_w: float = 1.3, margins: Vector4 = Vector4.ZERO, p_fibres: bool = false) -> Control:
    if target is Panel or target is PanelContainer:
        var empty := StyleBoxEmpty.new()
        if margins != Vector4.ZERO:
            empty.content_margin_left = margins.x
            empty.content_margin_top = margins.y
            empty.content_margin_right = margins.z
            empty.content_margin_bottom = margins.w
        target.add_theme_stylebox_override("panel", empty)
    var bg: Control = target.find_child("_TornCardBg", false, false) as Control
    if bg == null:
        bg = new()
        bg.name = "_TornCardBg"
        bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bg.show_behind_parent = true
        bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        target.add_child(bg)
        target.move_child(bg, 0)
    bg.fill_color = fill
    bg.border_color = border
    if bg.seed_id != p_seed or not is_equal_approx(bg.fray_amp, p_fray):
        bg.seed_id = p_seed
        bg.fray_amp = p_fray
        bg._cached_size = Vector2.ZERO
    bg.border_width = p_border_w
    bg.show_fibres = p_fibres
    bg.queue_redraw()
    return bg

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _cached_size = Vector2.ZERO
        queue_redraw()

func _rebuild(draw_origin: Vector2, draw_size: Vector2) -> void:
    _cached_size = draw_size
    var w: float = draw_size.x
    var h: float = draw_size.y
    if w < 10.0 or h < 10.0:
        _cached_pts = PackedVector2Array()
        return
    var inset: float = minf(fray_amp + 1.0, minf(w, h) * 0.12)
    var base := PackedVector2Array([
        Vector2(inset, inset),
        Vector2(w - inset, inset),
        Vector2(w - inset, h - inset),
        Vector2(inset, h - inset)
    ])
    var amp: float = minf(fray_amp, minf(w, h) * 0.08)
    var raw: PackedVector2Array = Edge.fray(base, amp, seed_id)
    _cached_pts = PackedVector2Array()
    _cached_uv = PackedVector2Array()
    _cached_shadow = PackedVector2Array()
    for pt in raw:
        _cached_pts.append(pt + draw_origin)
        _cached_uv.append(Vector2(clampf(pt.x / w, 0.0, 1.0), clampf(pt.y / h, 0.0, 1.0)))
        _cached_shadow.append(pt + draw_origin + shadow_offset)
    _cached_outline = PackedVector2Array(_cached_pts)
    if not _cached_pts.is_empty():
        _cached_outline.append(_cached_pts[0])

func _draw() -> void:
    var parent_ctrl: Control = get_parent() as Control
    var draw_origin: Vector2 = -position if parent_ctrl is PanelContainer else Vector2.ZERO
    var draw_size: Vector2 = parent_ctrl.size if parent_ctrl is PanelContainer else size
    if draw_size.x < 10.0 or draw_size.y < 10.0:
        return
    if _cached_size != draw_size or _cached_pts.is_empty():
        _rebuild(draw_origin, draw_size)
    if _cached_pts.size() < 3:
        return
    draw_colored_polygon(_cached_shadow, Color(0.06, 0.04, 0.02, 0.18))
    draw_colored_polygon(_cached_pts, fill_color, _cached_uv, PAPER_GRAIN)
    if show_fibres:
        Edge.fibres(self, _cached_pts, seed_id, 1.1)
    if border_width > 0.1:
        draw_polyline(_cached_outline, border_color, border_width, true)
