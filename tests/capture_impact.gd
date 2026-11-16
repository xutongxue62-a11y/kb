extends SceneTree

func _initialize() -> void:
    call_deferred("capture_checks")

func save_frame(filename: String) -> void:
    await RenderingServer.frame_post_draw
    var capture: Image = root.get_texture().get_image()
    var status: Error = capture.save_png("res://previews/" + filename)
    print("CAPTURE " + filename + " status=" + str(status))

func capture_checks() -> void:
    var world = load("res://src/main.gd").new()
    root.add_child(world)
    world.set_physics_process(false)
    world.demo = true
    world.start_run(true)
    DisplayServer.window_set_title("原始人大作战 · 特效核验")
    world.apply_buff("pet")
    world.apply_buff("drone")
    for enemy in world.enemies:
        enemy["view"].queue_free()
    world.enemies.clear()
    for fixture in [["tank", Vector2(95, 20)], ["hunter", Vector2(-95, 0)], ["charger", Vector2(60, -110)], ["spitter", Vector2(-210, -110)], ["spitter", Vector2(230, 100)], ["hunter", Vector2(180, 140)]]:
        world.spawn_enemy(fixture[0], world.player_position + fixture[1])
        world.enemies.back()["hp"] = 100.0
        world.enemies.back()["max_hp"] = 100.0
    world.hud.title_label.text = "战斗特效核验"
    for index in range(150):
        world.simulate(1.0 / 60.0, Vector2(0.25, 0.0))
        await process_frame
        if index == 55:
            await save_frame("v05_combat_a.png")
        if index == 110:
            await save_frame("v05_combat_b.png")
    world.toggle_stats()
    await process_frame
    await save_frame("v05_stats.png")
    world.toggle_stats()
    world.wave = 4
    world.elapsed = 119.99
    world.simulate(0.02, Vector2.ZERO)
    world.present_upgrade("wave")
    await process_frame
    await save_frame("v05_milestone.png")
    world.on_choice(world.upgrade_choices[0])
    world.toggle_stats()
    await process_frame
    await save_frame("v05_enemy_stats.png")
    world.hud.show_menu("start", 0)
    await process_frame
    await save_frame("v05_start.png")
    world.queue_free()
    await process_frame
    quit()
