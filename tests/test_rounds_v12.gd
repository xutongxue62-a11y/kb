extends SceneTree
var checks:=0
var failures:=0
func expect(ok: bool,message: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        print("FAIL: "+message)
func _initialize() -> void: call_deferred("run_checks")
func run_checks() -> void:
    var world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/rounds_v12_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.start_run(true,"base")
    expect(world.enemies.is_empty(),"a new run begins on an entirely empty battlefield")
    world.clear_enemies()
    world.spawn_clock=999
    world.invulnerable=999
    world.spawn_enemy("tank",world.player_position+Vector2(300,0))
    world.update_weapons(0.01)
    world.wave_elapsed=29.99
    var kills: int=world.kills
    world.simulate(0.02,Vector2.ZERO)
    expect(world.wave_closing and not world.shop_open,"round end visibly pauses before the shop")
    expect(world.enemies.is_empty() and world.projectiles.is_empty() and world.burning_fields.is_empty(),"round finish removes all live threats")
    expect(world.kills==kills and world.pickups.is_empty(),"dismissed living monsters grant no fake kills or resources")
    expect(world.is_loadout_visible() and world.player_frozen,"character and weapons stay visible during the brief finish")
    var before: Vector2=world.player_position
    var time: float=world.elapsed
    var poses: Dictionary={}
    for id in world.weapon_views: poses[id]=[world.weapon_views[id].position,world.weapon_views[id].rotation]
    world.simulate(0.3,Vector2.RIGHT)
    expect(world.wave_closing and not world.shop_open and world.player_position==before and world.elapsed==time,"finish pause advances no combat or movement time")
    for id in poses:
        expect(world.weapon_views[id].position==poses[id][0] and world.weapon_views[id].rotation==poses[id][1],"weapon poses remain frozen before camp")
    var saved: Dictionary=world.SessionState.capture(world,false)
    expect(world.save_store.write_run(saved).ok and world.continue_game(),"finish pause can be saved and restored")
    expect(world.wave_closing and not world.shop_open and world.player_frozen,"restoring a finish cannot start a live wave or skip camp")
    world.simulate(0.7,Vector2.RIGHT)
    expect(world.shop_open and not world.wave_closing and world.player_position==before,"shop opens only after the finish pause")
    world.leave_shop()
    expect(world.wave==2 and world.enemies.is_empty() and world.projectiles.is_empty() and world.effects.particles.is_empty(),"next wave starts without old enemies, shots or effects")
    world.invulnerable=999
    world.simulate(0.61,Vector2.ZERO)
    expect(not world.enemies.is_empty(),"new enemies arrive only after the opening delay")
    expect(world.enemies.all(func(e): return not world.visible_world_rect().has_point(e.position) or e.state=="egg"),"new enemies arrive from beyond the camera or through a visible hatch")
    world.begin_round(5)
    expect(world.enemies.is_empty(),"Boss round also begins empty rather than popping beside the player")
    world.simulate(0.61,Vector2.ZERO)
    expect(world.enemies.any(func(e):return e.kind=="boss"),"delayed Boss entry is still guaranteed")
    expect(world.enemies.all(func(e):return not world.visible_world_rect().has_point(e.position)),"Boss enters from offscreen")
    world.start_run(true,"base")
    world.select_link("chain_axe")
    world.weapon_runtime.axe.chain_state="out"
    world.select_link("rune_shell")
    world.start_wave_closing()
    world.simulate(world.WAVE_BUFFER+0.01,Vector2.ZERO)
    world.leave_shop()
    expect(world.pending_link.is_empty() and world.active_link.id=="rune_shell","next round settles a recipe queued during a flying chain")
    world.spawn_enemy("tank",world.player_position+Vector2(250,0))
    world.weapon_runtime.powder.cooldown=0
    world.update_weapons(0.01)
    expect(world.projectiles.any(func(p):return p.kind=="powder" and p.get("enchanted",false)),"settled recipe keeps the next round cannon firing")
    world.queue_free()
    await process_frame
    print("ROUNDS V12 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
