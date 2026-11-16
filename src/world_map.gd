extends Node2D

const CHUNK_SIZE := 512
const LAVA_DPS := 2.0
const STONE_POINTS := [Vector2(-24,5),Vector2(-17,-9),Vector2(-3,-14),Vector2(18,-9),Vector2(27,4),Vector2(12,12),Vector2(-9,11)]
const BIOMES := {"ochre":"荒草原", "grove":"蕨叶林地", "volcano":"熔岩荒原"}
var biome := "ochre"
var view_center := Vector2(640, 401)
var view := Rect2(0, 1, 1280, 800)
var clock := 0.0
var animate_world := true
var chunks: Dictionary = {}
var floors: Dictionary = {}
var stone_health: Dictionary = {}
var _draw_accum := 0.0
var _poly_cache: Dictionary = {}
var _last_view_chunks := Vector4i(99999, 99999, 99999, 99999)

static func biome_for_wave(stage: int) -> String:
    return "volcano" if stage >= 9 else ("grove" if stage >= 5 else "ochre")

func set_view(center: Vector2, stage: int) -> void:
    view_center = center
    view = Rect2(center - Vector2(640,400),Vector2(1280,800))
    var next: String = biome_for_wave(stage)
    var dirty := false
    if next != biome:
        biome = next
        chunks.clear()
        _poly_cache.clear()
        dirty = true
    var home := Vector2i(floori(center.x / CHUNK_SIZE),floori(center.y / CHUNK_SIZE))
    if chunks.size() > 40:
        for key in chunks.keys():
            if absi(key.x-home.x) > 3 or absi(key.y-home.y) > 3:
                chunks.erase(key)
                dirty = true
    var view_chunks := Vector4i(floori(view.position.x / CHUNK_SIZE), floori(view.position.y / CHUNK_SIZE), floori(view.end.x / CHUNK_SIZE), floori(view.end.y / CHUNK_SIZE))
    if dirty or view_chunks != _last_view_chunks:
        _last_view_chunks = view_chunks
        queue_redraw()

func _process(delta: float) -> void:
    if not animate_world: return
    clock += delta
    _draw_accum += delta
    if _draw_accum >= 0.07:
        _draw_accum = 0.0
        queue_redraw()

func visible_chunks() -> Array[Vector2i]:
    var keys: Array[Vector2i] = []
    for y in range(floori(view.position.y / CHUNK_SIZE), floori(view.end.y / CHUNK_SIZE)+1):
        for x in range(floori(view.position.x / CHUNK_SIZE), floori(view.end.x / CHUNK_SIZE)+1):
            keys.append(Vector2i(x,y))
    return keys

func chunk_content(key: Vector2i) -> Array:
    if chunks.has(key): return chunks[key]
    var random := RandomNumberGenerator.new()
    random.seed = hash("caveman_terrain_v10_%d_%d_%s" % [key.x,key.y,biome])
    var origin := Vector2(key) * CHUNK_SIZE
    var props: Array = []
    for i in range(11):
        var point := origin + Vector2(random.randf_range(22,490),random.randf_range(22,490))
        var kind := "stone" if i < 2 else ("leaf" if i < 8 else "grass")
        var prop: Dictionary={"kind":kind,"point":point,"angle":random.randf_range(-PI,PI),"scale":random.randf_range(0.7,1.4),"seed":random.randi_range(0,9999)}
        if kind=="stone": prop["id"]="%s:%d:%d:%d" % [biome,key.x,key.y,i]
        props.append(prop)
    if biome == "volcano":
        var at := origin + Vector2(random.randf_range(110,402),random.randf_range(110,402))
        if at.distance_to(Vector2(640,401)) > 165:
            props.append({"kind":"lava","point":at,"radius":random.randf_range(48,85),"seed":random.randi_range(0,9999)})
    chunks[key] = props
    return props

