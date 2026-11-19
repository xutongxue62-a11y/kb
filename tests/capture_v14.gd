extends "res://tests/capture_character_loot_v13.gd"

func shot(name: String) -> void:
    world.queue_redraw()
    await frames(2)
    await RenderingServer.frame_post_draw
    expect(root.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"native image: "+name)
    markers.append({"name":name,"frame":Engine.get_frames_drawn(),"coins":world.coins,"xp":world.xp,"pickups":world.pickups.size(),"chests":world.chest_marks.size(),"shop":world.shop_open})
    print("V14 NATIVE: "+name)

func ticks(count: int) -> void:
    for i in range(count):
        world.simulate(1.0/60.0,Vector2.ZERO)
        await process_frame

func prepare(ids: Array,level: int) -> void:
    world.start_run(false)
    world.set_physics_process(false)
    world.departure_left=0
    world.hud.hide_menu()
    world.clear_enemies()
    world.clear_weapons()
    world.pickups.clear()
    clear_stones()
    for id in ids:
        for i in range(level): world.grant_weapon(id)
    world.spawn_clock=999
    world.invulnerable=999
    world.stats.crit_chance=0
    for offset in [Vector2(140,0),Vector2(200,-65),Vector2(230,65),Vector2(290,0),Vector2(100,100)]:
        world.spawn_enemy("tank",world.player_position+offset,false,"idle")
        var enemy: Dictionary=world.enemies.back()
        enemy.hp=10000
        enemy.max_hp=10000
        enemy.dodge=0
        enemy.speed_multiplier=0
    world.sync_idle_loadout()
    world.update_hud()

func add_label(host: Node,text: String,at: Vector2,size: int=23) -> void:
    var label:=Label.new()
    label.text=text
    label.position=at
    label.add_theme_font_override("font",world.hud.body_font)
    label.add_theme_font_size_override("font_size",size)
    label.add_theme_color_override("font_color",Color("#48372c"))
    host.add_child(label)

func forge_sheet() -> void:
    var viewport:=SubViewport.new()
    viewport.size=Vector2i(940,1500)
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var paper:=ColorRect.new()
    paper.size=Vector2(940,1500)
    paper.color=Color("#f0dfb9")
    viewport.add_child(paper)
    add_label(viewport,"武器成长 · 实际游戏素材",Vector2(32,18),32)
    for column in range(3): add_label(viewport,["Lv.1 基础","Lv.3 进阶","Lv.5 觉醒"][column],Vector2(238+column*230,75),24)
    for row in range(world.Catalog.IDS.size()):
        var id: String=world.Catalog.IDS[row]
        add_label(viewport,world.Catalog.WEAPONS[id].name,Vector2(24,132+row*96),21)
        for column in range(3):
            var weapon: Sprite2D=world.library.make_weapon(id,66,[1,3,5][column])
            weapon.position=Vector2(300+column*230,145+row*96)
            viewport.add_child(weapon)
    await frames(3)
    await RenderingServer.frame_post_draw
    expect(viewport.get_texture().get_image().save_png(folder.path_join("weapon_growth_sheet.png"))==OK,"all fourteen milestone appearances exported from the real texture factory")
    viewport.queue_free()
    await process_frame

func record() -> void:
    folder="res://previews/v14_native_v2"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    root.size=Vector2i(1280,800)
    Engine.max_fps=60
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/native_v14_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.settings.autosave=false
    world.set_physics_process(false)
    await frames(40)
    await click("EnterCamp")
    for id in world.Catalog.CHARACTER_ORDER:
        while world.hud.selected_character!=id: await click("NextCharacter")
        await shot("selection_"+id)
    await forge_sheet()
    for level in [1,3,5]:
        prepare(["sling"],level)
        await ticks(8)
        await shot("sling_level_"+str(level))
        await ticks(72)
    for fixture in [["fire_drum",["firepot","wardrum"]],["thunder_crystal",["totem","crystal"]],["storm_arrow",["bonebow","totem"]]]:
        prepare(fixture[1],3)
        world.select_link(fixture[0])
        expect(world.active_link.id==fixture[0],"native optional recipe: "+fixture[0])
        await ticks(90)
        await shot(fixture[0])
        await ticks(50)
    prepare(["sling"],3)
    world.clear_enemies()
    for offset in [Vector2(230,50),Vector2(-160,20)]:
        world.spawn_enemy("hunter",world.player_position+offset,true,"egg")
    world.coins=7
    world.xp=7
    world.spawn_loot({"coin":3,"xp":5},world.player_position+Vector2(350,80))
    world.chest_marks=[{"position":world.player_position+Vector2(-300,100),"age":0.0}]
    world.update_hud()
    await shot("round_before_sweep")
    var kills: int=world.kills
    world.start_wave_closing()
    expect(world.enemies.is_empty() and world.pickups.size()==8 and world.chest_marks.size()==1 and world.kills==kills,"native sweeping of elite eggs creates no extra rewards")
    await shot("round_clear_no_new_loot")
    await ticks(30)
    await shot("round_finish_pause_leftover_loot")
    await ticks(26)
    expect(world.upgrade_pending and world.upgrade_reason=="chest" and world.coins==7 and is_equal_approx(world.xp,7.0) and not world.shop_open,"native settlement discards leftover gems and presents the remaining chest before camp")
    await shot("round_chest_reward")
    await click("GrowthOffer0")
    expect(world.shop_open and world.coins==7 and is_equal_approx(world.xp,7.0) and world.chest_queue==0,"native camp shows exact final 7 coins / 7 remaining XP with no absorbed leftovers")
    await shot("round_final_shop")
    var file:=FileAccess.open(folder.path_join("timeline.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":markers,"real_player_storage_used":false},"  "))
    file.close()
    print("V14 NATIVE RESULT: %d checks, %d failures" % [checks,failures])
    await frames(20)
    quit(1 if failures else 0)
