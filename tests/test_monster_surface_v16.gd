extends SceneTree
var checks:=0
var failures:=0
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void:
    var library=load("res://src/asset_library.gd").new()
    for kind in library.Catalog.DINOS:
        var view=load("res://src/dino_view.gd").new()
        view.setup(library,kind,float(library.Catalog.DINOS[kind].size),false)
        var scale_before: Vector2=view.base_scale
        var surface: Sprite2D=view.find_child("SurfaceArt",true,false) as Sprite2D
        expect(surface!=null,kind+" has a dedicated scale/armor/skin detail layer")
        if surface!=null:
            expect(surface.texture!=null and surface.texture.get_size()==view.sprite.texture.get_size(),kind+" details share the original padded body canvas")
            expect(surface.material.get_shader_parameter("body_mask")==view.sprite.texture,kind+" material details are clipped to the original body silhouette")
            for velocity in [Vector2(-120,0),Vector2(120,0)]:
                view.animate(velocity,0.1)
                expect(surface.flip_h==view.sprite.flip_h,kind+" surface follows both facing directions")
            expect(view.base_scale==scale_before,kind+" surface does not change combat/body scale")
        view.free()
    print("MONSTER SURFACE V16 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