func _floor_textures() -> Array:
    if floors.has(biome): return floors[biome]
    var source: Texture2D = load("res://assets/maps/v10/" + biome + ".png")
    var image: Image = source.get_image()
    # Only the open interior is a ground material, never the illustrated frame.
    var sample: Image = image.get_region(Rect2i(image.get_width()/4,image.get_height()/4,image.get_width()/2,image.get_height()/2))
    sample.resize(CHUNK_SIZE,CHUNK_SIZE,Image.INTERPOLATE_BILINEAR)
    var variants: Array = []
    for i in range(4):
        var tile: Image = sample.duplicate()
        if i & 1: tile.flip_x()
        if i & 2: tile.flip_y()
        variants.append(ImageTexture.create_from_image(tile))
    floors[biome] = variants
    return variants

func _draw() -> void:
    var textures := _floor_textures()
    var keys := visible_chunks()
    for key in keys:
        var parity: int = posmod(key.x,2) + posmod(key.y,2) * 2
        draw_texture_rect(textures[parity],Rect2(Vector2(key)*CHUNK_SIZE,Vector2.ONE*CHUNK_SIZE),false)
    for key in keys:
        for prop in chunk_content(key):
            match prop.kind:
                "stone":
                    if stone_health.get(stone_id(prop),1)>0: _stone(prop)
                    else: _rubble(prop)
                "grass": _grass(prop)
                "leaf": _leaf(prop)
                "lava": _lava(prop)

func _stone(prop: Dictionary) -> void:
    draw_set_transform(prop.point,prop.angle * 0.10,Vector2.ONE * prop.scale)
    var points := PackedVector2Array(STONE_POINTS)
    var shade := Color("#bba081") if biome == "ochre" else (Color("#8e9170") if biome == "grove" else Color("#674e4f"))
    draw_colored_polygon(points,shade.darkened(0.10))
    draw_colored_polygon(PackedVector2Array([points[0],points[1],points[2],points[3],Vector2(8,1)]),shade.lightened(0.15))
    points.append(points[0])
    draw_polyline(points,Color("#5a493d"),1.7,true)
    draw_line(Vector2(-15,-7),Vector2(-3,-10),shade.lightened(0.4),1.3,true)
    var hp: float=float(stone_health.get(stone_id(prop),stone_max_hp(prop)))
    if hp<stone_max_hp(prop):
        draw_polyline(PackedVector2Array([Vector2(-4,-12),Vector2(1,-3),Vector2(-5,2),Vector2(5,9)]),Color("#514239"),2.2,true)
        if hp<stone_max_hp(prop)*0.5:
            draw_polyline(PackedVector2Array([Vector2(21,-5),Vector2(9,0),Vector2(12,6)]),Color("#514239"),2,true)
    draw_set_transform(Vector2.ZERO)

func _rubble(prop: Dictionary) -> void:
    draw_set_transform(prop.point,0,Vector2.ONE*float(prop.scale))
    for i in range(4):
        var at:=Vector2((i-1.5)*10,sin(i*3.1+prop.seed)*4)
        draw_colored_polygon(PackedVector2Array([at+Vector2(-4,2),at+Vector2(-1,-3),at+Vector2(4,1)]),Color("#99836c",0.7))
    draw_set_transform(Vector2.ZERO)

func stone_id(prop: Dictionary) -> String:
    return str(prop.get("id","%s:p%.3f:%.3f:%s" % [biome,prop.point.x,prop.point.y,prop.get("seed",0)]))

func stone_max_hp(prop: Dictionary) -> float:
    return 14.0+8.0*float(prop.get("scale",1.0))

func stone_targets(bounds: Rect2) -> Array:
    var targets: Array=[]
    for prop in _props_in(bounds,"stone"):
        if not bounds.grow(40).has_point(prop.point): continue
        var id: String=stone_id(prop)
        var hp: float=float(stone_health.get(id,stone_max_hp(prop)))
        targets.append({"id":"stone:"+id,"stone_id":id,"kind":"stone","stone":true,"position":prop.point,"hp":hp,"max_hp":stone_max_hp(prop),"radius":29.0*float(prop.scale),"elite":false,"velocity":Vector2.ZERO})
    return targets

