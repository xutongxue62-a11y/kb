extends SceneTree
var world
var timings: Dictionary={}
var tag: String="before"

func _initialize() -> void: call_deferred("measure")
func summary(values: Array) -> Dictionary:
    values.sort()
    return {"median":values[values.size()/2],"p95":values[floori(values.size()*0.95)],"max":values[-1]}

func measure() -> void:
    if not OS.get_cmdline_user_args().is_empty(): tag=OS.get_cmdline_user_args()[0]
    var output: String="res://previews/v16_benchmark_"+tag
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    root.size=Vector2i(1280,800)
    Engine.max_fps=0
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/benchmark_v16_"+tag+"_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.settings.autosave=false
    world.set_physics_process(false)
    world.start_run(true)
    world.departure_left=0
    world.hud.hide_menu()
    world.rng.seed=160016
    world.clear_enemies()
    world.clear_weapons()
    world.spawn_clock=9999
    world.invulnerable=9999
    world.buff_levels["pet"]=6
    world.buff_levels["drone"]=6
    world.refresh_stats()
    world.stats.attack_speed=3.0
    world.stats.crit_chance=0.0
    world.stats.magnet=0.0
    world.xp_needed=999999
    for id in ["staff","bonebow","firepot","wardrum","totem","crystal"]:
        for level in range(5): world.grant_weapon(id)
    for i in range(42):
        var offset: Vector2=Vector2.from_angle(i*2.39996)*(115+(i%7)*27)
        world.spawn_enemy(["hunter","tank","raptor","armored"][i%4],world.player_position+offset,false,"walk")
        var enemy: Dictionary=world.enemies.back()
        enemy.hp=1e9;enemy.max_hp=1e9;enemy.dodge=0;enemy.speed_multiplier=0.15
    var bounds: Rect2=world.visible_world_rect().grow(-45)
    for i in range(1500):
        var at: Vector2=bounds.position+Vector2(fmod(i*17.37,bounds.size.x),fmod(i*13.91,bounds.size.y))
        if at.distance_squared_to(world.player_position)<45000: at.y=bounds.position.y+18
        world.pickups.append({"kind":"coin" if i%2==0 else "xp","position":at,"value":1})
    var simulation: Array=[];var frames_ms: Array=[];var draws: Array=[]
    for i in range(210):
        var start: int=Time.get_ticks_usec()
        world.simulate(1.0/60.0,Vector2.ZERO)
        var sim_ms: float=(Time.get_ticks_usec()-start)/1000.0
        await process_frame
        await RenderingServer.frame_post_draw
        if i>=30:
            simulation.append(sim_ms)
            frames_ms.append((Time.get_ticks_usec()-start)/1000.0)
            draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    for method in ["update_enemies","update_companions","update_weapons","update_armory","update_projectiles","update_hud","update_pickups"]:
        var samples: Array=[]
        for i in range(90):
            var start: int=Time.get_ticks_usec()
            if method=="update_hud": world.call(method)
            else: world.call(method,1.0/60.0)
            samples.append((Time.get_ticks_usec()-start)/1000.0)
        timings[method]=summary(samples)
    var result: Dictionary={"tag":tag,"seed":160016,"frames":180,"simulation_ms":summary(simulation),"native_frame_ms":summary(frames_ms),"draw_calls":summary(draws),"subsystem_ms":timings,"enemies":world.enemies.size(),"pickups":world.pickups.size(),"particles":world.effects.particles.size(),"projectiles":world.projectiles.size(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"coins":world.coins,"xp":world.xp,"isolated_player_storage":true,"notes":"Native OpenGL, vsync off, fixed 1/60 simulation, no video encoding. Same fixture and seed; end-to-end timings include scheduling, not a hardware guarantee."}
    root.get_texture().get_image().save_png(output.path_join("stress.png"))
    var file:=FileAccess.open(output.path_join("performance.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(result,"  "));file.close();file=null
    print("V16 BENCHMARK: ",JSON.stringify(result))
    world.queue_free();world=null
    await process_frame
    quit()
