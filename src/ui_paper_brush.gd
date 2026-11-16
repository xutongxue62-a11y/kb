extends RefCounted
const GRAIN=preload("res://assets/ui/paper_grain_v01.png")
const ENTER_TIME:=0.18
const EXIT_TIME:=0.12
const RED:=Color("#b5654b")
const YELLOW:=Color("#f3e5cc")
const HOVER_ORANGE:=Color("#cf6b50")
const WEAPON_HOVER:=Color("#dfad72")
const WEAPON_PRESSED:=Color("#c69a59")
const PRESSED:=Color("#b9543e")
const DARK_INK:=Color("#302317")
const LIGHT_INK:=Color("#fff3d9")
static var shader: Shader
static var ink_shader: Shader

class Surface extends Control:
    var paper_owner: Control
    var outline_method: String
    func _ready() -> void:
        name="BrushSurface"
        mouse_filter=Control.MOUSE_FILTER_IGNORE
        set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    func configure(base: Color,wash: Color,progress: float,width: float,pressed: float=0.0) -> void:
        material.set_shader_parameter("base_tint",base)
        material.set_shader_parameter("wash_tint",wash)
        material.set_shader_parameter("progress",progress)
        material.set_shader_parameter("edge_width",clampf(0.7/maxf(width,1),0.001,0.025))
        material.set_shader_parameter("pixel_step",1.0/maxf(width,1))
        material.set_shader_parameter("paper_size",paper_owner.size)
        material.set_shader_parameter("press_tint",Color("#b9543e"))
        material.set_shader_parameter("press_amount",pressed)
        queue_redraw()
    func _draw() -> void:
        if not is_instance_valid(paper_owner) or paper_owner.size.x<4: return
        var points: PackedVector2Array=paper_owner.call(outline_method)
        var uv:=PackedVector2Array()
        for point in points: uv.append(point/paper_owner.size)
        draw_colored_polygon(points,Color.WHITE,uv,preload("res://assets/ui/paper_grain_v01.png"))

static func make_surface(owner_control: Control,outline_method: String="paper_outline") -> Control:
    if shader==null:
        shader=Shader.new()
        shader.code='''shader_type canvas_item;
render_mode unshaded;
uniform vec4 base_tint : source_color = vec4(1.0);
uniform vec4 wash_tint : source_color = vec4(0.7,0.3,0.2,1.0);
uniform vec4 press_tint : source_color = vec4(0.93,0.52,0.12,1.0);
uniform float press_amount = 0.0;
uniform float progress = 0.0;
uniform float edge_width = 0.04;
uniform float pixel_step = 0.003;
uniform vec2 paper_size = vec2(300.0,80.0);
varying vec4 tint;
void vertex(){ tint=COLOR; }
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float paper_noise(vec2 p){
    vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),f.x),
               mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0)),f.x),f.y);
}
void fragment(){
    vec4 grain=texture(TEXTURE,UV);
    vec2 px=UV*paper_size;
    float bristles=(sin(px.y*0.53)+sin(px.y*1.47)*0.35)*pixel_step*3.4;
    float edge=mix(-edge_width*2.0,1.0+edge_width*2.0,progress);
    float coverage=1.0-smoothstep(edge-edge_width,edge+edge_width,UV.x+bristles);
    if(progress<=0.0){coverage=0.0;}
    if(progress>=1.0){coverage=1.0;}
    // One opaque pigment per side. Only a one-pixel antialias touches the brush front.
    float fibre=dot(grain.rgb,vec3(0.299,0.587,0.114));
    // Only the original fine paper grain, lightly strengthened. No synthetic grit or dry stripes.
    float paper_relief=clamp(0.997+(fibre-0.8786),0.966,1.026);
    vec3 rough_paper=base_tint.rgb*paper_relief;
    // Hover is an opaque, pale solid paint. Paper texture belongs only to the rest state.
    vec3 face=mix(rough_paper,wash_tint.rgb,coverage);
    float alpha=mix(base_tint.a,wash_tint.a,coverage);
    if(press_amount>0.1){face=press_tint.rgb;alpha=press_tint.a;}
    COLOR=vec4(face,alpha*grain.a)*tint;
}'''
    var surface:=Surface.new()
    surface.paper_owner=owner_control
    surface.outline_method=outline_method
    surface.material=ShaderMaterial.new()
    surface.material.shader=shader
    return surface

static func make_ink_material() -> ShaderMaterial:
    if ink_shader==null:
        ink_shader=Shader.new()
        ink_shader.code='''shader_type canvas_item;
render_mode unshaded;
uniform vec4 base_ink : source_color = vec4(0.2,0.14,0.09,1.0);
uniform vec4 wash_ink : source_color = vec4(1.0,0.95,0.85,1.0);
uniform vec4 press_ink : source_color = vec4(0.2,0.14,0.09,1.0);
uniform vec2 paper_size = vec2(300.0,80.0);
uniform vec2 ink_offset = vec2(0.0);
uniform float progress = 0.0;
uniform float press_amount = 0.0;
varying vec2 ink_position;
void vertex(){ink_position=VERTEX+ink_offset;}
void fragment(){
    float pixel_step=1.0/max(paper_size.x,1.0);
    float bristles=(sin(ink_position.y*0.53)+sin(ink_position.y*1.47)*0.35)*pixel_step*3.4;
    float edge=mix(-pixel_step*1.4,1.0+pixel_step*1.4,progress);
    float coverage=step(ink_position.x/paper_size.x+bristles,edge);
    if(progress<=0.0){coverage=0.0;}
    if(progress>=1.0){coverage=1.0;}
    vec3 ink=mix(base_ink.rgb,wash_ink.rgb,coverage);
    if(press_amount>0.1){ink=press_ink.rgb;}
    COLOR.rgb=ink;
}'''
    var result:=ShaderMaterial.new()
    result.shader=ink_shader
    return result

static func sync_ink(material: ShaderMaterial,paper_size: Vector2,offset: Vector2,progress: float,pressed: float,base: Color,wash: Color) -> void:
    material.set_shader_parameter("paper_size",paper_size)
    material.set_shader_parameter("ink_offset",offset)
    material.set_shader_parameter("progress",progress)
    material.set_shader_parameter("press_amount",pressed)
    material.set_shader_parameter("base_ink",base)
    material.set_shader_parameter("wash_ink",wash)
    material.set_shader_parameter("press_ink",DARK_INK)

static func advance(current: float,wanted: float,delta: float) -> float:
    return move_toward(current,wanted,maxf(delta,0)/(ENTER_TIME if wanted>current else EXIT_TIME))
