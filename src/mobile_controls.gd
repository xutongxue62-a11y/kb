extends CanvasLayer
const Fonts=preload("res://src/game_fonts.gd")
var world
var active:=false
var stick_finger: int=-1
var stick_center:=Vector2(126,558)
var dodge_center:=Vector2(1154,558)
var movement:=Vector2.ZERO
var surface: Control
var font: SystemFont=Fonts.create_system(PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"]),700)
class TouchSurface extends Control:
    var owner_controls
    func _draw() -> void: owner_controls.paint(self)
func _ready() -> void:
    name="MobileControls";layer=95;process_mode=Node.PROCESS_MODE_ALWAYS
    surface=TouchSurface.new();surface.owner_controls=self
    surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(surface)
func set_active(value: bool) -> void:
    if not value: reset_input()
    active=value
    if surface!=null: surface.visible=active
func reset_input() -> void:
    stick_finger=-1;movement=Vector2.ZERO
    if is_instance_valid(world): world.touch_input=Vector2.ZERO
func feed_touch(index: int,pressed: bool,at: Vector2) -> bool:
    if not active: return false
    if not pressed:
        if index!=stick_finger: return false
        reset_input();return true
    if stick_finger==-1 and at.distance_to(stick_center)<=104:
        stick_finger=index;feed_drag(index,at);return true
    if at.distance_to(dodge_center)<=65:
        if is_instance_valid(world): world.request_dodge(movement)
        return true
    return false
func feed_drag(index: int,at: Vector2) -> bool:
    if not active or index!=stick_finger: return false
    movement=((at-stick_center)/70.0).limit_length(1.0)
    if movement.length()<0.12: movement=Vector2.ZERO
    if is_instance_valid(world): world.touch_input=movement
    return true
func _input(event: InputEvent) -> void:
    var handled:=false
    if event is InputEventScreenTouch: handled=feed_touch(event.index,event.pressed,event.position)
    elif event is InputEventScreenDrag: handled=feed_drag(event.index,event.position)
    if handled: get_viewport().set_input_as_handled()
func _process(_delta: float) -> void:
    if not is_instance_valid(world): return
    set_active(world.running and not world.paused and not world.upgrade_pending and not world.shop_open and not world.stats_open and not world.player_frozen and not world.wave_closing and world.departure_left<=0 and not world.hud.ui_busy())
    if surface!=null: surface.queue_redraw()
func _notification(what: int) -> void:
    if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: reset_input()
    if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(world): world.toggle_pause()
func paint(canvas: Control) -> void:
    var fill:=Color(0.94,0.85,0.65,0.62)
    var ink:=Color(0.35,0.22,0.12,0.80)
    canvas.draw_circle(stick_center,76,fill)
    canvas.draw_arc(stick_center,76,0,TAU,64,ink,2,true)
    canvas.draw_circle(stick_center+movement*48,26,Color(0.67,0.40,0.22,0.78))
    canvas.draw_string(font,stick_center+Vector2(-22,-98),"移动",HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
    canvas.draw_circle(dodge_center,60,fill)
    canvas.draw_arc(dodge_center,60,0,TAU,64,ink,2,true)
    var caption: String="闪避"
    if is_instance_valid(world) and world.get("dodge_cooldown")!=null and world.dodge_cooldown>0.05:
        caption="%.1f" % world.dodge_cooldown
    canvas.draw_string(font,dodge_center+Vector2(-24,8),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,24,ink)
