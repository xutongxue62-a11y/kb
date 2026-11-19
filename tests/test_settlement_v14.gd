extends SceneTree
var checks := 0
var failures := 0
func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)
func _initialize() -> void: call_deferred("run_checks")
func run_checks() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/settlement_v14_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.settings.autosave = false
    world.start_run(false)
    world.clear_enemies()
    for id in world.Catalog.CHARACTER_ORDER:
        world.hero.set_character(id)
        for key in world.hero.parts:
            expect(world.hero.parts[key].material == null,"no cyan silhouette shader remains on " + id + ":" + key)
    world.coins = 7
    world.xp = 0.0
    world.spawn_loot({"coin":3,"xp":5},world.player_position+Vector2(350,100))
    world.chest_marks = [{"position":world.player_position+Vector2(-320,150),"age":0.0}]
    world.spawn_enemy("hunter",world.player_position+Vector2(100,0),true,"egg")
    var kills: int = world.kills
    world.start_wave_closing()
    expect(world.enemies.is_empty() and world.kills==kills and world.pickups.size()==8 and world.chest_marks.size()==1,"sweeping a living elite egg grants no kills, loot or extra chest")
    var before: Array = world.pickups.map(func(d):return d.position)
    world.simulate(0.25,Vector2.RIGHT)
    expect(world.wave_closing and not world.shop_open,"shop stays closed during the finish pause")
    expect(world.pickups.map(func(d):return d.position)==before and world.chest_marks.size()==1 and world.coins==7 and is_equal_approx(world.xp,0.0),"leftover gems and the ground chest stay put and are not absorbed")
    var partial: Dictionary = world.SessionState.capture(world)
    expect(world.save_store.write_run(partial).ok and world.continue_game(),"finish pause saves and resumes")
    world.simulate(1.0,Vector2.ZERO)
    expect(world.pickups.is_empty() and world.chest_marks.is_empty() and world.chest_queue==0 and world.coins==7 and is_equal_approx(world.xp,0.0) and world.shop_open and not world.upgrade_pending,"uncollected gems and the ground chest are discarded at settlement")
    world.start_run(false)
    world.clear_enemies()
    world.coins = 0
    # Lv.1 needs 15 XP. Leftover gems and the ground chest are discarded, so 14 XP is not enough to level up.
    world.xp = 14.0
    world.spawn_loot({"coin":4,"xp":4},world.player_position+Vector2(500,0))
    world.chest_marks = [{"position":world.player_position+Vector2(0,200),"age":0.0}]
    world.start_wave_closing()
    world.simulate(1.1,Vector2.ZERO)
    expect(world.shop_open and not world.upgrade_pending and world.coins==0 and is_equal_approx(world.xp,14.0) and world.player_level==1 and world.chest_queue==0 and world.chest_marks.is_empty(),"final shop totals exclude discarded leftover gems and the uncollected chest")
    world.queue_free()
    await process_frame
    print("SETTLEMENT V14 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
