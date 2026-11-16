extends Node2D
## Only presentation is batched. Every resource in Main.pickups remains a unit object.
const Visuals=preload("res://src/battle_visuals.gd")
var batches: Dictionary={}

func _init() -> void:
    var quad:=QuadMesh.new()
    # QuadMesh is authored in Y-up space. MultiMeshInstance2D draws in Y-down
    # canvas space, so a positive height would flip the baked ellipse onto the
    # top of the coin / XP gem ("影子倒天"). Negative height keeps the shadow
    # on the ground under the pickup without changing instance origins.
    quad.size=Vector2(32,-36)
    for key in ["xp","coin","blood"]:
        var batch:=MultiMeshInstance2D.new()
        batch.texture=_texture_for(key)
        batch.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
        batch.multimesh=MultiMesh.new()
        batch.multimesh.transform_format=MultiMesh.TRANSFORM_2D
        batch.multimesh.mesh=quad
        add_child(batch)
        batches[key]=batch

func _texture_for(key: String) -> Texture2D:
    if key=="coin":
        return Visuals.COIN_UNIT
    if key=="xp":
        return Visuals.XP_UNIT
    return _make_blood_texture()

func _make_blood_texture() -> Texture2D:
    var image:=Image.create(64, 64, false, Image.FORMAT_RGBA8)
    image.fill(Color(0,0,0,0))
    for y in range(64):
        for x in range(64):
            var p:=Vector2(x-32, y-32)
            var pack:=Vector2(p.x/18.0, p.y/22.0)
            if pack.length()<=1.0:
                var shade: float = 0.78 - pack.y*0.12
                image.set_pixel(x,y,Color(0.75*shade, 0.22, 0.24, 1.0))
            # white cross
            if absf(p.x)<=3.0 and absf(p.y)<=11.0:
                image.set_pixel(x,y,Color(0.95,0.92,0.9,1))
            if absf(p.y)<=3.0 and absf(p.x)<=11.0:
                image.set_pixel(x,y,Color(0.95,0.92,0.9,1))
    return ImageTexture.create_from_image(image)

func _pack_scale(drop: Dictionary) -> float:
    var kind:=str(drop.get("kind","xp"))
    if kind=="blood":
        return 1.08
    var value:=maxf(1.0, float(drop.get("value",1)))
    if value>=25.0:
        return 1.42
    if value>=10.0:
        return 1.22
    if value>=5.0:
        return 1.08
    return 0.92

func sync(drops: Array,bounds: Rect2,elapsed: float) -> void:
    var items: Dictionary={"coin":[],"xp":[],"blood":[]}
    for drop in drops:
        if not bounds.has_point(drop.position):
            continue
        var kind:=str(drop.get("kind","xp"))
        if not items.has(kind):
            kind="xp"
        items[kind].append(drop)
    for key in items:
        var mesh: MultiMesh=batches[key].multimesh
        var points: Array=items[key]
        if points.size()>mesh.instance_count:
            var capacity:=maxi(32,mesh.instance_count)
            while capacity<points.size(): capacity*=2
            mesh.instance_count=capacity
        mesh.visible_instance_count=points.size()
        for i in range(points.size()):
            var drop: Dictionary=points[i]
            var point: Vector2=drop.position
            var bob: float=sin(elapsed*4.0+point.x)*1.6
            var scale: float=_pack_scale(drop)
            mesh.set_instance_transform_2d(i,Transform2D(0.0,Vector2(scale,scale),0.0,point+Vector2(0,-2+bob)))
