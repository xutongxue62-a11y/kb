extends SceneTree
var checks:=0
var failures:=0
class CanvasRecorder extends RefCounted:
    var commands: Array=[]
    func draw_set_transform(at: Vector2,angle: float=0,scale_value: Vector2=Vector2.ONE) -> void:
        commands.append({"shape":"transform","at":at,"angle":angle,"scale":scale_value})
    func draw_texture_rect(texture: Texture2D,rect: Rect2,_tile: bool,tint: Color=Color.WHITE) -> void:
        commands.append({"shape":"texture","texture":texture,"rect":rect,"tint":tint})
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var fx=load("res://src/effects.gd").new()
    for i in range(20): fx.comic_word(Vector2(i*12,0),"雷",Color.WHITE)
    expect(fx.particles.filter(func(p):return p.kind=="word").size()<=6,"repeated decorative words cannot bury the actual impact art")
    fx.free()
    var available: bool=ResourceLoader.exists("res://src/combat_art.gd")
    expect(available,"combat uses distinct cached ink artwork instead of repeated primitive rings")
    if available:
        var art=load("res://src/combat_art.gd")
        var signatures: Array=[]
        for family in ["wood","axe","blade","stone","powder","rune","spear","hammer","bonebow","fire","drum","crystal","lightning","pet"]:
            var texture: Texture2D=art.texture(family,0.35)
            expect(texture!=null and texture==art.texture(family,0.35),family+" reuses cached effect art")
            if texture==null: continue
            var image: Image=texture.get_image()
            var bounds: Rect2i=image.get_used_rect()
            expect(bounds.has_area() and bounds.position.x>=2 and bounds.position.y>=2 and bounds.end.x<image.get_width()-1 and bounds.end.y<image.get_height()-1,family+" has clean transparent margins")
            signatures.append(hash(image.get_data()))
            var canvas:=CanvasRecorder.new()
            art.draw(canvas,family,Vector2(90,70),42.0,0.35,Vector2.UP)
            expect(canvas.commands.filter(func(c):return c.shape=="texture").size()==1,family+" submits one cached quad rather than many per-frame polygons")
        var unique: Dictionary={}
        for signature in signatures: unique[signature]=true
        expect(unique.size()==14,"all fourteen effect families have different silhouettes and shading")
        for i in range(100): art.texture("fire",i*0.37)
        expect(art.cache.size()<=16*6,"effect cache stays bounded across arbitrary lifetime values")
    var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/v16_baseline.json"))
    var previous:=GDScript.new()
    previous.source_code=FileAccess.get_file_as_string(str(baseline.snapshot).path_join("src/weapon_art.gd"))
    expect(previous.reload()==OK,"previous stage art loads read-only for visible-change comparison")
    var old=previous.new()
    var library=load("res://src/asset_library.gd").new()
    var current=load("res://src/weapon_art.gd")
    for id in library.Catalog.IDS:
        for stage in [1,2]:
            var base: Texture2D=library.texture("weapons",id)
            var a: Image=old.evolved_texture(base,id,stage).get_image()
            var b: Image=current.evolved_texture(base,id,stage).get_image()
            var changed:=0
            for y in range(a.get_height()):
                for x in range(a.get_width()):
                    var p: Color=a.get_pixel(x,y)
                    var q: Color=b.get_pixel(x,y)
                    if absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)+absf(p.a-q.a)>0.12: changed+=1
            expect(changed>=80,id+" tier "+str(stage)+" receives visible material/construction upgrades beyond the old small gem")
    print("COMBAT ART V16 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
