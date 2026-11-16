extends SceneTree
var world
var failures := 0
var checks := 0
var folder := "res://previews/v11_native_v1"
var markers: Array = []

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-folder="): folder="res://previews/"+arg.trim_prefix("--capture-folder=")
    call_deferred("record")
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        print("FAIL: "+label)
func frames(count: int) -> void:
    for i in range(count): await process_frame
func ticks(count: int,movement: Vector2=Vector2.ZERO) -> void:
    for i in range(count):
        world.simulate(1.0/30.0,movement)
        await process_frame
func mark(label: String) -> void:
    markers.append({"name":label,"frame":Engine.get_frames_drawn(),"world":[world.player_position.x,world.player_position.y],"music":world.music._playing_context})
    print("V11 NATIVE: ",label," frame=",Engine.get_frames_drawn())
func shot(label: String) -> void:
    await RenderingServer.frame_post_draw
    expect(root.get_texture().get_image().save_png(folder+"/"+label+".png")==OK,"save "+label)
func target(name: String) -> BaseButton:
    return world.hud.overlay.find_child(name,true,false) as BaseButton
func hover(button: BaseButton) -> void:
    if button==null:
        expect(false,"hover target exists")
        return
    var at:=button.get_global_rect().get_center()
    var event:=InputEventMouseMotion.new()
    event.position=at
    event.global_position=at
    Input.parse_input_event(event)
    await frames(15)
func click(button: BaseButton) -> void:
    var waited:=0
    while world.hud.ui_busy() and waited<300:
        await process_frame
        waited+=1
    if button==null or button.disabled or world.hud.ui_busy():
        expect(false,"native button exists and is unlocked")
        return
    await hover(button)
    var at:=button.get_global_rect().get_center()
    for down in [true,false]:
        var event:=InputEventMouseButton.new()
        event.position=at
        event.global_position=at
        event.button_index=MOUSE_BUTTON_LEFT
        event.pressed=down
        Input.parse_input_event(event)
        await process_frame
func key(code: int,down: bool) -> void:
    var event:=InputEventKey.new()
    event.physical_keycode=code
    event.keycode=code
    event.pressed=down
    Input.parse_input_event(event)
    await process_frame
func teleport(at: Vector2) -> void:
    world.player_position=world.map_view.move_body(at,at,18)
    world.hero.position=world.player_position
    world.update_hud()
func dummy(kind: String,at: Vector2,elite: bool=false,shell: String="") -> Dictionary:
    world.spawn_enemy(kind,at,elite,shell)
    var enemy: Dictionary=world.enemies.back()
    enemy.hp=100000.0
    enemy.max_hp=100000.0
    enemy.dodge=0.0
    enemy.elite=elite
    enemy.view.elite=elite
    return enemy
func find_prop(kind: String) -> Dictionary:
    var nearest: Dictionary={}
    var distance:=INF
    for key_id in world.map_view.visible_chunks():
        for prop in world.map_view.chunk_content(key_id):
            if prop.kind==kind and prop.point.distance_to(world.player_position)<distance:
                nearest=prop
                distance=prop.point.distance_to(world.player_position)
    return nearest

