extends SceneTree
class AuditHud extends "res://src/hud.gd":
    var heard: Array=[]
    func can_animate() -> bool: return false
    func play_ui(key: String) -> void: heard.append(key)
var checks:=0
var failures:=0
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var h:=AuditHud.new();root.add_child(h)
    h.setup(load("res://src/asset_library.gd").new());h.show_title()
    var button: Button=h.overlay.find_child("EnterCamp",true,false)
    h.heard.clear()
    button.mouse_entered.emit()
    button.mouse_entered.emit()
    expect(h.heard.count("button_hover")==1,"one pointer entry plays exactly one hover cue")
    button.mouse_exited.emit();button.mouse_entered.emit()
    expect(h.heard.count("button_hover")==2,"leaving and returning rearms hover audio")
    button.mouse_exited.emit();button.disabled=true;button.mouse_entered.emit()
    expect(h.heard.count("button_hover")==2,"disabled title actions never play hover audio")
    button.disabled=false;button.mouse_exited.emit();button.mouse_entered.emit()
    var has_brush: bool=button.get("brush_progress")!=null
    expect(has_brush,"home actions expose a directional brush fill rather than a uniform color fade")
    if has_brush:
        button.brush_progress=0.0;button._process(0.06)
        expect(button.brush_progress>0.25 and button.brush_progress<0.5,"brush moves across a fraction of the width during its short entrance")
        var surface: Control=button.find_child("BrushSurface",true,false)
        expect(surface!=null and surface.material is ShaderMaterial,"paper texture uses a dedicated directional fill material")
        if surface!=null: expect(absf(float(surface.material.get_shader_parameter("progress"))-float(button.brush_progress))<0.001,"visible brush front follows the real animation clock")
        button._process(0.20)
        expect(is_equal_approx(float(button.brush_progress),1.0),"brush completes quickly across the whole button")
        button.release_focus();button.mouse_exited.emit();button._process(0.15)
        expect(is_zero_approx(float(button.brush_progress)),"leaving restores the normal paper face")
        button.disabled=true;button._process(0.01)
        expect(is_zero_approx(float(button.brush_progress)),"disabled paper never retains a partial hover wash")
    var cue: Dictionary=load("res://src/ui_audio.gd").spec("button_hover")
    expect(not cue.is_empty() and float(cue.get("gain_db",0))<0 and int(cue.get("min_gap_ms",0))>=60,"hover cue has restrained volume and jitter debounce")
    var audio=load("res://src/ui_audio.gd").new()
    for key in ["scroll_unroll","parchment_burn","page_turn"]: audio._reserve_voice_at(key,2000)
    expect(audio._reserve_voice_at("button_hover",2000)==-1,"decorative hover leaves the last voice available for an action")
    expect(audio._reserve_voice_at("button_press",2000)==3,"click audio can still play while three longer page cues overlap")
    audio.free()
    h.show_cast()
    var start: Button=h.overlay.find_child("StartSling",true,false)
    var skin=start.find_child("InkFeedback",true,false)
    h.heard.clear();start.mouse_entered.emit();skin._process(0.06)
    expect(h.heard.count("button_hover")==1,"other page buttons share the hover sound binding")
    expect(skin.brush_progress>0.25 and skin.brush_progress<0.5,"other paper buttons share the directional entrance timing")
    start.mouse_exited.emit();start.hide();start.mouse_entered.emit()
    expect(h.heard.count("button_hover")==1,"hidden controls cannot produce surprise hover cues")
    await process_frame
    var back: Button=h.overlay.find_child("Back",true,false)
    var back_skin=back.find_child("InkFeedback",true,false)
    expect(back.get_theme_color("font_hover_color").r<0.4,"late paper skin setup does not leave white hover text on pale paper")
    back.mouse_entered.emit();back_skin._process(0.03)
    expect(back.get_theme_color("font_hover_color").r<0.4,"text stays dark before the brush reaches the letters")
    var paper=load("res://src/ui_paper.gd").new();paper.size=Vector2(1000,620)
    var points: PackedVector2Array=paper.outline()
    var deepest:=0.0
    for p in points:
        if p.x>200 and p.x<800 and p.y<28: deepest=maxf(deepest,p.y)
    expect(deepest>=10.0,"large parchment has visible tears rather than a barely wavy rectangle")
    expect(points==paper.outline(),"paper damage is stable and does not flicker between frames")
    for reveal in [0.04,0.10,0.5,1.0]:
        paper.reveal=reveal
        expect(not Geometry2D.triangulate_polygon(paper.outline()).is_empty(),"ragged paper remains drawable while the scroll opens")
    paper.free();h.queue_free();await process_frame
    print("UI BRUSH V22 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
