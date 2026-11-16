extends SceneTree

var world
var folder: String="res://previews/native_ui_v24"
var marks: Array=[]
var checks:=0
var failures:=0

func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)

func _initialize() -> void: call_deferred("record")

func frames(count: int) -> void:
    for i in range(count): await process_frame

func pointer(at: Vector2) -> void:
    var event:=InputEventMouseMotion.new()
    event.position=at;event.global_position=at
    Input.parse_input_event(event)

func shot(key: String,extra: Dictionary={}) -> void:
    await RenderingServer.frame_post_draw
    var result: int=root.get_texture().get_image().save_png(folder.path_join(key+".png"))
    assert(result==OK,"Native screenshot must save")
    var mark: Dictionary={"name":key,"frame":Engine.get_frames_drawn(),"native_viewport":true}
    mark.merge(extra)
    marks.append(mark)

func reward(ids: Array,levels: Dictionary) -> void:
    world.upgrade_pending=true;world.upgrade_reason="chest"
    world.upgrade_choices=ids.duplicate();world.upgrade_offer_levels=levels.duplicate()
    world.hud.show_choices(ids,world.inventory,{},"chest",world.wave,levels)

func click(at: Vector2) -> void:
    pointer(at);await frames(2)
    for pressed in [true,false]:
        var event:=InputEventMouseButton.new()
        event.position=at;event.global_position=at
        event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
        Input.parse_input_event(event);await frames(2)

func record() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    root.size=Vector2i(1280,800);Engine.max_fps=60
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/native_ui_v23_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.settings.autosave=false;world.set_physics_process(false)
    world.music.set_enabled(false)
    pointer(Vector2(1200,50));await frames(30)
    world.hud.configure_save(true,false,"预览专用存档")
    await shot("home_rest")
    var enter: Button=world.hud.overlay.find_child("EnterCamp",true,false)
    pointer(enter.get_global_rect().get_center());await frames(3)
    # Freeze the actual animation at its exact midpoint, with the same production shader.
    enter.set_process(false);enter.brush_progress=0.5;enter._sync_brush()
    await shot("enter_brush_mid",{"brush_progress":enter.brush_progress})
    enter.set_process(true);await frames(20)
    await shot("enter_brush_complete")
    enter.button_down.emit();await frames(4)
    await shot("enter_pressed")
    enter.button_up.emit();await frames(10)
    pointer(Vector2(1200,50));await frames(20)
    world.start_run(false);world.set_physics_process(false)
    world.clear_weapons()
    for key in ["club","axe","blade","sling","powder","staff"]: world.grant_weapon(key)
    world.grant_weapon("club");world.wave=5;world.coins=40
    reward(["club","hammer","totem"],{"hammer":3,"totem":4})
    await frames(55)
    await shot("reward_three_weapons")
    var offer: Button=world.hud.overlay.find_child("GrowthOffer1",true,false)
    pointer(offer.get_global_rect().get_center());await frames(3)
    var skin=offer.find_child("InkFeedback",true,false)
    skin.set_process(false);skin.brush_progress=0.5;skin._sync_brush()
    await shot("reward_brush_mid",{"brush_progress":skin.brush_progress})
    skin.set_process(true);await frames(20)
    await shot("reward_hover_complete",{"brush_progress":skin.brush_progress})
    offer.button_down.emit();await frames(4)
    await shot("reward_pressed")
    offer.button_up.emit();pointer(Vector2(1200,50));await frames(15)
    var actual: Array=load("res://src/growth.gd").chest_choices(world.inventory,{},world.rng)
    expect(actual.size()==3,"actual chest reward generator still produces three choices")
    reward(["spear","hammer","boomerang","totem","bonebow","crystal"],{"spear":3,"hammer":1,"boomerang":5,"totem":4,"bonebow":1,"crystal":3})
    for label in world.hud.overlay.find_children("*","Label",true,false):
        if label.text=="精英宝箱 · 选择奖励": label.text="六项布局测试 · 实际宝箱三选一"
    await frames(55)
    await shot("reward_six_weapons")
    var sell: Button=world.hud.overlay.find_child("GrowthRewardSell4",true,false)
    var held: Array=world.inventory.duplicate(true)
    await click(sell.get_global_rect().get_center())
    await frames(55)
    expect(world.coins==51,"native click sells only the stage 5 Lv.1 bonebow for 11 coins")
    expect(world.inventory==held,"native sale preserves all six equipped weapons")
    expect(not world.upgrade_pending and world.hud.screen=="combat","native sale completes the existing scroll close and returns to combat")
    await shot("after_one_reward_sale",{"coins":world.coins,"equipped_weapons_unchanged":world.inventory==held})
    world.hud.show_choices(["power","haste","pet"],[],{})
    pointer(Vector2(1200,50));await frames(55)
    await shot("reward_attributes")
    var timeline:=FileAccess.open(folder.path_join("timeline.json"),FileAccess.WRITE)
    timeline.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":marks,"real_player_storage_used":false,"actual_chest_choice_count":actual.size(),"six_offer_page":"explicit layout-test fixture"},"  "))
    timeline.close()
    print("NATIVE UI V23 RESULT: %d checks, %d failures; %d native screenshots" % [checks,failures,marks.size()])
    world.queue_free();world=null;await frames(2);quit(1 if failures else 0)
