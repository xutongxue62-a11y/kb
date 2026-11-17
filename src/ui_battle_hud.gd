extends RefCounted
const Paper = preload("res://src/ui_battle_paper.gd")
const KeyBindings = preload("res://src/key_bindings.gd")
static func paper(h, rect: Rect2):
    var panel := Paper.new()
    panel.position = rect.position
    panel.custom_minimum_size = rect.size
    panel.size = rect.size
    h.root.add_child(panel)
    var content := Control.new()
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.custom_minimum_size = rect.size
    panel.add_child(content)
    return [panel, content]
static func label(h, parent: Node, text: String, rect: Rect2, font_size: int = 16, color: Color = Color("#233044")) -> Label:
    var node: Label = h.make_label(text, font_size, color)
    node.position = rect.position
    node.size = rect.size
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(node)
    return node
static func action(h, name_value: String, text: String, rect: Rect2, callback: Callable, primary := false) -> Button:
    var node: Button = h.make_button(text, Color("#b2533b") if primary else Color("#f1e6cd"))
    node.name = name_value
    node.set_meta("quiet_chrome", true)
    node.position = rect.position
    node.size = rect.size
    node.add_theme_font_size_override("font_size", 16)
    for state in ["normal", "hover", "pressed", "disabled"]:
        var fill: Color = Color("#ad5039") if primary else Color("#f1e6cd")
        if state == "hover": fill = fill.lightened(0.05)
        if state == "pressed": fill = fill.darkened(0.08)
        var style: StyleBoxFlat = h.style(fill)
        style.set_corner_radius_all(0)
        style.set_border_width_all(1)
        style.border_color = Color(0.22,0.17,0.13,0.4)
        node.add_theme_stylebox_override(state, style)
    if primary:
        for state in ["font_color", "font_hover_color", "font_pressed_color"]:
            node.add_theme_color_override(state, Color("#fff0d0"))
    node.pressed.connect(func():
        if not h.ui_busy(): callback.call())
    h.root.add_child(node)
    return node
static func meter(h, parent: Node, rect: Rect2, color: Color) -> ProgressBar:
    var node := ProgressBar.new()
    node.show_percentage = false
    var back: StyleBoxFlat = h.meter_style(Color("#d8cdb8"), Color(0.25,0.2,0.15,0.3))
    var fill: StyleBoxFlat = h.meter_style(color, color.darkened(0.15))
    back.set_corner_radius_all(7)
    fill.set_corner_radius_all(7)
    node.add_theme_stylebox_override("background", back)
    node.add_theme_stylebox_override("fill", fill)
    parent.add_child(node)
    node.position = rect.position
    node.size = rect.size
    return node
static func build(h) -> void:
    var status: Array = paper(h, Rect2(18, 16, 322, 148))
    h.status_strip = status[0]
    status[0].name = "VitalStrip"
    status[0].set_meta("vital_hud", true)
    label(h,status[1],"生命",Rect2(18,6,58,24),17,Color("#a74235"))
    h.health_label = label(h,status[1],"8 / 8",Rect2(202,6,102,24),18)
    h.health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    h.hp_bar = meter(h,status[1],Rect2(18,34,286,14),Color("#c25242"))
    h.hp_bar.max_value = 8
    h.hp_bar.value = 8
    label(h,status[1],"经验",Rect2(18,56,42,22),15,Color("#557758"))
    h.xp_bar = meter(h,status[1],Rect2(66,62,122,10),Color("#6a9569"))
    h.xp_label = label(h,status[1],"0 / 8",Rect2(198,54,106,24),15)
    h.xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    # Wave countdown stays in this same cluster so it remains visible when the HUD is hidden.
    h.timer_label = label(h,status[1],"第 1 关 00:30",Rect2(18,108,286,32),18)
    h.timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    h.timer_label.set_meta("vital_hud", true)
    var map_paper: Array = paper(h,Rect2(356,16,280,44))
    h.map_label = label(h,map_paper[1],"荒草原",Rect2(14,6,252,32),15,Color("#7d6746"))
    h.title_label = h.map_label
    var wallet: Array = paper(h,Rect2(751,16,280,66))
    h.coin_label = label(h,wallet[1],"金币 0",Rect2(15,7,126,46),17,Color("#956c2f"))
    h.score_label = label(h,wallet[1],"击败 0",Rect2(145,7,124,46),17)
    KeyBindings.attach_to_button(action(h,"BattlePause","暂停 / 设置",Rect2(1050,21,208,48),func():h.pause_requested.emit()), "cancel")
    h.hide_ui_button = action(h,"HideUI","隐藏界面",Rect2(350,94,170,42),func():h.toggle_hud_hidden())
    h.hide_ui_button.set_meta("hud_toggle", true)
    KeyBindings.attach_to_button(h.hide_ui_button, "hide_ui")
    KeyBindings.attach_to_button(action(h,"BattleStats","属性",Rect2(991,94,126,36),func():h.stats_requested.emit()), "stats")
    h.growth_button = action(h,"TrialGrowth","成长",Rect2(1133,94,124,36),func():h.growth_requested.emit())
    KeyBindings.attach_to_button(h.growth_button, "growth_trial")
    h.growth_button.visible = false
    var notice: Array = paper(h,Rect2(18,661,208,32))
    h.notice_label = label(h,notice[1],"",Rect2(10,3,188,25),13,Color("#5b624d"))
    h.notice_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    var link_note: Array = paper(h,Rect2(246,661,698,32))
    h.combo_label = label(h,link_note[1],"Q 切换可用联动",Rect2(10,3,678,24),14)
    h.combo_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    var dodge: Array = paper(h,Rect2(18,704,208,77))
    dodge[0].name = "DodgeStatus"
    label(h,dodge[1],"闪避 [Shift]",Rect2(17,8,112,24),17)
    h.dodge_label = label(h,dodge[1],"就绪",Rect2(130,8,61,24),15,Color("#547957"))
    h.dodge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    h.dodge_bar = meter(h,dodge[1],Rect2(18,45,171,10),Color("#6b9b9b"))
    h.dodge_bar.max_value = 1
    h.dodge_bar.value = 1
    for index in range(6):
        var slot: Array = paper(h,Rect2(246 + index * 118,704,108,77))
        var icon := TextureRect.new()
        icon.position = Vector2(35,5)
        icon.size = Vector2(39,31)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.material = h.library.weapon_material
        slot[1].add_child(icon)
        var title: Label = label(h,slot[1],"未装备",Rect2(5,37,98,18),12)
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var level: Label = label(h,slot[1],"",Rect2(5,55,98,17),11)
        level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        h.slots.append({"icon":icon,"name":title,"level":level})
    var growth: Array = paper(h,Rect2(980,658,276,64))
    h.growth_label = label(h,growth[1],"Buff 0 项 · 支援 0",Rect2(12,7,252,48),14,Color("#46675d"))
    action(h,"BattleTrial","六武器试用 [F2]",Rect2(1000,735,250,39),func():h.trial_requested.emit())
    var trial_button: BaseButton = h.root.find_child("BattleTrial", true, false) as BaseButton
    if trial_button != null:
        trial_button.visible = bool(h.debug_cheats)
        trial_button.disabled = not bool(h.debug_cheats)
        if not bool(h.debug_cheats):
            trial_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    h.boss_label = label(h,h.root,"古脊暴君",Rect2(409,141,462,23),17,Color("#a24349"))
    h.boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    h.boss_bar = meter(h,h.root,Rect2(409,166,462,12),Color("#bd6575"))
    h.boss_label.visible = false
    h.boss_bar.visible = false
