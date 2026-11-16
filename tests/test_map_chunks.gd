extends SceneTree
var checks := 0
var failures := 0
func expect(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("FAIL: " + message)
func _initialize() -> void:
    call_deferred("run_checks")
func run_checks() -> void:
    var map = load("res://src/world_map.gd").new()
    root.add_child(map)
    map.set_process(false)
    for stage in [1,4,5,8,9,25]:
        map.set_view(Vector2(640,401),stage)
        expect(map.biome == ("ochre" if stage<5 else ("grove" if stage<9 else "volcano")),"biome derives from stage without resetting world position")
    map.set_view(Vector2(5000,-2300),9)
    var first: Array = map.chunk_content(Vector2i(10,-5)).duplicate(true)
    expect(not first.is_empty() and first[0].point.x >= 5120 and first[0].point.y < 0,"terrain exists at real positive and negative world coordinates")
    map.chunks.clear()
    expect(map.chunk_content(Vector2i(10,-5)) == first,"returning to a distant chunk rebuilds identical terrain")
    var lava := 0
    for x in range(-3,4):
        for prop in map.chunk_content(Vector2i(x,1)):
            if prop.kind == "lava": lava += 1
    expect(lava >= 4,"volcano has interior animated pits throughout streamed chunks")
    for i in range(80):
        map.set_view(Vector2(i*700,i*400),9)
        for key in map.visible_chunks(): map.chunk_content(key)
    expect(map.chunks.size() <= 64,"travel does not retain unbounded terrain cache")
    map.queue_free()
    await process_frame
    print("MAP_CHUNKS RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