func damage_stone(target: Dictionary,amount: float) -> Dictionary:
    var id: String=str(target.get("stone_id",""))
    if id.is_empty() or not is_finite(amount) or amount<=0: return {"hit":false,"destroyed":false}
    var hp: float=float(stone_health.get(id,target.max_hp))
    if hp<=0:
        target.hp=0.0
        return {"hit":false,"destroyed":false}
    hp=maxf(0,hp-amount)
    stone_health[id]=hp
    target.hp=hp
    queue_redraw()
    return {"hit":true,"destroyed":hp<=0,"position":target.position}

func capture_terrain() -> Dictionary:
    return {"stone_health":stone_health.duplicate()}

func restore_terrain(state: Dictionary) -> void:
    stone_health=state.get("stone_health",{}).duplicate()
    queue_redraw()

func reset_terrain() -> void:
    stone_health.clear()
    _poly_cache.clear()
    queue_redraw()

func _leaf(prop: Dictionary) -> void:
    draw_set_transform(prop.point,prop.angle + sin(clock * 0.45 + prop.seed) * 0.025,Vector2.ONE*prop.scale)
    var color := Color("#b69b56") if biome != "volcano" else Color("#b47b4c")
    draw_colored_polygon(PackedVector2Array([Vector2(-10,0),Vector2(-2,-5),Vector2(10,-1),Vector2(2,5)]),color)
    draw_polyline(PackedVector2Array([Vector2(-12,1),Vector2(0,0),Vector2(10,-1)]),Color("#6b6744"),1.2,true)
    draw_set_transform(Vector2.ZERO)

func _grass(prop: Dictionary) -> void:
    draw_set_transform(prop.point,0,Vector2.ONE*prop.scale)
    var color := Color("#8c9a69") if biome != "volcano" else Color("#a97d55")
    var sway: float = sin(clock * 1.1 + prop.seed) * 2
    for i in range(3):
        var x: float = (i-1)*6
        draw_colored_polygon(PackedVector2Array([Vector2(x-3,5),Vector2(x-4+sway,-9-i*3),Vector2(x+4,5)]),color)
    draw_set_transform(Vector2.ZERO)

func _lava(prop: Dictionary) -> void:
    var at: Vector2 = prop.point
    var radius: float = prop.radius
    var rim := PackedVector2Array()
    for i in range(28):
        var a: float = TAU * i / 28
        var rough: float = 1 + sin(i*2.7+prop.seed)*0.09
        var direction := Vector2(cos(a),sin(a)*0.64)
        rim.append(at+direction*radius*rough)
    draw_colored_polygon(rim,Color("#3c3033"))
    draw_colored_polygon(lava_polygon(prop),Color("#d66b31"))
    rim.append(rim[0])
    draw_polyline(rim,Color("#8d4a36"),3.0,true)
    for i in range(5):
        var phase: float = fmod(clock*0.45+i*0.197+prop.seed*0.001,1)
        var point := at + Vector2(sin(i*3.7+prop.seed)*radius*0.52,cos(i*1.7+prop.seed)*radius*0.29)
        var bubble: float = 2 + sin(phase*PI)*6
        draw_circle(point,bubble,Color("#f5ab43"),true,-1,true)
        draw_arc(point,bubble,-2.7,-0.3,12,Color("#ffdb76"),1.4,true)
        if phase > 0.82:
            var pop: float = (phase-0.82)/0.18
            for n in range(3):
                var angle: float = -2.5+n*0.8
                var spark: Vector2 = point+Vector2.from_angle(angle)*(5+pop*15)
                draw_circle(spark,(1-pop)*2.3,Color("#ffd064"),true,-1,true)

# Sample adjacent chunks as decorations can extend across a chunk boundary.
func _props_in(bounds: Rect2, kind: String, narrow_stones: bool=true) -> Array:
    var result: Array = []
    var area := bounds.grow(120.0)
    for y in range(floori(area.position.y / CHUNK_SIZE), floori(area.end.y / CHUNK_SIZE)+1):
        for x in range(floori(area.position.x / CHUNK_SIZE), floori(area.end.x / CHUNK_SIZE)+1):
            for prop in chunk_content(Vector2i(x,y)):
                if prop.kind == kind and (kind!="stone" or stone_health.get(stone_id(prop),1)>0):
                    # Every stone vertex is <28 local units from its centre.
                    # 32*scale conservatively contains rotation and AA margins.
                    # Query bounds already contain the body's radius and full sweep.
                    if kind=="stone" and narrow_stones and not bounds.grow(32.0*float(prop.scale)).has_point(prop.point):
                        continue
                    result.append(prop)
    return result

