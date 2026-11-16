extends SceneTree
var world
var folder: String="D:/Codex/场景建模/独立游戏/原始人大作战_Godot_v0.1/previews/ui_v29_installed_controls"
var marks: Array=[]
var checks:=0
var failures:=0
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void: call_deferred("record")
func frames(count: int) -> void:
    for i in range(count): await process_frame
func button(key: String) -> Button: return world.hud.overlay.find_child(key,true,false) as Button
func state(node: Button,progress: float,pressed: float=0.0) -> void:
    if node.has_meta("home_paper_action"):
        node.set_process(false);node.brush_progress=progress;node.target_hover=progress
        node.press_amount=pressed;node.target_press=pressed
        node._process(0)
    var skin=node.find_child("InkFeedback",true,false)
    if skin!=null:
        skin.set_process(false);skin.brush_progress=progress;skin.target_hover=progress
        skin.down=pressed;skin.target_down=pressed;skin._process(0)
func rest() -> void:
    for node in world.hud.overlay.find_children("*","Button",true,false): state(node,0.0)
func shot(key: String,extra: Dictionary={}) -> void:
    await RenderingServer.frame_post_draw
    expect(root.get_texture().get_image().save_png(folder.path_join(key+".png"))==OK,"native image saved: "+key)
    var mark: Dictionary={"name":key,"native_viewport":true}
    mark.merge(extra);marks.append(mark)
func click(node: Button) -> void:
    var waited: int=0
    while world.hud.ui_busy() and waited<120:
        await frames(1);waited+=1
    expect(not world.hud.ui_busy(),"setting is ready before the native GUI click")
    root.gui_disable_input=false
    var at: Vector2=node.get_global_rect().get_center()
    var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
    root.push_input(motion,true)
    for pressed in [true,false]:
        var event:=InputEventMouseButton.new()
        event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
        root.push_input(event,true)
    root.gui_disable_input=true
    await frames(3)
func check_switches() -> void:
    for key in ["MusicEnabled","Autosave"]:
        var node: Button=button(key)
        var label: Label=node.find_child("SwitchState",false,false)
        expect(label!=null and label.text==node.text,key+" status follows the real setting")
        if label!=null:
            expect(node.get_global_rect().encloses(label.get_global_rect()),key+" status label stays inside its paper button")
            expect(label.get_minimum_size().x<=label.size.x,key+" text fits the reserved slot")
func record() -> void:
    DirAccess.make_dir_recursive_absolute(folder)
    root.size=Vector2i(1280,800);root.gui_disable_input=true;Engine.max_fps=60
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/control_preview_"+str(Time.get_ticks_usec()))
    root.add_child(world);world.settings.autosave=false;world.set_physics_process(false)
    world.music.set_enabled(false)
    await frames(30)
    world.hud.configure_save(true,false,"预览专用存档")
    rest();await shot("home_rest")
    state(button("EnterCamp"),0.5)
    await shot("home_brush_mid",{"brush_progress":0.5})
    state(button("EnterCamp"),1.0)
    await shot("home_hover_complete",{"brush_progress":1.0})
    state(button("EnterCamp"),1.0,1.0)
    await shot("home_pressed")
    world.hud.music_enabled=true;world.hud.autosave_enabled=false
    world.hud.show_settings(false);await frames(35);rest()
    state(button("MusicEnabled"),1.0);state(button("Autosave"),0.5)
    check_switches();await shot("settings_hover")
    await click(button("MusicEnabled"));await click(button("Autosave"))
    expect(not world.hud.music_enabled and world.hud.autosave_enabled,"native mouse clicks switch music off and autosave on")
    rest();state(button("MusicEnabled"),0.5);state(button("Autosave"),1.0)
    check_switches();await shot("settings_toggled")
    # Remove only the two status labels for a local pixel-boundary diagnostic.
    button("MusicEnabled").state_label.hide();button("Autosave").state_label.hide()
    await shot("settings_without_status_text")
    world.settings.autosave=false
    world.start_run(false);world.set_physics_process(false);world.clear_weapons()
    for key in ["club","axe","blade","sling","powder","staff"]: world.grant_weapon(key)
    world.grant_weapon("club");world.wave=5
    world.hud.show_choices(["club","hammer","totem"],world.inventory,{},"chest",5,{"hammer":3,"totem":4})
    await frames(55);rest();await shot("reward_rest")
    state(button("GrowthOffer1"),0.5)
    await shot("reward_brush_mid",{"brush_progress":0.5})
    state(button("GrowthOffer1"),0.0)
    var sell: Button=button("GrowthRewardSell1")
    state(sell,0.5)
    await shot("sell_brush_mid",{"brush_progress":0.5,"sale_quote":sell.text})
    state(sell,1.0)
    await shot("sell_hover_complete",{"brush_progress":1.0,"sale_quote":sell.text})
    state(sell,1.0,1.0);await shot("sell_pressed")
    var report:=FileAccess.open(folder.path_join("preview.json"),FileAccess.WRITE)
    report.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":marks,"applied_to_formal_game":true,"real_player_storage_used":false,"actual_chest_choice_count":3},"  "))
    report.close()
    print("CONTROLS PREVIEW RESULT: %d checks, %d failures; %d native screenshots" % [checks,failures,marks.size()])
    world.queue_free();world=null;await frames(2);quit(1 if failures else 0)
