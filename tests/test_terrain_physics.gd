extends SceneTree
var checks := 0
var failures := 0
func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)
func _initialize() -> void:
    call_deferred("run_checks")
func run_checks() -> void:
    var map = load("res://src/world_map.gd").new()
    expect(map.has_method("move_body"), "terrain blocks moving bodies")
    expect(map.has_method("lava_damage_at"), "lava exposes neutral damage sampling")
    if failures:
        map.free()
        print("TERRAIN RESULT: %d checks, %d failures" % [checks,failures])
        quit(1)
        return
    root.add_child(map)
    map.set_process(false)
    # Controlled actual chunk props: shared drawing/physics data, negative seam.
    for x in range(-3,3):
        for y in range(-3,3): map.chunks[Vector2i(x,y)] = []
    var center := Vector2(-512,-512)
    map.chunks[Vector2i(-1,-1)] = [{"kind":"stone","point":center,"scale":1.0,"angle":0.0,"seed":0}]
    for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
        var at: Vector2 = map.move_body(center+direction*100,center-direction*100,10)
        expect((at-center).dot(direction)>18, "swept dash blocks stone from " + str(direction))
    var slide: Vector2 = map.move_body(center+Vector2(-80,-4),center+Vector2(60,55),10)
    expect(slide.y > center.y+40, "oblique motion slides along stone")
    var resolved: Vector2 = map.move_body(center,center,18)
    expect(resolved.distance_to(center)>25, "spawn/load overlap resolves")
    expect(map.move_body(resolved,resolved,18).distance_to(resolved)<0.01, "resolved body remains stable")
    var clear := center+Vector2(150,100)
    expect(map.move_body(clear,clear,18)==clear, "clear resting bodies do not teleport")
    map.chunks[Vector2i(-1,-1)].append({"kind":"lava","point":clear,"radius":65.0,"seed":3})
    expect(map.lava_damage_at(clear)==2.0, "lava center has fixed neutral DPS")
    expect(map.lava_damage_at(clear+Vector2(0,60))==0.0, "outside ellipse has no damage")
    map.chunks.clear()
    var props: Array = map.chunk_content(Vector2i(-7,3)).duplicate(true)
    map.move_body(Vector2(-3600,1600),Vector2(-3500,1700),19)
    map.chunks.clear()
    expect(map.chunk_content(Vector2i(-7,3))==props, "physics preserves deterministic props")
    map.queue_free()
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/terrain_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.start_run(true)
    world.clear_enemies()
    world.spawn_clock = 9999.0
    world.stats["regen"] = 0.0
    world.stats["reduction"] = 0.99
    world.stats["dodge"] = 1.0
    world.stats["damage_multiplier"] = 100.0
    world.stats["crit_chance"] = 1.0
    world.map_view.chunks.clear()
    for x in range(-2,5):
        for y in range(-2,5): world.map_view.chunks[Vector2i(x,y)] = []
    var at := Vector2(640,401)
    world.map_view.chunks[Vector2i(1,0)] = [{"kind":"lava","point":at,"radius":100.0,"seed":0}]
    world.spawn_enemy("tank",at+Vector2(30,0))
    var enemy: Dictionary = world.enemies.back()
    enemy["dodge"] = 1.0
    var hp: float = world.player_hp
    var ehp: float = enemy["hp"]
    world.invulnerable = 0.0
    world.update_terrain_damage(0.25)
    expect(is_equal_approx(hp-world.player_hp,0.5), "lava bypasses hero armor and random dodge")
    expect(is_equal_approx(ehp-enemy["hp"],0.5), "same neutral DPS bypasses enemy dodge and player multipliers")
    for blocker in ["paused","shop_open","upgrade_pending","stats_open","player_frozen","wave_closing"]:
        world.set(blocker,true)
        hp = world.player_hp
        ehp = enemy["hp"]
        world.update_terrain_damage(1.0)
        expect(world.player_hp==hp and enemy["hp"]==ehp,"terrain freezes for "+blocker)
        world.set(blocker,false)
    world.departure_left = 1.0
    hp = world.player_hp
    world.update_terrain_damage(1.0)
    expect(world.player_hp==hp,"ready countdown freezes lava")
    world.departure_left = 0.0
    world.invulnerable = 0.2
    world.update_terrain_damage(0.1)
    expect(world.player_hp==hp,"Shift immunity protects hero against lava")
    enemy["hp"] = 0.1
    var kills: int = world.kills
    var drops: int = world.pickups.size()
    world.update_terrain_damage(0.1)
    var death_drops: int = world.pickups.size()
    world.update_terrain_damage(0.1)
    var allowed_values := {1: true, 5: true, 10: true, 25: true, 2: true}
    expect(world.kills==kills+1 and death_drops>drops and world.pickups.size()==death_drops and world.pickups.all(func(d):return allowed_values.has(int(round(float(d.value))))),"lava death rewards individual units exactly once")
    world.clear_enemies()
    world.map_view.chunks.clear()
    for x in range(-2,5):
        for y in range(-2,5): world.map_view.chunks[Vector2i(x,y)] = []
    # Isolate collision from the now-intentional automatic mining behavior.
    world.clear_weapons()
    world.grant_weapon("sling")
    world.weapon_runtime.sling.cooldown=999.0
    world.map_view.chunks[Vector2i(1,0)] = [{"kind":"stone","point":at,"scale":1.4,"angle":2.0,"seed":0}]
    world.player_position = at-Vector2(100,0)
    world.hero.position = world.player_position
    world.invulnerable = 0.0
    world.request_dodge(Vector2.RIGHT)
    world.simulate(0.2,Vector2.ZERO)
    expect(world.player_position.x < at.x-25,"actual Shift dash stops at transformed stone")
    world.spawn_enemy("hunter",at+Vector2(100,0))
    enemy = world.enemies.back()
    enemy["speed_multiplier"] = 30.0
    world.update_enemies(0.2)
    expect(enemy["position"].x > at.x+25,"actual fast enemy movement cannot cross stone")
    expect(enemy["view"].has_method("_draw_ground_shadow"),"monster view owns grounded shadow")
    world.spawn_enemy("tank",at)
    enemy = world.enemies.back()
    expect(enemy["position"].distance_to(at)>30,"spawn resolves stone overlap")
    world.player_position = at
    var captured: Dictionary = world.SessionState.capture(world,false)
    expect(world.save_store.write_run(captured)["ok"] and world.continue_game(),"overlapping old save loads")
    expect(world.player_position.distance_to(at)>30,"load resolves hero inside stone")
    world.queue_free()
    await process_frame
    print("TERRAIN RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
