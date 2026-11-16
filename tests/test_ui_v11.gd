extends SceneTree
class AnimatedHud:
    extends "res://src/hud.gd"
    func can_animate() -> bool: return true
    func snapshot_ui() -> Texture2D: return null
    func play_ui(_key: String) -> void: pass
var checks := 0
var failures := 0
func expect(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("FAIL: " + message)
func _initialize() -> void: call_deferred("run_checks")
func run_checks() -> void:
    Engine.max_fps = 120
    root.size = Vector2i(1280,800)
    var h := AnimatedHud.new()
    root.add_child(h)
    h.setup(load("res://src/asset_library.gd").new())
    expect(h.hp_bar.size.y<=16.1 and h.dodge_bar.size.y<=10.1,"battle meters respect designed height after theme setup")
    h.pulse(h.hp_bar)
    await create_timer(0.12).timeout
    expect(is_equal_approx(h.hp_bar.scale.x,1.0),"continuous lava feedback cannot widen the health bar outside its paper")
    h.show_cast()
    await process_frame
    var start: Button = h.overlay.find_child("StartSling",true,false)
    var skin = start.find_child("InkFeedback",true,false)
    expect(skin.get_script().resource_path.ends_with("ui_ink_button_fx.gd"),"all page buttons use the new color-wash paper skin")
    expect(start.get_theme_stylebox("hover") is StyleBoxEmpty,"no pill or native hover frame remains")
    var normal: Color = skin.fill_color(0)
    var hovered: Color = skin.fill_color(1)
    expect(absf(normal.r-hovered.r)+absf(normal.g-hovered.g)>0.35,"hover changes hue noticeably instead of tiny lightening")
    h.show_choices(["powder","pet","drone"],[],{})
    await process_frame
    for image in h.overlay.find_children("*","TextureRect",true,false):
        expect(image.size.x<=88.1 and image.size.y<=72.1,"offer art respects its card-sized bounds after texture assignment")
        var used: Rect2i=image.texture.get_image().get_used_rect()
        expect(used.has_area(),"offer illustration has visible pixels")
    h.update_state(8,0,0,0,8,[],false,load("res://src/catalog.gd").LINKS.none,false,true)
    expect(not h.growth_button.is_visible_in_tree(),"trial HUD shortcut cannot reappear above a modal scroll")
    h.show_choices(["power","haste","pet"],[],{})
    await create_timer(0.70).timeout
    var waited := 0
    while h.ui_busy() and waited < 160:
        await process_frame
        waited += 1
    var frame = h.overlay.find_child("HanddrawnPaper",true,false)
    var safe: Rect2 = frame.visible_content_rect()
    expect(safe.position.x>=36 and safe.position.y>=20,"scroll content leaves safe space around physical caps")
    expect(frame.get_child(frame.get_child_count()-1).name=="RollerForeground","rollers render after content rather than being covered")
    var selections: Array = []
    h.choice_selected.connect(func(key: String):
        selections.append(key)
        h.hide_menu())
    h.choose_index(0)
    expect(h.scroll_closing and selections.is_empty(),"choosing starts a real close without consuming the upgrade early")
    h.choose_index(1)
    await create_timer(0.42).timeout
    expect(selections==["power"] and h.screen=="combat","one upgrade commits only after the scroll has rolled shut")
    var random := RandomNumberGenerator.new()
    random.seed=11
    var stock: Array = load("res://src/economy.gd").stock([],{},2,random)
    h.show_shop(stock,500,2,[],{},6,8,false)
    await process_frame
    var cards: Array = h.overlay.find_children("ShopOffer*","Button",true,false)
    expect(cards.size()==6,"the actual shop lays out six unique offers")
    for button in cards:
        var rect: Rect2 = button.get_global_rect()
        expect(rect.position.y>90 and rect.end.y<740,"every shop card stays inside its scroll")
    h.update_round(4,24,false,0)
    expect(h.timer_label.get_theme_color("font_color").r>0.6 and h.timer_label.text.contains("最后"),"last ten seconds have explicit red countdown")
    h.update_round(5,0,true,0)
    expect(not h.timer_label.text.contains("最后"),"unlimited boss stage does not inherit a false urgent countdown")
    var fx = load("res://src/effects.gd").new()
    root.add_child(fx)
    for i in 100: fx.damage_number(Vector2.ZERO,10,true)
    expect(fx.particles.size()==1 and is_equal_approx(fx.particles[0].value,1000),"simultaneous damage feedback sums values without covering the target")
    for i in 30:
        fx.advance(0.03)
        fx.damage_number(Vector2(3,0),10,i%2==0)
    expect(fx.particles.filter(func(p): return p.kind=="number").size()<=4,"sustained attack feedback stays locally bounded")
    fx.queue_free()
    h.queue_free()
    await process_frame
    print("UI V11 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
