extends SceneTree

const Main = preload("res://src/main.gd")
const Catalog = preload("res://src/catalog.gd")
const Store = preload("res://src/save_store.gd")
var world
var checks := 0
var failures := 0
var folder := "res://previews/character_loot_v13_v4"
var markers: Array = []

func _initialize() -> void:
    call_deferred("record")

func expect(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + label)

func frames(count: int) -> void:
    for i in range(count): await process_frame

func button(name: String) -> BaseButton:
    return world.hud.overlay.find_child(name,true,false) as BaseButton

func click(name: String) -> void:
    var waited := 0
    while world.hud.ui_busy() and waited < 300:
        await process_frame
        waited += 1
    var target := button(name)
    if target == null or target.disabled or not target.visible:
        expect(false,"native button available: " + name)
        return
    if root.has_method("grab_focus"): root.call("grab_focus")
    var at: Vector2 = target.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = at
    motion.global_position = at
    Input.parse_input_event(motion)
    await frames(15)
    for down in [true,false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.global_position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        Input.parse_input_event(event)
        await process_frame
    await frames(40)

func key(code: int, down: bool) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.pressed = down
    Input.parse_input_event(event)
    await process_frame

func shot(name: String) -> void:
    world.queue_redraw()
    await frames(2)
    await RenderingServer.frame_post_draw
    var error: Error = root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
    expect(error == OK,"native screenshot saved: " + name)
    markers.append({"name":name,"frame":Engine.get_frames_drawn(),"character":world.character_id,"pickups":world.pickups.size(),"coins":world.coins,"xp":world.xp})
    print("NATIVE V13: ", name)

func clear_stones() -> void:
    var home := Vector2i(floori(world.player_position.x/512),floori(world.player_position.y/512))
    for x in range(home.x-3,home.x+4):
        for y in range(home.y-3,home.y+4):
            var id := Vector2i(x,y)
            world.map_view.chunks[id] = world.map_view.chunk_content(id).filter(func(p): return p.kind != "stone")
    world.map_view.queue_redraw()

func record() -> void:
    root.size = Vector2i(1280,800)
    Engine.max_fps = 60
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    world = Main.new()
    world.save_store = Store.new("res://runtime/tests/native_character_loot_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.settings.autosave = false
    world.set_physics_process(false)
    await frames(35)
    for id in Catalog.CHARACTER_ORDER:
        if world.running:
            world.go_home()
            await frames(45)
        await click("EnterCamp")
        if world.hud.screen == "title":
            await key(KEY_ENTER,true)
            await key(KEY_ENTER,false)
            await frames(40)
        expect(world.hud.screen == "cast", "native title click opens selection")
        if world.hud.screen != "cast": break
        var turns := 0
        while world.hud.selected_character != id and turns < 3:
            await click("NextCharacter")
            turns += 1
        expect(world.hud.selected_character == id,"selection arrows reach " + id)
        await shot(id + "_01_selection")
        await click(Catalog.character(id).confirm_button)
        world.set_physics_process(true)
        var waited := 0
        while world.departure_left > 0 and waited < 240:
            await process_frame
            waited += 1
        world.set_physics_process(false)
        expect(world.character_id == id and world.hero.body_resource_path() == Catalog.character(id).body,"native confirm launches matching " + id + " actor")
        expect(world.starting_weapon == Catalog.character(id).starting_weapon,"native confirm retains starter weapon for " + id)
        clear_stones()
        world.clear_enemies()
        world.spawn_clock = 999
        world.invulnerable = 999
        world.departure_left = 0
        world.player_frozen = false
        world.spawn_enemy("tank",world.player_position+Vector2(180,10),false,"idle")
        var enemy: Dictionary = world.enemies.back()
        enemy.hp = 1000.0
        enemy.max_hp = 1000.0
        enemy.dodge = 0.0
        world.spawn_enemy("hunter",world.player_position+Vector2(-185,30),false,"idle")
        world.enemies.back().hp = 1000.0
        world.enemies.back().max_hp = 1000.0
        world.enemies.back().dodge = 0.0
        world.set_physics_process(true)
        await key(KEY_D,true)
        await frames(40)
        await key(KEY_D,false)
        if id == "barbarian":
            # Keep the diagnostic target on the club's real orbit, rather than
            # letting a pursuing target finish inside its circular swing.
            enemy.position = world.player_position + Vector2(94,0)
            enemy.view.position = enemy.position
            enemy.speed_multiplier = 0.0
        await frames(100)
        world.set_physics_process(false)
        await shot(id + "_02_combat")
        expect(world.hero.amplitude >= 0 and world.enemies.any(func(e): return e.hp < 1000.0),"native " + id + " movement and automatic combat run")
        world.clear_enemies()
        world.projectiles.clear()
        world.pickups.clear()
        world.effects.particles.clear()
        world.coins = 0
        world.xp = 0.0
        world.spawn_loot({"xp":5,"coin":3},world.player_position+Vector2(180,60))
        world.update_hud()
        expect(world.pickups.size() == 8 and world.pickups.all(func(d):return d.value==1),"native " + id + " shows eight physical 5XP/3coin resources")
        await shot(id + "_03_eight_units")
        await frames(35)
        world.pickups[0].position = world.player_position + Vector2(30,0)
        world.pickups[-1].position = world.player_position + Vector2(-30,0)
        world.set_physics_process(true)
        await frames(22)
        world.set_physics_process(false)
        expect(world.pickups.size() == 6 and world.coins == 1 and is_equal_approx(world.xp,1.0),"native partial collection keeps six independent objects")
        var saved: Dictionary = world.SessionState.capture(world)
        expect(world.save_store.write_run(saved).ok and world.continue_game(),"native " + id + " saves and resumes partial pickups")
        world.set_physics_process(false)
        expect(world.character_id == id and world.pickups.size() == 6 and world.coins == 1,"native continue retains character and remaining units")
        clear_stones()
        world.spawn_clock = 999
        world.invulnerable = 999
        await shot(id + "_04_partial_resume")
        world.set_physics_process(true)
        await key(KEY_D,true)
        await frames(38)
        await key(KEY_D,false)
        await frames(18)
        world.set_physics_process(false)
        expect(world.pickups.is_empty() and world.coins == 3 and is_equal_approx(world.xp,5.0),"native walking collects all eight once; HUD total is 3 coins / 5 XP")
        await shot(id + "_05_collected")

    world.settings.autosave = false
    world.clear_enemies()
    world.pickups.clear()
    world.coins = 0
    world.xp = 0.0
    world.spawn_loot({"xp":2500,"coin":2500},world.player_position+Vector2(1800,300))
    var samples: Array = []
    for i in range(120):
        var start: int = Time.get_ticks_usec()
        world.update_pickups(1.0/60.0)
        samples.append((Time.get_ticks_usec()-start)/1000.0)
    samples.sort()
    expect(world.pickups.size()==5000 and world.coins==0 and world.xp==0.0,"5000-unit stress never silently collects or aggregates")
    expect(world.save_store.write_run(world.SessionState.capture(world)).ok and world.continue_game(),"5000 physical units survive native save/continue")
    expect(world.pickups.size()==5000,"5000 physical units remain after native continue")
    await shot("stress_5000_culled")
    var manifest := {"checks":checks,"failures":failures,"screenshots":markers,"update_5000_ms":{"median":samples[60],"p95":samples[114],"max":samples[-1]},"storage":"isolated runtime/tests; real player saves untouched","subjective_listening_verified":false,"user_acceptance_verified":false}
    var file := FileAccess.open(folder.path_join("timeline.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(manifest,"  "))
    file.close()
    print("NATIVE CHARACTER LOOT RESULT: %d checks, %d failures" % [checks,failures])
    print("5000 UPDATE MS: ",manifest.update_5000_ms)
    await frames(20)
    quit(1 if failures else 0)
