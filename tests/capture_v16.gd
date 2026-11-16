extends "res://tests/capture_v14.gd"
const CombatArt=preload("res://src/combat_art.gd")
const Rig=preload("res://src/support_rig.gd")

class EffectTile extends Node2D:
    var family: String
    func _draw() -> void:
        preload("res://src/combat_art.gd").draw(self,family,Vector2.ZERO,88.0,0.36)

class RigTile extends Node2D:
    var key: String
    var phase: float
    func _draw() -> void:
        preload("res://src/support_rig.gd").draw(self,key,{"position":Vector2.ZERO,"facing":1.0,"attack":0.0,"aim":Vector2.RIGHT,"stride":phase*6.0,"moving":key=="pet"},phase)

func sheet(size: Vector2i,title: String) -> SubViewport:
    var viewport:=SubViewport.new()
    viewport.size=size
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var paper:=ColorRect.new();paper.size=size;paper.color=Color("#f0dfb9")
    viewport.add_child(paper)
    add_label(viewport,title,Vector2(28,16),30)
    return viewport

func save_sheet(viewport: SubViewport,name: String) -> void:
    await frames(3)
    await RenderingServer.frame_post_draw
    expect(viewport.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"native sheet: "+name)
    viewport.queue_free()
    await process_frame

func effects_sheet() -> void:
    var viewport:=sheet(Vector2i(1240,1120),"命中特效 · 独立材质与轮廓")
    var families: Array=["wood","axe","blade","stone","powder","rune","spear","hammer","bonebow","fire","drum","crystal","lightning","pet"]
    var names: Array=["木棒 · 木屑钝击","石斧 · 楔形劈砍","骨刃 · 细切刃光","弹弓 · 石屑崩裂","火药 · 烟火爆破","法杖 · 碎符镶晶","骨矛 · 锥形贯刺","石槌 · 碎岩震地","骨弩 · 骨箭穿裂","火种 · 地面火舌","战鼓 · 兽纹鼓波","晶簇 · 多面碎晶","图腾 · 分叉电芒","幼龙 · 牙爪划痕"]
    for i in range(families.size()):
        var origin:=Vector2(155+(i%4)*310,175+(i/4)*245)
        var tile:=EffectTile.new();tile.family=families[i];tile.position=origin;viewport.add_child(tile)
        add_label(viewport,names[i],origin+Vector2(-126,97),20)
    add_label(viewport,"短暂、分层、留出中心；重复拟声字限量，真实伤害数字保留。",Vector2(28,1064),20)
    await save_sheet(viewport,"effect_families")

func supports_sheet() -> void:
    var viewport:=sheet(Vector2i(1240,750),"随从分件动作 · 四个时相")
    add_label(viewport,"地面幼龙：脚步按实际位移推进，停下后不再踏步。",Vector2(28,70),21)
    for i in range(4):
        var tile:=RigTile.new();tile.key="pet";tile.phase=i*0.12;tile.position=Vector2(166+i*300,290);tile.scale=Vector2.ONE*2
        viewport.add_child(tile)
    add_label(viewport,"飞行跟随物：双翼独立扑动，身体小幅起伏，投影保持落在地面。",Vector2(28,390),21)
    for i in range(4):
        var tile:=RigTile.new();tile.key="drone";tile.phase=i*0.12;tile.position=Vector2(166+i*300,638);tile.scale=Vector2.ONE*2
        viewport.add_child(tile)
    await save_sheet(viewport,"support_motion_phases")

func monsters_sheet() -> void:
    var viewport:=sheet(Vector2i(1200,1200),"怪物材质细节 · 原生前后对照")
    add_label(viewport,"上一版",Vector2(276,70),24)
    add_label(viewport,"新版：鳞纹 / 甲片 / 材质明暗",Vector2(790,70),24)
    var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/v16_baseline.json"))
    var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(str(baseline.snapshot).path_join("src/enemy_art.gd"))
    expect(script.reload()==OK,"old native enemy material can be compared read-only")
    var previous=script.new()
    var ids: Array=["hunter","charger","spitter","tank","boss","raptor","thrower","armored"]
    var names: Array=["猎手","冲锋龙","喷吐龙","厚甲龙","首领","疾爪龙","投石龙","岩甲龙"]
    for i in range(ids.size()):
        var id: String=ids[i]
        add_label(viewport,names[i],Vector2(28,151+i*127),21)
        for column in range(2):
            var view=world.DinoView.new()
            view.setup(world.library,id,115.0 if id!="boss" else 135.0,false)
            view.position=Vector2(320+column*580,175+i*127)
            if column==0:
                view.surface.hide()
                if previous.BODY_SIZES.has(id): view.sprite.texture=previous.texture(id)
            viewport.add_child(view)
    await save_sheet(viewport,"monster_materials_before_after")

func record() -> void:
    folder="res://previews/v16_native_v4"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    root.size=Vector2i(1280,800)
    Engine.max_fps=60
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/native_v16_"+str(Time.get_ticks_usec()))
    root.add_child(world);world.settings.autosave=false;world.set_physics_process(false)
    await frames(25)
    await effects_sheet()
    await supports_sheet()
    await monsters_sheet()
    await forge_sheet()
    prepare(["sling"],3)
    world.clear_enemies()
    world.buff_levels.pet=3;world.buff_levels.drone=3;world.refresh_stats()
    world.update_companions(0.0)
    await shot("supports_idle")
    for i in range(120):
        world.simulate(1.0/60.0,Vector2.RIGHT)
        await process_frame
        if i==60: await shot("supports_walking")
    expect(world.companions.states.pet.stride>1.0,"ground pet follows with actual travelled gait")
    await shot("supports_following")
    prepare(["club","axe","blade","sling","spear","hammer"],5)
    await ticks(35);await shot("melee_material_impacts")
    await ticks(65)
    prepare(["staff","powder","totem","bonebow","firepot","crystal"],5)
    await ticks(65);await shot("ranged_material_impacts")
    await ticks(65)
    prepare(["wardrum","firepot","crystal","sling","bonebow","totem"],5)
    world.select_link("fire_drum")
    await ticks(100);await shot("fire_drum_materials")
    await ticks(80)
    expect(world.hero.parts.body.material==null,"accepted hero has no cyan outline")
    expect(world.Rules.MELEE_ORBIT==100.0,"accepted v15 weapon spacing remains unchanged")
    var file:=FileAccess.open(folder.path_join("timeline.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":markers,"real_player_storage_used":false,"source_version":"v0.16"},"  "));file.close();file=null
    print("V16 NATIVE RESULT: %d checks, %d failures" % [checks,failures])
    await frames(15)
    world.queue_free();world=null
    await frames(2)
    quit(1 if failures else 0)
