extends "res://tests/capture_v14.gd"
var distances: Array=[]
var capture_folder: String="res://previews/v15_native_v4"

func comparison_pose(host: Node,origin: Vector2,ids: Array,previous: bool,scale_value: float) -> void:
    var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/v15_baseline.json"))
    var rules
    if previous:
        var script:=GDScript.new()
        script.source_code=FileAccess.get_file_as_string(str(baseline.snapshot).path_join("src/rules.gd"))
        expect(script.reload()==OK,"previous verified layout can be loaded read-only")
        rules=script.new()
    else:
        rules=world.Rules.new()
    var group:=Node2D.new()
    group.position=origin
    group.scale=Vector2.ONE*scale_value
    host.add_child(group)
    var actor=world.ActorView.new()
    actor.setup(world.library,"caveman")
    actor.get_node("PlayerMarker").hide()
    group.add_child(actor)
    var mounts: Dictionary=rules.call("loadout_layout",ids,0.0,false)
    for id in ids:
        var size: float=world.Catalog.WEAPONS[id].size*(1.0 if id=="sling" else 1.12)
        var view: Sprite2D=world.library.make_weapon(id,size,3)
        view.position=mounts[id]
        var aim: Vector2=Vector2(mounts[id]).normalized()
        if id in ["sling","staff","spear","bonebow"]: view.rotation=aim.angle()+PI/2.0
        elif id=="powder": view.rotation=aim.angle()
        if world.Rules.is_parked_weapon(id): rules.call("apply_parked_hold",view,id,Vector2.ZERO,aim)
        view.z_index=12 if view.position.y>=2.0 else 8
        group.add_child(view)
        distances.append({"previous":previous,"id":id,"pixels":(view.to_global(view.offset)-origin).length()/scale_value})

func layout_sheet() -> void:
    var viewport:=SubViewport.new()
    viewport.size=Vector2i(1200,930)
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var paper:=ColorRect.new()
    paper.size=Vector2(1200,930)
    paper.color=Color("#f0dfb9")
    viewport.add_child(paper)
    add_label(viewport,"武器距离与握持 · 原生绘制对照",Vector2(32,16),30)
    add_label(viewport,"上一版挂点",Vector2(216,77),26)
    add_label(viewport,"新版收近",Vector2(824,77),26)
    add_label(viewport,"单独骨弩 · 2.5倍放大",Vector2(32,128),20)
    comparison_pose(viewport,Vector2(275,290),["bonebow"],true,2.5)
    comparison_pose(viewport,Vector2(875,290),["bonebow"],false,2.5)
    add_label(viewport,"六武器组合 · 2倍放大",Vector2(32,456),20)
    var ids: Array=["bonebow","powder","staff","hammer","firepot","crystal"]
    comparison_pose(viewport,Vector2(300,660),ids,true,2.0)
    comparison_pose(viewport,Vector2(900,660),ids,false,2.0)
    add_label(viewport,"同一套新素材；保留等级能力与联动，近战命中随实际环绕位置同步。",Vector2(32,880),20)
    await frames(3)
    await RenderingServer.frame_post_draw
    expect(viewport.get_texture().get_image().save_png(folder.path_join("layout_before_after.png"))==OK,"native before/after layout comparison saved")
    viewport.queue_free()
    await process_frame

func record() -> void:
    folder=capture_folder
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    root.size=Vector2i(1280,800)
    Engine.max_fps=60
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/native_v15_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.settings.autosave=false
    world.set_physics_process(false)
    await frames(25)
    await layout_sheet()
    await forge_sheet()
    prepare(["bonebow"],3)
    await shot("single_bonebow_idle")
    await ticks(8)
    await shot("single_bonebow_firing")
    await ticks(100)
    prepare(["bonebow","powder","staff","totem","firepot","crystal"],5)
    await shot("six_parked_weapons_idle")
    await ticks(10)
    await shot("six_parked_weapons_firing")
    await ticks(100)
    world.collapsed=true
    world.sync_idle_loadout()
    await shot("six_parked_weapons_compact")
    await ticks(80)
    prepare(["club","axe","blade","sling","spear","hammer"],3)
    await shot("mixed_melee_and_ranged_idle")
    await ticks(120)
    await shot("mixed_melee_and_ranged_combat")
    expect(world.hero.parts.body.material==null,"character cyan outline remains removed")
    expect(world.Rules.parked_hold_length("bonebow")<20.0,"crossbow no longer adds a full extra weapon length")
    var file:=FileAccess.open(folder.path_join("timeline.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":markers,"layout_distances":distances,"real_player_storage_used":false},"  "))
    file.close()
    file=null
    print("V15 NATIVE RESULT: %d checks, %d failures" % [checks,failures])
    await frames(20)
    world.queue_free()
    world=null
    await frames(2)
    quit(1 if failures else 0)
