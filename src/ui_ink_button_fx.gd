extends Control
const GRAIN = preload("res://assets/ui/paper_grain_v01.png")
const Brush=preload("res://src/ui_paper_brush.gd")
const Edge=preload("res://src/ui_paper_edge.gd")
const Pattern=preload("res://src/ui_paper_pattern.gd")
var button: BaseButton
var hover := 0.0
var down := 0.0
var target_hover := 0.0
var target_down := 0.0
var base_color := Color("#f1e6cd")
var applying := false
var queued := false
var brush_progress:=0.0
var brush_surface
var pattern_layer: Control
var _last_ink:=Color.TRANSPARENT
var ink_labels: Array=[]
var _ink_child_count: int=-1

class PaperInk extends Control:
    var skin
    func _draw() -> void:
        if skin!=null: skin.draw_details(self)

func _ready() -> void:
    show_behind_parent = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    brush_surface=Brush.make_surface(self)
    add_child(brush_surface)
    pattern_layer=Pattern.make_layer(button)
    add_child(pattern_layer)
    var edge:=PaperInk.new();edge.skin=self;edge.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(edge);edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    button.mouse_entered.connect(func(): target_hover = 0.0 if button.disabled else 1.0)
    button.mouse_exited.connect(func(): target_hover = 0.0)
    button.button_down.connect(func(): target_down = 0.0 if button.disabled else 1.0)
    button.button_up.connect(func(): target_down = 0.0)
    button.theme_changed.connect(_request_skin)
    _apply_skin()
    _sync_brush()

func _request_skin() -> void:
    if applying or queued: return
    queued = true
    call_deferred("_apply_skin")

func _apply_skin() -> void:
    queued = false
    if not is_instance_valid(button): return
    applying = true
    var old: StyleBox = button.get_theme_stylebox("normal")
    if old is StyleBoxFlat: base_color = old.bg_color
    for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]:
        var current: StyleBox = button.get_theme_stylebox(state)
        if current is StyleBoxEmpty: continue
        var empty := StyleBoxEmpty.new()
        for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
            empty.set_content_margin(side,maxf(5,current.get_content_margin(side)))
        button.add_theme_stylebox_override(state,empty)
    _last_ink=Color.TRANSPARENT
    applying = false
    _sync_brush()
    queue_redraw()

func fill_color(amount: float) -> Color:
    var primary: bool = button.get_meta("ink_primary",false) or base_color.r > base_color.g * 1.35
    var normal: Color=Brush.RED if primary else Brush.YELLOW
    var alternate: Color=Brush.YELLOW if primary else Brush.HOVER_ORANGE
    if button.get_meta("ink_weapon",false): alternate=Brush.WEAPON_HOVER
    return normal.lerp(alternate,amount)

func paper_outline() -> PackedVector2Array:
    var w: float = size.x
    var h: float = size.y
    var slant: float = minf(14,h*0.2) if h < 100 else 5
    return Edge.fray(PackedVector2Array([Vector2(slant,2),Vector2(w-3,0),Vector2(w-4,h*0.42),Vector2(w-7,h*0.45),Vector2(w-slant,h-2),Vector2(w*0.53,h),Vector2(w*0.51,h-3),Vector2(2,h-1),Vector2(4,h*0.68),Vector2(2,h*0.62)]),minf(3.2,h*0.055),23)

func _process(delta: float) -> void:
    if not is_instance_valid(button): return
    brush_progress=0.0 if button.disabled else Brush.advance(brush_progress,target_hover,delta)
    hover = lerpf(hover,0.0 if button.disabled else target_hover,1-exp(-delta*16))
    down = move_toward(down,target_down,delta*20)
    button.pivot_offset = button.size*0.5
    button.scale = Vector2.ONE*(1-down*0.035)
    _sync_brush()
    queue_redraw()
    for child in get_children():
        if child is Control: child.queue_redraw()

func _sync_brush() -> void:
    brush_surface.visible=true
    var normal:=fill_color(0)
    var wash:=fill_color(1)
    if button.has_meta("ink_nav"): normal=Color.TRANSPARENT;wash=Brush.HOVER_ORANGE
    if button.toggle_mode and button.button_pressed and not button.has_meta("ink_switch"): normal=Brush.RED;wash=Brush.YELLOW
    if button.disabled: normal=base_color.darkened(0.09);wash=normal
    brush_surface.configure(normal,wash,brush_progress,size.x,down)
    if button.get_meta("ink_weapon",false): brush_surface.material.set_shader_parameter("press_tint",Brush.WEAPON_PRESSED)
    var primary: bool=button.get_meta("ink_primary",false) or base_color.r>base_color.g*1.35
    Pattern.sync_layer(pattern_layer,button,brush_progress,down,primary)
    var normal_ink: Color=Brush.LIGHT_INK if primary else Brush.DARK_INK
    var hover_ink: Color=Brush.DARK_INK
    if button.get_meta("ink_reward_sale",false): normal_ink=Color("#a74c37");hover_ink=Brush.LIGHT_INK
    if button.toggle_mode and button.button_pressed and not button.has_meta("ink_switch"): normal_ink=Brush.LIGHT_INK;hover_ink=Brush.DARK_INK
    if button.disabled: normal_ink=Color("#685c49");hover_ink=normal_ink
    if button.material==null: button.material=Brush.make_ink_material()
    Brush.sync_ink(button.material,button.size,Vector2.ZERO,brush_progress,down,normal_ink,hover_ink)
    if _ink_child_count!=button.get_child_count():
        ink_labels.clear()
        for child in button.get_children():
            if child is Label:
                child.material=Brush.make_ink_material()
                ink_labels.append(child)
        _ink_child_count=button.get_child_count()
    for label in ink_labels:
        Brush.sync_ink(label.material,button.size,label.position,brush_progress,down,label.get_theme_color("font_color"),hover_ink)
    var next_ink: Color=normal_ink if brush_progress<0.5 else hover_ink
    if next_ink!=_last_ink:
        applying=true
        for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
            button.add_theme_color_override(state,Color(next_ink,0.0) if button.has_meta("ink_switch") else next_ink)
        applying=false
        _last_ink=next_ink

func _draw() -> void:
    if not is_instance_valid(button) or size.x<4 or button.has_meta("ink_nav"): return
    var shadow:=PackedVector2Array()
    for p in paper_outline(): shadow.append(p+Vector2(1,3+hover-down))
    draw_colored_polygon(shadow,Color(0.10,0.07,0.05,0.23))

func draw_details(canvas: Control) -> void:
    if not is_instance_valid(button) or size.x < 4: return
    if button.has_meta("ink_nav"):
        var direction: float = float(button.get_meta("ink_nav"))
        var center := size*0.5+Vector2(direction*hover*3,0)
        var ink := Brush.DARK_INK
        if down>0.1: ink=Brush.DARK_INK
        ink.a = 0.34 if button.disabled else 0.95
        canvas.draw_polyline(PackedVector2Array([center+Vector2(-direction*5,-9),center+Vector2(direction*5,0),center+Vector2(-direction*5,9)]),ink,3.2,true)
        return
    var points := paper_outline()
    Edge.fibres(canvas,points,23,0.6)
    points.append(points[0])
    canvas.draw_polyline(points,Color(0.25,0.17,0.11,0.35),1,true)