func stone_polygon(prop: Dictionary) -> PackedVector2Array:
    var id: String = stone_id(prop)
    if _poly_cache.has(id):
        return _poly_cache[id]
    var points := PackedVector2Array()
    for point in STONE_POINTS:
        points.append(prop.point + (point * float(prop.scale)).rotated(float(prop.angle) * 0.10))
    _poly_cache[id] = points
    return points

func _resolve_body(at: Vector2, radius: float, polygons: Array) -> Vector2:
    var result := at
    for pass_index in range(12):
        var changed := false
        for polygon in polygons:
            var nearest := Vector2.ZERO
            var distance := INF
            for i in range(polygon.size()):
                var candidate := Geometry2D.get_closest_point_to_segment(result,polygon[i],polygon[(i+1)%polygon.size()])
                var length_sq := candidate.distance_squared_to(result)
                if length_sq < distance:
                    distance = length_sq
                    nearest = candidate
            var inside := Geometry2D.is_point_in_polygon(result,polygon)
            distance = sqrt(distance)
            if inside or distance < radius - 0.0001:
                var normal: Vector2 = (nearest-result).normalized() if inside else (result-nearest).normalized()
                if normal.is_zero_approx():
                    # On an edge: its outward normal is determined by the polygon center.
                    var center := Vector2.ZERO
                    for point in polygon: center += point
                    normal = (nearest-center/float(polygon.size())).normalized()
                result += normal * (distance+radius+0.002 if inside else radius-distance+0.002)
                changed = true
        if not changed: break
    return result

func move_body(from: Vector2, to: Vector2, radius: float) -> Vector2:
    var polygons: Array = []
    var swept: Rect2=Rect2(from,Vector2.ZERO).expand(to).grow(radius)
    for prop in _props_in(swept,"stone"):
        polygons.append(stone_polygon(prop))
    var result := _resolve_body(from,maxf(radius,0.01),polygons)
    if result.distance_squared_to(from)>0.0000001:
        # Spawn/restore can begin embedded. Recovery pushes can reach beyond the
        # original sweep, so preserve the full legacy neighbourhood for this path.
        polygons.clear()
        for prop in _props_in(swept,"stone",false): polygons.append(stone_polygon(prop))
        result=_resolve_body(from,maxf(radius,0.01),polygons)
    var displacement := to-from
    var steps := maxi(1,ceili(displacement.length()/6.0))
    var step := displacement/float(steps)
    for i in range(steps):
        # Preserve the free component when the other axis hits an obstacle.
        # Binary contact search avoids pushing a dash around/through a corner.
        for axis_step in [Vector2(step.x,0),Vector2(0,step.y)]:
            if axis_step.is_zero_approx(): continue
            var candidate: Vector2 = result+axis_step
            if _resolve_body(candidate,radius,polygons).distance_squared_to(candidate) < 0.0000001:
                result = candidate
                continue
            var low := 0.0
            var high := 1.0
            for search in range(12):
                var middle := (low+high)*0.5
                candidate = result+axis_step*middle
                if _resolve_body(candidate,radius,polygons).distance_squared_to(candidate) < 0.0000001:
                    low = middle
                else:
                    high = middle
            result += axis_step*low
    return result

func lava_polygon(prop: Dictionary) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(28):
        var angle: float = TAU * i / 28
        var rough: float = 1 + sin(i*2.7+prop.seed)*0.09
        points.append(prop.point + Vector2(cos(angle),sin(angle)*0.64)*(float(prop.radius)-11.0)*rough)
    return points

func lava_damage_at(at: Vector2) -> float:
    for prop in _props_in(Rect2(at,Vector2.ZERO),"lava"):
        if Geometry2D.is_point_in_polygon(at,lava_polygon(prop)):
            return LAVA_DPS
    return 0.0
