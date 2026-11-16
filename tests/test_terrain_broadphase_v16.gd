extends SceneTree
var checks:=0
var failures:=0
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var map=load("res://src/world_map.gd").new()
    var fixtures: Array=[]
    for x in range(-2,3):
        for y in range(-2,3): map.chunks[Vector2i(x,y)]=[]
    for i in range(80): fixtures.append({"id":"far_"+str(i),"kind":"stone","point":Vector2(300+i,320),"scale":1.0,"angle":0.0,"seed":i})
    fixtures.append({"id":"near","kind":"stone","point":Vector2(20,20),"scale":1.0,"angle":0.0,"seed":99})
    map.chunks[Vector2i.ZERO]=fixtures
    var nearby: Array=map._props_in(Rect2(-20,-20,80,80),"stone")
    expect(nearby.size()==1 and nearby[0].id=="near","far rocks are excluded before expensive polygon collision resolution")
    var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/v16_baseline.json"))
    var script:=GDScript.new()
    script.source_code=FileAccess.get_file_as_string(str(baseline.snapshot).path_join("src/world_map.gd"))
    expect(script.reload()==OK,"old collision algorithm loads read-only")
    var old=script.new()
    var overlap: Array=[{"id":"overlap_a","kind":"stone","point":Vector2(256,246),"scale":1.2,"angle":0.0,"seed":1},{"id":"overlap_b","kind":"stone","point":Vector2(238,322),"scale":0.9,"angle":0.0,"seed":2}]
    for instance in [map,old]:
        for x in range(-2,3):
            for y in range(-2,3): instance.chunks[Vector2i(x,y)]=[]
        instance.chunks[Vector2i.ZERO]=overlap.duplicate(true)
    var pushed: Vector2=map.move_body(Vector2(256,256),Vector2(256,256),33.0)
    expect(pushed.distance_to(old.move_body(Vector2(256,256),Vector2(256,256),33.0))<0.005,"initial embedded recovery can discover a second rock beyond the original sweep")
    for prop in overlap:
        var polygon: PackedVector2Array=map.stone_polygon(prop)
        var distance:=INF
        for i in range(polygon.size()): distance=minf(distance,Geometry2D.get_closest_point_to_segment(pushed,polygon[i],polygon[(i+1)%polygon.size()]).distance_to(pushed))
        expect(not Geometry2D.is_point_in_polygon(pushed,polygon) and distance>=32.99,"recovered body is not left overlapping either nearby stone")
    var rng:=RandomNumberGenerator.new();rng.seed=160016
    map.reset_terrain();map.chunks.clear();old.reset_terrain();old.chunks.clear()
    for i in range(160):
        var start: Vector2=Vector2(rng.randf_range(-900,1800),rng.randf_range(-900,1500))
        var end: Vector2=start+Vector2.from_angle(rng.randf_range(-PI,PI))*rng.randf_range(0,220)
        var radius: float=[9.0,18.0,33.0,56.0][i%4]
        expect(map.move_body(start,end,radius).distance_to(old.move_body(start,end,radius))<0.005,"broad phase preserves old wall/corner/dash resolution "+str(i))
    map.free();old.free()
    print("TERRAIN BROADPHASE V16 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
