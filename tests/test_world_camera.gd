extends SceneTree
var checks: int = 0
var failures: int = 0
func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)
func clear_route(world) -> void:
    var home := Vector2i(floori(world.player_position.x/512.0),floori(world.player_position.y/512.0))
    for y in range(home.y-2,home.y+3):
        for x in range(home.x-2,home.x+3):
            world.map_view.chunks[Vector2i(x,y)] = []
func _initialize() -> void:
    call_deferred("run_checks")
func run_checks() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/world_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    expect(world.has_method("visible_world_rect"), "world exposes camera visible world rectangle")
    if failures:
        world.queue_free()
        print("WORLD_CAMERA RESULT: %d checks, %d failures" % [checks,failures])
        quit(1)
        return
    world.start_run(true)
    world.clear_enemies()
    world.spawn_clock = 9999.0
    for heading in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
        world.player_position = Vector2(640,401)
        for step in range(150):
            clear_route(world)
            world.simulate(1.0/30.0, heading)
        expect(not world.FIELD.has_point(world.player_position), "can walk beyond original edge: " + str(heading))
        expect(world.world_camera.position.is_equal_approx(world.player_position), "camera follows after movement: " + str(heading))
        expect(world.visible_world_rect().get_center().is_equal_approx(world.player_position), "visible world rect follows player")
    for location in [Vector2(-12500,-8200),Vector2(45200,36000)]:
        world.player_position = location
        world.update_hud()
        var view: Rect2 = world.visible_world_rect()
        expect(view.size == Vector2(1280,800), "camera uses fixed logical viewport")
        for side in range(4):
            var point: Vector2 = world.offscreen_point(side)
            expect(not view.has_point(point) and view.grow(100).has_point(point), "spawn stays just outside far visible edge")
            expect(view.has_point(world.arrive_inside(point)), "entry point inside current view")
        for attempt in range(5):
            var egg: Vector2 = world.egg_point()
            expect(view.has_point(egg) and egg.distance_to(location)>=220, "eggs hatch near far player at safe distance")
        world.clear_enemies()
        world.spawn_enemy("hunter")
        expect(world.enemies.back()["position"].distance_to(location)<1000, "random spawn follows player")
        world.spawn_enemy("tank",location+Vector2(160,0))
        var tank: Dictionary = world.enemies.back()
        var initial_distance: float = tank["position"].distance_to(location)
        world.update_enemies(0.1)
        expect(tank["position"].distance_to(location)<initial_distance, "far enemy chases without old field clamp")
        world.clear_enemies()
        world.spawn_enemy("tank",Vector2(0,0))
        var stale: Dictionary = world.enemies.back()
        var before_kills: int = world.kills
        var before_xp: float = world.xp
        var hp: float = stale["hp"]
        world.update_enemies(0.0)
        expect(stale["position"].distance_to(location)<1100, "stale population recycles near view")
        expect(world.kills==before_kills and world.xp==before_xp and stale["hp"]==hp, "recycling gives no fake kill or reward or heal")
        world.clear_enemies()
        world.chest_marks = [{"position":location+Vector2(70,0),"age":2.0}]
        world.trial_mode = false
        var state: Dictionary = world.SessionState.capture(world)
        expect(world.save_store.write_run(state)["ok"] and world.continue_game(), "world positions survive validated disk save")
        expect(world.player_position.is_equal_approx(location) and world.world_camera.position.is_equal_approx(location), "restore preserves negative/large player and camera")
        expect(world.chest_marks[0]["position"]==location+Vector2(70,0), "restore preserves actual chest coordinate")
        expect(world.dodge_left==0.0, "restore clears transient dodge")
        world.player_position = location+Vector2(70,0)
        world.update_chests(0.01)
        world.try_present_chest()
        expect(world.chest_marks.is_empty() and world.upgrade_pending, "actual chest beyond old field is collectible")
        world.start_run(true)
        world.clear_enemies()
        world.spawn_clock = 9999.0
    world.player_position = Vector2(10,10)
    var origin: Vector2 = world.player_position
    world.request_dodge(Vector2.LEFT)
    clear_route(world)
    world.simulate(0.2,Vector2.ZERO)
    expect(world.player_position.distance_to(origin-Vector2(140,0))<0.01, "dodge crosses old arena edge")
    world.impact_strength=2.0
    clear_route(world)
    world.simulate(0.01,Vector2.ZERO)
    expect(world.position==Vector2.ZERO and world.world_camera.offset.length()>0, "screenshake offsets camera without moving parent world")
    expect(world.hud is CanvasLayer, "HUD stays in screen-space layer")
    world.queue_free()
    print("WORLD_CAMERA RESULT: %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)

