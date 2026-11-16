extends RefCounted
## Uneven cave-paint strokes, fixed per button. The brush masks them locally as it passes.
static var mask_shader: Shader

class Layer extends Control:
    var painter: Callable
    var pattern_seed: int=0
    var role: String="button"
    var ink:=Color(0.53,0.32,0.15,0.24)
    func _ready() -> void:
        mouse_filter=Control.MOUSE_FILTER_IGNORE
        set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    func _draw() -> void:
        if painter.is_valid(): painter.call(self,size,pattern_seed,role,ink)

static func make_layer(owner_control: Control,role: String="button") -> Control:
    if mask_shader==null:
        mask_shader=Shader.new()
        mask_shader.code='''shader_type canvas_item;
render_mode unshaded;
uniform vec2 paper_size = vec2(300.0,80.0);
uniform float progress = 0.0;
uniform float press_amount = 0.0;
varying vec2 paper_position;
void vertex(){paper_position=VERTEX;}
void fragment(){
    float pixel_step=1.0/max(paper_size.x,1.0);
    float edge_width=clamp(0.7*pixel_step,0.001,0.025);
    float bristles=(sin(paper_position.y*0.53)+sin(paper_position.y*1.47)*0.35)*pixel_step*3.4;
    float edge=mix(-edge_width*2.0,1.0+edge_width*2.0,progress);
    float covered=1.0-smoothstep(edge-edge_width,edge+edge_width,paper_position.x/paper_size.x+bristles);
    if(progress<=0.0){covered=0.0;}
    if(progress>=1.0||press_amount>0.1){covered=1.0;}
    COLOR.a*=1.0-covered;
}'''
    var node:=Layer.new()
    node.name="PaperCaveMarks";node.role=role;node.painter=draw
    node.pattern_seed=int(str(owner_control.name).hash())
    node.mouse_filter=Control.MOUSE_FILTER_IGNORE
    node.material=ShaderMaterial.new();node.material.shader=mask_shader
    return node

static func sync_layer(node: Control,owner_control: Control,progress: float,pressed: float,light: bool=false) -> void:
    node.pattern_seed=int(str(owner_control.name).hash())
    node.ink=Color(0.98,0.87,0.67,0.22) if light else Color(0.53,0.32,0.15,0.24)
    node.role="home" if owner_control.has_meta("home_paper_action") else str(owner_control.get_meta("ink_layout","button"))
    node.material.set_shader_parameter("paper_size",owner_control.size)
    node.material.set_shader_parameter("progress",progress)
    node.material.set_shader_parameter("press_amount",pressed)
    node.queue_redraw()

static func _stroke(canvas: CanvasItem,points: PackedVector2Array,at: Vector2,scale: float,angle: float,ink: Color,width: float=1.8) -> void:
    for i in range(1,points.size()):
        var a: Vector2=at+(points[i-1]*scale).rotated(angle)
        var b: Vector2=at+(points[i]*scale).rotated(angle)
        canvas.draw_line(a,b,ink,width*(0.79+0.20*absf(sin(i*2.31))),true)

static func _glyph(canvas: CanvasItem,at: Vector2,scale: float,angle: float,kind: int,ink: Color) -> void:
    var paths: Array=[]
    match posmod(kind,4):
        0:
            paths=[PackedVector2Array([Vector2(-13,4),Vector2(-8,2),Vector2(-5,-2),Vector2(2,-1),Vector2(7,-5),Vector2(11,-3),Vector2(8,0)]),
                PackedVector2Array([Vector2(-4,-1),Vector2(-2,5),Vector2(-6,8)]),
                PackedVector2Array([Vector2(3,-1),Vector2(6,5),Vector2(10,4)])]
        1:
            paths=[PackedVector2Array([Vector2(-7,2),Vector2(-8,-4),Vector2(-2,-8),Vector2(4,-7),Vector2(7,-2),Vector2(3,4),Vector2(-3,5)]),
                PackedVector2Array([Vector2(-10,-6),Vector2(-13,-9)]),
                PackedVector2Array([Vector2(1,-11),Vector2(3,-15)]),
                PackedVector2Array([Vector2(9,1),Vector2(13,4)])]
        2:
            paths=[PackedVector2Array([Vector2(-3,-8),Vector2(1,-12),Vector2(5,-8),Vector2(2,-4),Vector2(-3,-8)]),
                PackedVector2Array([Vector2(1,-4),Vector2(-1,3),Vector2(2,9)]),
                PackedVector2Array([Vector2(-8,-1),Vector2(-3,2),Vector2(1,-1),Vector2(8,-6)]),
                PackedVector2Array([Vector2(2,8),Vector2(-5,15)]),
                PackedVector2Array([Vector2(2,9),Vector2(8,13)])]
        _:
            paths=[PackedVector2Array([Vector2(-8,-4),Vector2(-5,1),Vector2(-6,7)]),
                PackedVector2Array([Vector2(-1,-8),Vector2(1,-1),Vector2(-1,8)]),
                PackedVector2Array([Vector2(6,-5),Vector2(7,2),Vector2(5,6)])]
    for path in paths: _stroke(canvas,path,at,scale,angle,ink)

static func draw(canvas: CanvasItem,size: Vector2,seed: int=0,role: String="button",ink: Color=Color(0.53,0.32,0.15,0.24)) -> void:
    var variant: int=posmod(seed,11)
    var tilt: float=-0.23+0.047*variant
    if role=="home":
        _glyph(canvas,Vector2(size.x-43,size.y*0.48),0.66,tilt,variant,ink)
        if size.x>240:
            _stroke(canvas,PackedVector2Array([Vector2(-7,0),Vector2(0,2),Vector2(9,-1)]),Vector2(size.x-86,14),0.9,-0.2,ink,1.6)
    elif size.y>260 and role!="side_icon":
        _glyph(canvas,Vector2(29,111+variant*0.7),0.92,tilt,variant,ink)
        _glyph(canvas,Vector2(size.x-29,126-variant*0.6),0.76,-tilt+0.25,variant+2,ink)
        _stroke(canvas,PackedVector2Array([Vector2(-8,1),Vector2(-2,-2),Vector2(6,0)]),Vector2(size.x-28,25),0.8,0.16,ink,1.6)
    elif size.y>110:
        _glyph(canvas,Vector2(24,18),0.38,tilt,variant+3,ink)
        _glyph(canvas,Vector2(size.x-23,20+variant*0.5),0.43,-0.2,variant+1,ink)
        if size.x>320: _glyph(canvas,Vector2(25,size.y-61),0.54,-0.3,variant,ink)
    elif size.x>130:
        _glyph(canvas,Vector2(size.x-24,size.y*0.48),0.47,tilt,variant+3,ink)
        if size.x>240: _glyph(canvas,Vector2(21,size.y*0.53),0.36,-tilt,variant+1,ink)
    else:
        _stroke(canvas,PackedVector2Array([Vector2(-2,-4),Vector2(0,1),Vector2(-1,5)]),Vector2(12,12),0.8,0.3,ink,1.4)

static func draw_scroll(canvas: CanvasItem,area: Rect2) -> void:
    if area.size.x<280 or area.size.y<180: return
    var ink:=Color(0.53,0.32,0.15,0.20)
    _glyph(canvas,area.position+Vector2(56,38),0.70,-0.27,1,ink)
    _glyph(canvas,area.position+Vector2(area.size.x-54,48),0.67,0.19,0,ink)
    _glyph(canvas,area.position+Vector2(54,area.size.y-37),0.55,0.30,2,ink)
    _glyph(canvas,area.position+Vector2(area.size.x-56,area.size.y-43),0.75,-0.23,3,ink)
