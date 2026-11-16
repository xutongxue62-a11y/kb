extends SceneTree
var world

func _initialize() -> void:
    call_deferred("measure")

func render_samples(count: int) -> Array:
    var values: Array = []
    for i in range(count):
        var start: int = Time.get_ticks_usec()
        world.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        values.append((Time.get_ticks_usec()-start)/1000.0)
    values.sort()
    return values

func summary(values: Array) -> Dictionary:
    return {"median":values[values.size()/2],"p95":values[floori(values.size()*0.95)],"max":values[-1]}

func measure() -> void:
    root.size = Vector2i(1280,800)
    Engine.max_fps = 0
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/loot_benchmark_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.settings.autosave = false
    world.set_physics_process(false)
    world.start_run(false)
    world.departure_left = 0
    world.hud.hide_menu()
    world.clear_enemies()
    world.clear_weapons()
    world.pickups.clear()
    world.coins = 0
    world.xp = 0
    await process_frame
    var empty: Array = await render_samples(60)
    var bounds: Rect2 = world.visible_world_rect().grow(-50)
    for i in range(5000):
        var at := bounds.position + Vector2(fmod(i*17.37,bounds.size.x),fmod(i*13.91,bounds.size.y))
        if at.distance_squared_to(world.player_position)<18000: at.y = bounds.position.y + 20
        world.pickups.append({"kind":"coin" if i%2==0 else "xp","position":at,"value":1})
    var update: Array = []
    for i in range(120):
        var start: int = Time.get_ticks_usec()
        world.update_pickups(1.0/60.0)
        update.append((Time.get_ticks_usec()-start)/1000.0)
    update.sort()
    var full: Array = await render_samples(120)
    var visible: int = world.pickups.filter(func(d):return world.visible_world_rect().has_point(d.position)).size()
    var intact: bool = world.pickups.size()==5000 and world.coins==0 and world.xp==0.0
    var result := {"count":world.pickups.size(),"visible":visible,"uncollected_intact":intact,"empty_native_frame_ms":summary(empty),"5000_native_frame_ms":summary(full),"5000_update_ms":summary(update),"notes":"Native OpenGL rendered frames, vsync off, no movie encoding. End-to-end frame samples include engine scheduling; not a general hardware guarantee."}
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://previews/character_loot_v13_v4/stress_5000_visible.png")
    var file := FileAccess.open("res://previews/character_loot_v13_v4/performance.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(result,"  "))
    file.close()
    print("LOOT BENCHMARK: ",JSON.stringify(result))
    quit(0 if intact and visible==5000 else 1)
