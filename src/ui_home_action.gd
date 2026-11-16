extends Button

const GRAIN = preload("res://assets/ui/paper_grain_v01.png")
const Brush=preload("res://src/ui_paper_brush.gd")
const Edge=preload("res://src/ui_paper_edge.gd")
const Pattern=preload("res://src/ui_paper_pattern.gd")
var primary := false
var paper_icon := "enter"
var hover_amount := 0.0
var press_amount := 0.0
var target_hover := 0.0
var target_press := 0.0
var rest_position := Vector2.ZERO
var face: Control
var brush_surface
var pattern_layer: Control
var brush_progress:=0.0
var _last_ink:=Color.TRANSPARENT

class PaperFace:
    extends Control
    var action: Button
    func _draw() -> void:
        if action != null:
            action.draw_shadow(self)

class PaperInk extends Control:
    var action: Button
    func _draw() -> void:
        if action!=null: action.draw_paper(self)

func _ready() -> void:
    set_meta("home_paper_action", true)
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    add_theme_color_override("font_hover_color",Color("#fff1d6"))
    alignment = HORIZONTAL_ALIGNMENT_LEFT
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        var empty := StyleBoxEmpty.new()
        empty.content_margin_left = 54 if size.y > 50 else 45
        empty.content_margin_right = 18
        empty.content_margin_top = 6
        empty.content_margin_bottom = 6
        add_theme_stylebox_override(state, empty)
    rest_position = position
    face = PaperFace.new()
    face.action = self
    face.name = "TornPaperFace"
    face.show_behind_parent = true
    face.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(face)
    face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    brush_surface=Brush.make_surface(self)
    face.add_child(brush_surface)
    pattern_layer=Pattern.make_layer(self,"home")
    face.add_child(pattern_layer)
    var edge:=PaperInk.new()
    edge.action=self;edge.mouse_filter=Control.MOUSE_FILTER_IGNORE
    face.add_child(edge);edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _sync_brush()
    mouse_entered.connect(func(): target_hover = 1.0 if not disabled else 0.0)
    mouse_exited.connect(func(): target_hover = 0.0)
    button_down.connect(func(): target_press = 1.0 if not disabled else 0.0)
    button_up.connect(func(): target_press = 0.0)
    if DisplayServer.get_name() == "headless":
        set_process(false)

func paper_outline() -> PackedVector2Array:
    var w := size.x
    var h := size.y
    return Edge.fray(PackedVector2Array([
        Vector2(22, 3), Vector2(w - 2, 0),
        Vector2(w - 13, h * 0.43), Vector2(w - 9, h * 0.48),
        Vector2(w - 24, h - 3), Vector2(w * 0.55, h),
        Vector2(w * 0.55 - 5, h - 2), Vector2(1, h - 1),
        Vector2(12, h * 0.63), Vector2(8, h * 0.59)]),minf(3.2,h*0.065),17)

func _has_point(point: Vector2) -> bool:
    return Geometry2D.is_point_in_polygon(point, paper_outline())

func _process(delta: float) -> void:
    var wanted: float = 0.0 if disabled else maxf(target_hover, 1.0 if has_focus() else 0.0)
    brush_progress=0.0 if disabled else Brush.advance(brush_progress,wanted,delta)
    hover_amount = lerpf(hover_amount, wanted, 1.0 - exp(-delta * 14.0))
    press_amount = move_toward(press_amount, target_press, delta * 18)
    position = rest_position + Vector2(hover_amount * 3, -hover_amount * 3 + press_amount * 4)
    _sync_brush()
    if face != null: face.queue_redraw()
    for child in face.get_children():
        if child is Control: child.queue_redraw()

func _sync_brush() -> void:
    var base:=Brush.RED if primary else Brush.YELLOW
    var wash:=Brush.YELLOW if primary else Brush.HOVER_ORANGE
    if disabled: base=Color("#b2aa98");wash=base
    brush_surface.configure(base,wash,brush_progress,size.x,press_amount)
    Pattern.sync_layer(pattern_layer,self,brush_progress,press_amount,primary)
    var normal_ink:=Brush.LIGHT_INK if primary else Brush.DARK_INK
    var hover_ink:=Brush.DARK_INK
    if material==null: material=Brush.make_ink_material()
    Brush.sync_ink(material,size,Vector2.ZERO,brush_progress,press_amount,normal_ink,hover_ink)
    var next_ink: Color=normal_ink if brush_progress<0.5 else hover_ink
    if next_ink!=_last_ink:
        for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: add_theme_color_override(state,next_ink)
        _last_ink=next_ink

func draw_shadow(canvas: Control) -> void:
    var points := paper_outline()
    var shadow := PackedVector2Array()
    for point in points:
        shadow.append(point + Vector2(3, 4 + hover_amount * 2 - press_amount * 2))
    canvas.draw_colored_polygon(shadow, Color(0.015, 0.025, 0.04, 0.28))

func draw_paper(canvas: Control) -> void:
    var points:=paper_outline()
    # A broken paper edge belongs to the silhouette; hover adds no new frame.
    var edge := PackedVector2Array([points[0], points[1], points[2]])
    canvas.draw_polyline(edge, Color(1, 0.96, 0.85, 0.30 if not disabled else 0.12), 1.0, true)
    canvas.draw_line(points[4], points[5], Color(0.12, 0.12, 0.10, 0.26), 1.2, true)
    Edge.fibres(canvas,points,17,0.75)
    var normal_ink:=Brush.LIGHT_INK if primary else Brush.DARK_INK
    var hover_ink:=Brush.DARK_INK
    var ink: Color=hover_ink if brush_progress>0.13 else normal_ink
    if press_amount>0.1: ink=Brush.DARK_INK
    if disabled: ink.a = 0.4
    var center := Vector2(31 if size.y > 50 else 27, size.y * 0.5)
    if paper_icon == "enter":
        center.x += hover_amount * 2
        canvas.draw_line(center + Vector2(-9, 0), center + Vector2(8, 0), ink, 2.2, true)
        canvas.draw_polyline(PackedVector2Array([center + Vector2(2, -6), center + Vector2(9, 0), center + Vector2(2, 6)]), ink, 2.2, true)
    elif paper_icon == "continue":
        canvas.draw_polyline(PackedVector2Array([center + Vector2(-6, -8), center + Vector2(5, -8), center + Vector2(5, 9), center + Vector2(0, 5), center + Vector2(-6, 9), center + Vector2(-6, -8)]), ink, 1.7, true)
    elif paper_icon == "help":
        canvas.draw_polyline(PackedVector2Array([center + Vector2(-9, -7), center + Vector2(0, -4), center + Vector2(9, -7), center + Vector2(8, 7), center + Vector2(0, 9), center + Vector2(-8, 7), center + Vector2(-9, -7)]), ink, 1.6, true)
        canvas.draw_line(center + Vector2(0, -4), center + Vector2(0, 9), ink, 1.2, true)
    else:
        canvas.draw_circle(center, 5.4, ink, false, 1.8, true)
        for i in range(6):
            var spoke := Vector2.from_angle(TAU * i / 6 + 0.2)
            canvas.draw_line(center + spoke * 7, center + spoke * 10, ink, 2.2, true)
