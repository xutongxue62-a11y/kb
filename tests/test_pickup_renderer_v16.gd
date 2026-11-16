extends SceneTree
var checks:=0
var failures:=0
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void:
    var available: bool=ResourceLoader.exists("res://src/pickup_renderer.gd")
    expect(available,"dense unit loot uses instanced rendering rather than thousands of draw submissions")
    if available:
        var renderer=load("res://src/pickup_renderer.gd").new()
        root.add_child(renderer)
        var drops: Array=[]
        for i in range(5000): drops.append({"kind":"coin" if i%2==0 else "xp","position":Vector2(i%100*7,i/100*5),"value":1})
        drops.append({"kind":"coin","position":Vector2(9999,9999),"value":1})
        drops.append({"kind":"blood","position":Vector2(180,180),"value":2.0})
        var before: Array=drops.duplicate(true)
        var bounds:=Rect2(-50,-50,900,500)
        renderer.sync(drops,bounds,0.0)
        expect(drops==before,"rendering never collects, merges, moves or discards physical loot")
        expect(renderer.batches.coin.multimesh.visible_instance_count==2500 and renderer.batches.xp.multimesh.visible_instance_count==2500,"all five thousand visible unit resources retain separate instances")
        expect(renderer.get_child_count()==3,"gold, XP and health each use one texture batch independent of unit count")
        expect(renderer.batches.blood.multimesh.visible_instance_count==1 and renderer.batches.blood.texture!=null,"the visible health pack uses its own bound texture batch")
        var coin_mesh: Mesh=renderer.batches.coin.multimesh.mesh
        var xp_mesh: Mesh=renderer.batches.xp.multimesh.mesh
        expect(coin_mesh is QuadMesh and xp_mesh is QuadMesh,"batched loot still uses a shared quad")
        expect(coin_mesh.size.y<0.0 and xp_mesh.size.y<0.0 and is_equal_approx(absf(coin_mesh.size.x),32.0) and is_equal_approx(absf(coin_mesh.size.y),36.0),"pickup quads use a negative height so the baked ground shadow stays below the icon")
        var xf: Transform2D=renderer.batches.coin.multimesh.get_instance_transform_2d(0)
        expect(xf.y.y>0.0 and is_equal_approx(xf.get_rotation(),0.0),"instance transforms stay upright; the mesh, not a Y-flip on each drop, corrects canvas space")
        for key in ["coin","xp"]:
            var icon: Texture2D=renderer.batches[key].texture
            expect(icon!=null,"cached "+key+" icon is bound to its batch")
            var image: Image=icon.get_image()
            var top_shadow:=0
            var bottom_shadow:=0
            for y in range(image.get_height()):
                for x in range(image.get_width()):
                    var pixel: Color=image.get_pixel(x,y)
                    if pixel.a>0.08 and pixel.a<0.45 and pixel.r<0.35:
                        if y<image.get_height()*0.4: top_shadow+=1
                        if y>image.get_height()*0.6: bottom_shadow+=1
            expect(bottom_shadow>top_shadow*3 and bottom_shadow>20,key+" artwork keeps its translucent ground shadow in the lower half, not mirrored onto the top")
        var first: Vector2=renderer.batches.coin.multimesh.get_instance_transform_2d(0).origin
        renderer.sync(drops,bounds,0.25)
        if DisplayServer.get_name()!="headless":
            expect(renderer.batches.coin.multimesh.get_instance_transform_2d(0).origin!=first,"batched resources retain their visual bob")
        else:
            print("NATIVE CHECK REQUIRED: dummy renderer does not expose multimesh transforms; visual bob is covered by the native run")
        renderer.sync([],bounds,0.5)
        expect(renderer.batches.coin.multimesh.visible_instance_count==0 and renderer.batches.xp.multimesh.visible_instance_count==0 and renderer.batches.blood.multimesh.visible_instance_count==0,"empty and collected fields draw no stale gold, XP or health instances")
        renderer.queue_free()
    print("PICKUP RENDERER V16 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
