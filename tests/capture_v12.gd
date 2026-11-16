extends SceneTree
var world
var failures := 0
var checks := 0
var folder := "res://previews/v12_native_v1"
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
    print("V12 NATIVE: ",label," frame=",Engine.get_frames_drawn())
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

func clear_local_stones(keep: String="") -> void:
    var home:=Vector2i(floori(world.player_position.x/512),floori(world.player_position.y/512))
    for x in range(home.x-3,home.x+4):
        for y in range(home.y-3,home.y+4):
            var id:=Vector2i(x,y)
            var props: Array=world.map_view.chunk_content(id)
            world.map_view.chunks[id]=props.filter(func(p):return p.kind!="stone" or world.map_view.stone_id(p)==keep)
    world.map_view.queue_redraw()
func prepare(ids: Array) -> void:
    world.set_physics_process(false)
    world.start_run(true,"base")
    world.clear_enemies()
    world.clear_weapons()
    for id in ids: world.grant_weapon(id)
    clear_local_stones()
    world.sync_idle_loadout()
    world.spawn_clock=999
    world.invulnerable=999
    world.effects.advance(0)
    world.update_hud()
func record() -> void:
    root.size=Vector2i(1280,800)
    Engine.max_fps=60
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/v12_native_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    await frames(26)
    await click(target("EnterCamp"))
    await click(target("StartSling"))
    world.set_physics_process(true)
    var wait_count:=0
    while world.departure_left>0 and wait_count<160:
        await process_frame
        wait_count+=1
    world.set_physics_process(false)
    expect(world.enemies.is_empty(),"real departure starts with no enemy residue")
    mark("empty_opening_and_player_shadow")
    await frames(6)
    await shot("01_player_shadow_empty_opening")

    var rock: Dictionary=find_prop("stone")
    expect(not rock.is_empty(),"actual world contains a mineable rock")
    var id: String=world.map_view.stone_id(rock)
    teleport(rock.point-Vector2(200,0))
    clear_local_stones(id)
    world.sync_idle_loadout()
    world.spawn_clock=999
    world.invulnerable=999
    world.weapon_runtime.sling.cooldown=0
    mark("actual_sling_source_and_mining")
    await ticks(1)
    await shot("02_sling_release_and_stone_bullet")
    await ticks(32)
    await shot("03_stone_damage_cracks")
    await ticks(88)
    expect(world.map_view.stone_health.get(id,999)==0,"automatic projectiles really destroy the stone")
    expect(world.pickups.size()==2,"broken stone drops one coin and one XP bundle")
    await shot("04_broken_rock_large_loot")
    var stop: Vector2=rock.point
    await key(KEY_D,true)
    world.set_physics_process(true)
    await frames(36)
    await key(KEY_D,false)
    world.set_physics_process(false)
    expect(world.player_position.x>stop.x,"real D input crosses the destroyed collision")
    expect(world.coins>=1 and world.xp>=1,"real walking collects the mining rewards")

    for key_id in ["powder","staff"]:
        prepare([key_id])
        dummy("tank",world.player_position+Vector2(-210,0) if key_id=="staff" else world.player_position+Vector2(260,0))
        world.weapon_runtime[key_id].cooldown=0
        mark(key_id+"_distinct_muzzle_and_projectile")
        await ticks(2)
        expect(world.projectiles.any(func(p):return p.kind==key_id),"remote showcase really contains its fired projectile")
        await shot("05_cannon_muzzle" if key_id=="powder" else "06_staff_triple_runes")
        await ticks(38)
    prepare(["totem"])
    for offset in [Vector2(205,-60),Vector2(245,45),Vector2(330,90)]: dummy("hunter",world.player_position+offset)
    mark("branched_lightning_from_totem")
    await ticks(1)
    await shot("07_branched_lightning")
    await ticks(35)

    prepare(["bonebow","firepot","wardrum","crystal"])
    world.buff_levels={"haste":3}
    world.stats=world.Growth.stats(world.buff_levels)
    world.update_hud()
    mark("four_new_weapon_mechanisms")
    await frames(15)
    await shot("08_four_new_weapon_shapes")
    for i in range(5): dummy("tank",world.player_position+Vector2.from_angle(TAU*i/5)*155)
    await ticks(33)
    await shot("09_bone_arrows_fire_and_rhythm")
    await ticks(62)
    await shot("10_triggered_crystal_shards")
    await ticks(40)

    prepare([])
    dummy("raptor",world.player_position+Vector2(-225,-60),true)
    dummy("thrower",world.player_position+Vector2(240,-45))
    dummy("armored",world.player_position+Vector2(40,150))
    mark("three_new_monster_silhouettes_and_AI")
    await frames(12)
    await shot("11_new_monster_species")
    var saw_stone:=false
    for i in range(90):
        await ticks(1)
        if not saw_stone and world.projectiles.any(func(p):return p.get("source_kind","")=="thrower"):
            saw_stone=true
            await shot("12_thrower_rock_fan")
        if i==32: await shot("13_pounce_and_stomp_warnings")
    expect(saw_stone,"new ranged monster emits actual distinct stone projectiles")

    prepare([])
    var rewards: Array=[]
    for i in range(3):
        var kind: String=["hunter","tank","armored"][i]
        var enemy: Dictionary=dummy(kind,world.player_position+Vector2((i-1)*235,100),i==2)
        world.hurt_enemy(enemy,1000000,"powder",true,Vector2.UP)
        rewards.append({"kind":kind,"xp":world.pickups[-2].value,"coins":world.pickups[-1].value})
    world.clear_enemies()
    for i in range(22):
        world.effects.advance(1.0/30.0)
        await process_frame
    mark("differentiated_threat_loot_bands")
    await shot("14_enemy_reward_bundles")
    expect(rewards[2].coins>rewards[0].coins,"large elite reward exceeds small hunter reward")

    prepare(["sling","powder","staff","totem"])
    for i in range(4): dummy(["hunter","raptor","thrower","armored"][i],world.player_position+Vector2.from_angle(TAU*i/4)*230)
    await ticks(8)
    world.wave_elapsed=29.99
    await ticks(1)
    expect(world.wave_closing and not world.shop_open,"real round end begins a visible settlement freeze")
    var before: Vector2=world.player_position
    var poses: Dictionary={}
    for key_id in world.weapon_views: poses[key_id]=[world.weapon_views[key_id].position,world.weapon_views[key_id].rotation]
    mark("all_enemies_dismiss_then_frozen_player_and_weapons")
    await key(KEY_D,true)
    world.set_physics_process(true)
    await frames(8)
    expect(world.player_position==before,"held real D cannot move during settlement")
    for key_id in poses:
        expect(world.weapon_views[key_id].position==poses[key_id][0] and world.weapon_views[key_id].rotation==poses[key_id][1],"weapon remains still in settlement")
    await shot("15_round_clear_frozen_pose")
    await key(KEY_D,false)
    await frames(36)
    world.set_physics_process(false)
    expect(world.shop_open and world.enemies.is_empty(),"shop opens after the pause on a clean field")
    await frames(26)
    await shot("16_camp_after_settlement")
    await click(target("NextRound"))
    while world.shop_open: await process_frame
    expect(world.enemies.is_empty() and world.projectiles.is_empty(),"native scroll close begins next wave without residue")
    mark("next_wave_completely_empty")
    await shot("17_next_wave_empty")
    world.set_physics_process(true)
    await frames(12)
    expect(world.enemies.is_empty(),"next wave retains its brief clean opening")
    await frames(8)
    world.set_physics_process(false)
    expect(not world.enemies.is_empty(),"new wave eventually creates its own arrivals")
    expect(world.enemies.all(func(e):return not world.visible_world_rect().has_point(e.position) or e.state=="egg"),"fresh enemies enter from the screen edge or a hatch")
    await shot("18_next_wave_fresh_arrival")
    await ticks(32)
    var file:=FileAccess.open(folder+"/timeline.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"fps":30,"checks":checks,"failures":failures,"markers":markers,"drop_samples":rewards,"note":"Isolated save. Durable monsters, invulnerability, curated loadouts and an isolated real-rock lane are presentation fixtures. Mouse departure/shop and D pickup/freeze tests use actual input. UI layout and music are unchanged from v0.11. Audio is the real recorded mix, listening is unverified."},"  "))
    file.close()
    world.music.set_enabled(false)
    world.audio.stop_all()
    await frames(20)
    world.queue_free()
    await frames(3)
    print("V12 NATIVE RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
