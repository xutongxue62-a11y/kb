extends CheckButton
## Keep the status and slider in explicit slots; native icon/text metrics cannot push them out.
const Brush=preload("res://src/ui_paper_brush.gd")
var state_label: Label
var slider: Control
var _shown_text: String=""
var _shown_pressed: bool=false

class SliderFace extends Control:
    var owner_switch: CheckButton
    func _draw() -> void:
        var track:=StyleBoxFlat.new()
        track.bg_color=Color("#75896c") if owner_switch.button_pressed else Color("#af9e83")
        track.border_color=Color("#78654d")
        track.set_border_width_all(1)
        track.set_corner_radius_all(9)
        draw_style_box(track,Rect2(18,15,44,20))
        var center:=Vector2(51 if owner_switch.button_pressed else 29,25)
        draw_circle(center+Vector2(0,1),7.4,Color(0.24,0.17,0.10,0.22))
        draw_circle(center,7.4,Color("#f8ecd3"))
        draw_circle(center,7.4,Color("#8c7657"),false,1.1,true)

func _ready() -> void:
    set_meta("ink_switch",true)
    custom_minimum_size=Vector2(168,50)
    clip_text=true
    # Retain CheckButton's state, keyboard and signal behavior; draw its content in bounded slots.
    var transparent:=Image.create(2,2,false,Image.FORMAT_RGBA8)
    transparent.fill(Color.TRANSPARENT)
    var empty_icon:=ImageTexture.create_from_image(transparent)
    for key in ["on","off","on_disabled","off_disabled","checked","unchecked","checked_disabled","unchecked_disabled","checked_mirrored","unchecked_mirrored","checked_disabled_mirrored","unchecked_disabled_mirrored"]:
        add_theme_icon_override(key,empty_icon)
    for key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]:
        add_theme_color_override(key,Color.TRANSPARENT)
    slider=SliderFace.new()
    slider.owner_switch=self;slider.name="SwitchSlider"
    slider.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(slider)
    slider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    state_label=Label.new()
    state_label.name="SwitchState"
    state_label.position=Vector2(77,0);state_label.size=Vector2(72,50)
    state_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    state_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    state_label.clip_text=true
    state_label.add_theme_font_size_override("font_size",21)
    state_label.add_theme_color_override("font_color",Brush.DARK_INK)
    state_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(state_label)
    _sync_content()
    toggled.connect(func(_value: bool): _sync_content())

func _process(_delta: float) -> void:
    if text!=_shown_text or button_pressed!=_shown_pressed: _sync_content()

func _sync_content() -> void:
    if state_label==null: return
    _shown_text=text;_shown_pressed=button_pressed
    state_label.text=text
    slider.queue_redraw()