func record() -> void:
    root.size=Vector2i(1280,800)
    Engine.max_fps=60
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/v11_native_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    await frames(35)
    mark("title_score_and_paper_hover")
    await shot("01_home_rest")
    await hover(target("EnterCamp"))
    await shot("02_home_teal_hover")
    await click(target("EnterCamp"))
    await frames(45)
    await hover(target("StartSling"))
    await shot("03_cast_paper_hover")
    await click(target("StartSling"))
    world.set_physics_process(true)
    await frames(82)
    world.set_physics_process(false)
    world.start_run(true,"base")
    world.clear_enemies()
    world.spawn_clock=999
    world.invulnerable=999
    var home: Vector2=world.player_position
    dummy("hunter",home+Vector2(-235,-70),true)
    dummy("charger",home+Vector2(240,-80))
    dummy("spitter",home+Vector2(-225,145))
    dummy("tank",home+Vector2(245,160),true)
    dummy("hunter",home+Vector2(10,190),false,"egg")
    mark("grounded_monsters_and_radial_weapons")
    await ticks(1)
    await frames(18)
    await shot("04_monster_ground_shadows")

    world.clear_enemies()
    world.buff_levels={"haste":19,"crit_chance":14,"pet":3}
    world.stats=world.Growth.stats(world.buff_levels)
    world.upgrade_pending=true
    world.upgrade_choices=["haste","crit_chance","pet"]
    world.upgrade_reason="xp"
    world.hud.show_choices(world.upgrade_choices,world.inventory,world.buff_levels,"xp",world.wave)
    world.update_hud()
    await frames(48)
    mark("growth_odds_and_unobscured_rollers")
    await shot("05_growth_odds")
    var before: float=world.elapsed
    await click(target("GrowthOffer0"))
    await frames(5)
    expect(world.upgrade_pending and world.hud.scroll_closing,"growth keeps battle frozen until roll close")
    world.simulate(0.1,Vector2.RIGHT)
    expect(world.elapsed==before,"closing growth does not advance battle time")
    await shot("06_growth_rolling_closed")
    await frames(35)
    expect(not world.upgrade_pending and world.buff_levels.haste==20,"native click commits exactly one chosen buff after close")

    world.coins=500
    world.player_hp=6
    world.end_round()
    await frames(45)
    mark("six_offer_camp_shop")
    expect(world.hud.overlay.find_children("ShopOffer*","Button",true,false).size()==6,"six real shop cards are mounted")
    await hover(target("ShopOffer1"))
    await shot("07_six_offer_shop")
    var cost: int=world.shop_stock[0].price
    await click(target("ShopOffer0"))
    expect(world.shop_stock[0].sold and world.coins==500-cost,"native purchase charges once and marks sold")
    await frames(12)
    await shot("08_shop_purchase")
    await click(target("NextRound"))
    await frames(5)
    expect(world.shop_open and world.hud.scroll_closing,"next round waits for camp scroll close")
    await shot("09_shop_rolling_closed")
    await frames(35)
    expect(world.wave==2 and not world.shop_open,"next wave starts after camp has rolled away")

    world.clear_enemies()
    world.spawn_clock=999
    world.invulnerable=999
    var stone: Dictionary=find_prop("stone")
    expect(not stone.is_empty(),"streamed terrain supplies a real stone")
    if not stone.is_empty():
        teleport(stone.point-Vector2(105,0))
        await key(KEY_D,true)
        world.set_physics_process(true)
        await frames(12)
        await key(KEY_SHIFT,true)
        await frames(20)
        await key(KEY_SHIFT,false)
        await key(KEY_D,false)
        world.set_physics_process(false)
        expect(world.player_position.x<stone.point.x,"real walking and Shift cannot cross stone")
        mark("solid_stone_blocks_shift")
        await shot("10_stone_collision")

    world.wave=6
    world.wave_elapsed=4
    world.update_hud()
    await frames(40)
    expect(world.music._playing_context=="grove","grove plays its own native score")
    mark("grove_original_score")
    await shot("11_grove")
    world.toggle_pause()
    await frames(24)
    expect(world.music._context=="pause","native pause ducks biome music")
    world.toggle_pause()
    world.go_home()
    await frames(30)
    expect(world.music._playing_context=="title","shop/battle home navigation returns to title score")

    world.start_run(true,"base")
    world.clear_enemies()
    world.spawn_clock=999
    world.wave=9
    world.wave_elapsed=3
    world.invulnerable=0
    world.update_hud()
    var pit: Dictionary=find_prop("lava")
    expect(not pit.is_empty(),"volcano supplies an internal neutral lava pit")
    if not pit.is_empty():
        teleport(pit.point)
        var enemy: Dictionary=dummy("tank",pit.point+Vector2(30,0),true)
        var hp: float=world.player_hp
        var ehp: float=enemy.hp
        for i in range(30):
            world.elapsed+=1.0/30.0
            world.update_terrain_damage(1.0/30.0,1.0/30.0)
            world.effects.advance(1.0/30.0)
            enemy.view.animate(Vector2.ZERO,1.0/30.0)
            world.update_hud()
            await process_frame
        expect(is_equal_approx(hp-world.player_hp,2.0),"hero loses two health to one second of lava")
        expect(is_equal_approx(ehp-enemy.hp,2.0),"monster loses the same neutral lava damage")
        mark("lava_hurts_both_teams")
        await shot("12_neutral_lava")
    expect(world.music._playing_context=="volcano","volcano plays its own native score")

    world.start_run(true,"base")
    world.clear_enemies()
    world.spawn_clock=999
    world.invulnerable=999
    world.wave=6
    world.wave_elapsed=8
    world.buff_levels={"power":20,"haste":20,"crit_chance":15,"crit_power":15,"pet":6,"drone":6}
    world.stats=world.Growth.stats(world.buff_levels)
    world.player_hp=world.stats.max_hp
    world.update_hud()
    world.companions.advance(0.1,world.player_position,[],world.buff_levels,world.stats)
    await ticks(2)
    await frames(20)
    await shot("13a_support_idle")
    for i in range(9):
        dummy("tank" if i%3==0 else "hunter",world.player_position+Vector2.from_angle(TAU*i/9)*165,i%3==0)
    mark("stacked_haste_crit_and_redesigned_supports")
    await ticks(30)
    await shot("13_pet_and_drone")
    await ticks(80)
    await shot("14_late_attack_storm")
    await ticks(40)
    expect(world.companions.states.has("pet") and world.companions.states.has("drone"),"new support artwork is used by active combat units")
    world.wave_elapsed=26.5
    world.update_hud()
    mark("last_five_seconds_red_warning")
    await frames(16)
    await shot("15_urgent_countdown")
    expect(world.hud.timer_label.text.contains("最后"),"native countdown displays explicit last seconds")

    var file:=FileAccess.open(folder+"/timeline.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"fps":30,"checks":checks,"failures":failures,"markers":markers,"note":"Isolated save. Forced map stages, high-level buffs, invulnerability and durable targets are presentation fixtures. Mouse selection/purchase, roll-close, and Shift collision use actual input events. Audio is the real recorded game mix; listening is not verified."},"  "))
    file.close()
    world.music.set_enabled(false)
    world.audio.stop_all()
    await frames(20)
    world.queue_free()
    await frames(3)
    print("V11 NATIVE RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
