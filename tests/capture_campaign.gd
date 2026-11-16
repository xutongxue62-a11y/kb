extends SceneTree

func _initialize() -> void:
    call_deferred("capture_checks")

func save_frame(filename: String) -> void:
    await RenderingServer.frame_post_draw
    var capture: Image = root.get_texture().get_image()
    print("CAPTURE "+filename+" status="+str(capture.save_png("res://previews/"+filename)))

func capture_checks() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/native_capture_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.demo = true
    await process_frame
    await save_frame("v06_start.png")
    world.hud.show_help("gameplay",false)
    await process_frame
    await save_frame("v06_help.png")
    world.hud.show_settings(false)
    await process_frame
    await save_frame("v06_settings.png")
    world.start_run(true,"new")
    world.apply_buff("pet")
    world.apply_buff("drone")
    world.clear_enemies()
    for fixture in [["tank",Vector2(100,10)],["hunter",Vector2(150,-20)],["charger",Vector2(-120,-85)],["spitter",Vector2(235,120)]]:
        world.spawn_enemy(fixture[0],world.player_position+fixture[1])
        world.enemies.back()["hp"] = 150.0
        world.enemies.back()["max_hp"] = 150.0
    for index in range(100):
        world.simulate(1.0/60.0,Vector2(0.2,0))
        await process_frame
    await save_frame("v06_new_weapons.png")
    world.coins = 45
    world.end_round()
    await process_frame
    await save_frame("v06_shop.png")
    world.buy_shop_item(0)
    await process_frame
    await save_frame("v06_shop_bought.png")
    world.leave_shop()
    world.begin_round(5)
    for index in range(100):
        world.simulate(1.0/60.0,Vector2(-0.12,0))
        await process_frame
    await save_frame("v06_boss.png")
    world.toggle_stats()
    await process_frame
    await save_frame("v06_stats.png")
    world.queue_free()
    await process_frame
    quit()
