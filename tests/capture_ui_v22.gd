extends SceneTree
var world
var folder: String
var tag: String="after"
var shots: Array=[]
var checks:=0
var failures:=0
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void: call_deferred("record")
func frames(count: int) -> void:
    for i in range(count): await process_frame
func move_pointer(at: Vector2) -> void:
    var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
    Input.parse_input_event(motion)
func button(key: String) -> Button: return world.hud.overlay.find_child(key,true,false) as Button
func shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    expect(root.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"native UI image: "+name)
    var mark: Dictionary={"name":name,"frame":Engine.get_frames_drawn()}
    var enter: Button=button("EnterCamp")
    if enter!=null:
        var rect: Rect2=enter.get_global_rect()
        mark["button_position"]=[rect.position.x,rect.position.y]
        mark["button_size"]=[rect.size.x,rect.size.y]
        mark["brush_progress"]=enter.get("brush_progress")
    shots.append(mark)
func record() -> void:
    if not OS.get_cmdline_user_args().is_empty(): tag=OS.get_cmdline_user_args()[0]
    folder="res://previews/ui_v22_"+tag
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    root.size=Vector2i(1280,800);Engine.max_fps=60
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/ui_v22_"+tag+"_"+str(Time.get_ticks_usec()))
    root.add_child(world);world.settings.autosave=false;world.set_physics_process(false)
    world.music.set_enabled(false)
    move_pointer(Vector2(1200,50));await frames(30)
    world.hud.configure_save(true,false,"预览专用存档")
    await shot("home_rest")
    var enter: Button=button("EnterCamp")
    move_pointer(enter.get_global_rect().get_center())
    await frames(2);await shot("enter_brush_early")
    await frames(3);await shot("enter_brush_mid")
    await frames(7);await shot("enter_brush_complete")
    move_pointer(Vector2(1200,50));await frames(16)
    for key in ["ContinueSave","HelpGameplay"]:
        move_pointer(button(key).get_global_rect().get_center())
        await frames(5);await shot(key+"_brush")
        await frames(16)
        move_pointer(Vector2(1200,50));await frames(14)
    if tag!="before":
        expect(world.hud.ui_audio._last_play_ms.has("button_hover"),"actual pointer hover reaches a native audio voice")
        expect(world.hud.ui_audio._voices.size()==4,"hover uses the existing bounded audio pool")
    world.hud.show_choices(["power","haste","pet"],[],{})
    await frames(55);await shot("rough_parchment_scroll")
    var offer: Button=world.hud.overlay.find_child("GrowthOffer0",true,false) as Button
    if offer!=null:
        move_pointer(offer.get_global_rect().get_center())
        await frames(5);await shot("scroll_card_brush")
    await frames(18)
    world.hud.show_title()
    move_pointer(Vector2(1200,50))
    await frames(35)
    world.hud.show_help("gameplay",false)
    await frames(45);await shot("rough_parchment_help")
    await frames(20)
    var file:=FileAccess.open(folder.path_join("timeline.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":shots,"tag":tag,"real_player_storage_used":false},"  "));file.close();file=null
    print("UI V22 NATIVE RESULT: %d checks, %d failures" % [checks,failures])
    world.queue_free();world=null;await frames(2)
    quit(1 if failures else 0)
