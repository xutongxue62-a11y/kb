extends RefCounted

const Paper = preload("res://src/ui_paper.gd")
const Catalog = preload("res://src/catalog.gd")
const Growth = preload("res://src/growth.gd")
const ActorView = preload("res://src/actor_view.gd")
const HomeAction = preload("res://src/ui_home_action.gd")
const HomeStage = preload("res://src/ui_home_stage.gd")
const PaperToggle = preload("res://src/ui_paper_toggle.gd")
const KeyBindings = preload("res://src/key_bindings.gd")
const INK = Color("#17253a")
const IVORY = Color("#f2e8d2")
const RED = Color("#af4833")

static func label(h, parent: Node, text: String, rect: Rect2, font_size: int = 20, color: Color = INK, bold: bool = false) -> Label:
    var node: Label = h.make_display(text, font_size, color) if bold else h.make_label(text, font_size, color)
    node.position = rect.position
    node.size = rect.size
    node.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(node)
    return node

static func line(parent: Node, at: Vector2, width: float, color: Color = INK) -> void:
    var rule := ColorRect.new()
    rule.position = at
    rule.size = Vector2(width, 2)
    rule.color = color
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(rule)

static func button(h, parent: Node, key: String, text: String, rect: Rect2, callback: Callable, primary: bool = false, size: int = 22) -> Button:
    var result: Button = h.action(parent, key, text, callback, RED if primary else IVORY)
    result.position = rect.position
    result.size = rect.size
    result.custom_minimum_size = rect.size
    result.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    result.add_theme_font_size_override("font_size", size)
    result.set_meta("ink_primary", primary)
    result.add_theme_font_override("font", h.display_font)
    result.add_theme_color_override("font_color", IVORY if primary else INK)
    result.add_theme_color_override("font_hover_color", IVORY if primary else INK)
    result.add_theme_color_override("font_pressed_color", IVORY if primary else INK)
    result.add_theme_stylebox_override("normal", action_style(RED if primary else IVORY, IVORY if primary else Color(INK, 0.6)))
    result.add_theme_stylebox_override("hover", action_style(Color("#c15b3c") if primary else Color("#faf2df"), IVORY if primary else RED))
    result.add_theme_stylebox_override("pressed", action_style(Color("#923b2c") if primary else Color("#ded0b5"), INK))
    result.add_theme_stylebox_override("disabled", action_style(Color("#dacfb9"), Color("#ada28e")))
    result.add_theme_color_override("font_disabled_color", Color("#968b79"))
    return result

static func action_style(fill: Color, border: Color) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = fill
    box.border_color = border
    box.set_border_width_all(2)
    box.set_corner_radius_all(0)
    box.content_margin_left = 14
    box.content_margin_right = 14
    box.content_margin_top = 8
    box.content_margin_bottom = 8
    box.shadow_color = Color(0.025, 0.045, 0.07, 0.4)
    box.shadow_offset = Vector2(3, 4)
    box.shadow_size = 1
    return box

static func paper(h, rect: Rect2, animate: bool = true, mode: String = "fold"):
    var sheet = Paper.new()
    sheet.name = "HanddrawnPaper"
    sheet.opening_mode = mode
    sheet.position = rect.position
    sheet.size = rect.size
    h.overlay.add_child(sheet)
    if animate and h.can_animate():
        var tween: Tween = h.create_tween()
        if mode == "compose":
            h.lock_ui(0.46)
            sheet.position.y += 24
            sheet.modulate.a = 0
            sheet.pivot_offset = sheet.size * 0.5
            sheet.scale = Vector2.ONE * 0.985
            tween.set_parallel(true)
            tween.tween_property(sheet, "position", rect.position, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
            tween.tween_property(sheet, "modulate:a", 1.0, 0.24).set_delay(0.06)
            tween.tween_property(sheet, "scale", Vector2.ONE, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        else:
            sheet.reveal = 0.035
            h.lock_ui(0.34)
            tween.tween_property(sheet, "reveal", 1.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    return sheet

static func nav_arrow(h, parent: Node, key: String, direction: int, rect: Rect2) -> Button:
    var result: Button = h.action(parent, key, "", func(): h.change_character(direction))
    result.set_meta("ink_nav", direction)
    result.position = rect.position
    result.custom_minimum_size = rect.size
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        result.add_theme_stylebox_override(state, StyleBoxEmpty.new())
    result.size = rect.size
    return result

static func flat_background(h) -> void:
    h.present_backdrop("arena")
    h.overlay.color = Color(0.025, 0.06, 0.12, 0.88)

static func portrait(h, parent: Node, at: Vector2, scale_value: float = 3.4, character_id: String = "caveman") -> void:
    var actor = ActorView.new()
    actor.name = "CastPortrait"
    parent.add_child(actor)
    actor.setup(h.library, character_id)
    actor.position = at
    actor.scale = Vector2.ONE * scale_value
    actor.get_node("PlayerMarker").hide()
    for sprite in actor.parts.values():
        sprite.material = h.library.weapon_material

static func weapon(h, parent: Node, at: Vector2, key: String = "sling", size_value: float = 90.0) -> void:
    var sprite: Sprite2D = h.library.make_weapon(key, size_value)
    sprite.position = at
    parent.add_child(sprite)

static func title(h) -> void:
    h.present_backdrop("arena")
    h.backdrop.texture = load("res://assets/ui/title_empty_v09.png")
    h.overlay.color = Color.TRANSPARENT
    var stage := HomeStage.new()
    stage.name = "HomeStage"
    h.overlay.add_child(stage)
    stage.setup(h.library)
    var logo := TextureRect.new()
    logo.name = "GameTitleInk"
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    var atlas := AtlasTexture.new()
    atlas.atlas = load("res://assets/ui/title_logo_ink_v01.png")
    atlas.region = Rect2(120, 144, 1220, 834)
    logo.texture = atlas
    logo.position = Vector2(36, 140)
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo.size = Vector2(365, 260)
    logo.material = h.library.weapon_material
    logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    h.overlay.add_child(logo)
    home_button(h, "EnterCamp", "进入营地", Rect2(38, 473, 350, 74), func(): h.show_cast(), true, 29, "enter")
    var resume: Button = home_button(h, "ContinueSave", "继续存档", Rect2(40, 572, 262, 56), func(): h.show_continue(), false, 22, "continue")
    resume.disabled = not h.save_available
    resume.tooltip_text = h.save_note if h.save_available else "尚无可继续的旅程"
    h.save_note_label = label(h, h.overlay, "可继续上次旅程" if h.save_available else "准备好，开始一段新旅程", Rect2(46, 642, 350, 32), 16, Color("#d1c7b4"))
    home_button(h, "HelpGameplay", "玩法说明", Rect2(36, 712, 174, 44), func(): h.show_help("gameplay", false), false, 18, "help")
    home_button(h, "Settings", "设置", Rect2(220, 712, 136, 44), func(): h.show_settings(false), false, 18, "settings")

static func home_button(h, key: String, text: String, rect: Rect2, callback: Callable, primary: bool, font_size: int, icon_key: String) -> Button:
    var result := HomeAction.new()
    result.name = key
    result.text = text
    result.position = rect.position
    result.size = rect.size
    result.custom_minimum_size = rect.size
    result.primary = primary
    result.paper_icon = icon_key
    result.add_theme_font_override("font", h.display_font)
    result.add_theme_font_size_override("font_size", font_size)
    for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        result.add_theme_color_override(state, IVORY if primary else INK)
    result.add_theme_color_override("font_disabled_color", Color("#6e6a60"))
    # Every title action opens a page whose own animation supplies its one cue.
    result.pressed.connect(func():
        if not h.ui_busy(): callback.call())
    h.bind_hover_audio(result)
    h.overlay.add_child(result)
    return result

static func character_cutout(h, parent: Node, rect: Rect2, path: String) -> Control:
    var host := Control.new()
    host.name = "CastPortrait"
    host.position = rect.position
    host.size = rect.size
    host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(host)
    var view := TextureRect.new()
    view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    view.size = rect.size
    if not path.is_empty() and ResourceLoader.exists(path):
        view.texture = load(path)
    host.add_child(view)
    return host

static func cast(h) -> void:
    flat_background(h)
    var cast_title: Label = label(h, h.overlay, "选择角色", Rect2(48, 24, 600, 78), 52, IVORY, true)
    cast_title.name = "CastTitle"
    line(h.overlay, Vector2(50, 107), 278, RED)
    button(h, h.overlay, "Settings", "设置", Rect2(1100, 35, 128, 48), func(): h.show_settings(false), false, 19)
    var sheet = paper(h, Rect2(52, 134, 1176, 520), true, "compose")
    var body: Control = sheet.content
    line(body, Vector2(572, 40), 2, Color(INK, 0.3))
    var divider := ColorRect.new()
    divider.position = Vector2(572, 40)
    divider.size = Vector2(1.5, 438)
    divider.color = Color(INK, 0.4)
    divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    body.add_child(divider)
    var shown: String = h.displayed_character() if h.has_method("displayed_character") else h.selected_character
    var profile: Dictionary = Catalog.character(shown)
    var starter: String = str(profile.get("starting_weapon", "sling"))
    var weapon_name: String = str(profile.get("weapon_label", Catalog.WEAPONS.get(starter, {}).get("name", starter)))
    var portrait: Control = character_cutout(h, body, Rect2(116, 28, 320, 360), str(profile.get("portrait", "")))
    portrait.mouse_filter = Control.MOUSE_FILTER_STOP
    portrait.tooltip_text = "点击画像确认选择该角色"
    portrait.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not h.ui_busy():
            h.commit_character(shown))
    weapon(h, body, Vector2(459, 176), starter, 92)
    var previous: Button = nav_arrow(h, body, "PrevCharacter", -1, Rect2(166, 408, 52, 44))
    var next: Button = nav_arrow(h, body, "NextCharacter", 1, Rect2(346, 408, 52, 44))
    previous.disabled = Catalog.CHARACTER_ORDER.size() <= 1
    next.disabled = previous.disabled
    previous.tooltip_text = "当前只有一位角色" if previous.disabled else "上一位角色"
    next.tooltip_text = "当前只有一位角色" if next.disabled else "下一位角色"
    var index: int = maxi(0, Catalog.CHARACTER_ORDER.find(shown))
    var count: Label = label(h, body, "%d / %d" % [index + 1, Catalog.CHARACTER_ORDER.size()], Rect2(228, 411, 108, 35), 20)
    count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    if shown == h.selected_character:
        label(h, body, "✓ 已选择", Rect2(216, 454, 220, 38), 24, RED, true)
    label(h, body, str(profile.get("name", "原始人")), Rect2(620, 28, 500, 88), 58, INK, true)
    label(h, body, "初始武器", Rect2(620, 132, 400, 32), 21, INK, true)
    weapon(h, body, Vector2(664, 212), starter, 76)
    label(h, body, weapon_name, Rect2(730, 168, 370, 50), 34, INK, true)
    var blurbs := {"sling": "自动瞄准 · 快速连射", "spear": "自动瞄准 · 贯刺穿透", "club": "自动瞄准 · 近战重击", "bonebow": "自动瞄准 · 贯穿直射", "staff": "自动瞄准 · 符能散射", "firepot": "自动瞄准 · 定点火场", "totem": "自动瞄准 · 连锁雷击"}
    var blurb: String = str(profile.get("weapon_blurb", blurbs.get(starter, "自动瞄准")))
    label(h, body, blurb, Rect2(730, 223, 388, 34), 20)
    line(body, Vector2(620, 281), 486, Color(INK, 0.6))
    label(h, body, "角色能力 / 技能", Rect2(620, 288, 486, 32), 22, INK, true)
    var y: float = 318
    for skill in profile.get("skills", []):
        label(h, body, str(skill.get("name", "")), Rect2(626, y, 470, 28), 22, INK, true)
        label(h, body, str(skill.get("description", "")), Rect2(626, y + 28, 470, 28), 16, Color("#506071"))
        y += 62
    KeyBindings.attach_to_button(button(h, h.overlay, "Back", "← 返回首页", Rect2(52, 705, 258, 52), func(): h.show_title(), false, 21), "cancel")
    var progress: Dictionary = h.character_best_wave if h.get("character_best_wave") != null else {}
    var unlocked: bool = Catalog.is_character_unlocked(shown, progress)
    var note: String = ""
    if Catalog.shows_preview_unlock(shown, progress):
        note = "试玩提前解锁"
    elif not unlocked:
        note = Catalog.unlock_requirement_text(shown)
    if not note.is_empty():
        var note_y: float = minf(y + 10.0, 448.0)
        if Catalog.shows_preview_unlock(shown, progress):
            var condition: Label = label(h, body, Catalog.unlock_requirement_text(shown), Rect2(626, note_y, 470, 24), 16, Color("#506071"))
            condition.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
            condition.name = "UnlockCondition"
            note_y += 24
        var note_label: Label = label(h, body, note, Rect2(626, note_y, 470, 30), 22, RED, true)
        note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        note_label.name = "UnlockNote"
    for id in Catalog.CHARACTER_ORDER:
        var entry: Dictionary = Catalog.character(id)
        var key: String = str(entry.get("confirm_button", "StartSling"))
        var weapon_id: String = str(entry.get("starting_weapon", "sling"))
        var confirm: Button = button(h, h.overlay, key, "→  确认出发", Rect2(848, 694, 380, 66), func(): h.confirm_cast(weapon_id), true, 27)
        KeyBindings.attach_to_button(confirm, "confirm")
        confirm.visible = id == shown
        if id == shown and not Catalog.can_start_character(id, progress):
            confirm.disabled = true
            confirm.tooltip_text = Catalog.unlock_requirement_text(id)
    h.stage_panel(body)

static func modal(h, rect: Rect2):
    h.present_backdrop("arena")
    h.overlay.color = Color(0.04, 0.09, 0.17, 0.64)
    if h.modal_snapshot != null:
        var bg := TextureRect.new()
        bg.texture = h.modal_snapshot
        bg.size = Vector2(1280, 800)
        bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        bg.stretch_mode = TextureRect.STRETCH_SCALE
        bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        h.overlay.add_child(bg)
        var dim := ColorRect.new()
        dim.size = Vector2(1280, 800)
        dim.color = Color(0.025, 0.06, 0.13, 0.66)
        dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
        h.overlay.add_child(dim)
    return paper(h, rect)

static func volume_slider(h, node_name: String, kind: String, value: float, rect: Rect2) -> HSlider:
    var slider := HSlider.new()
    slider.name = node_name
    slider.position = rect.position
    slider.size = rect.size
    slider.custom_minimum_size = Vector2(maxf(40.0, rect.size.x), maxf(34.0, rect.size.y))
    slider.min_value = 0.0
    slider.max_value = 1.0
    slider.step = 0.01
    slider.value = clampf(value, 0.0, 1.0)
    slider.tooltip_text = "音乐音量" if kind == "music" else "音效音量"
    slider.value_changed.connect(func(amount: float):
        if kind == "music":
            h.music_volume = amount
        else:
            h.sfx_volume = amount
        var value_label: Label = slider.get_parent().find_child("MusicVolumeValue" if kind == "music" else "SfxVolumeValue", false, false) as Label if slider.get_parent() != null else null
        if value_label != null and h.has_method("volume_percent"):
            value_label.text = h.volume_percent(amount)
        h.volume_changed.emit(kind, amount))
    return slider

static func settings(h, in_run: bool) -> void:
    var sheet = modal(h, Rect2(254, 12, 772, 776))
    var body: Control = sheet.content
    label(h, body, "设置", Rect2(48, 25, 550, 73), 50, INK, true)
    button(h, body, "CloseModal", "×", Rect2(674, 24, 52, 48), func(): h.close_front_modal(), false, 30)
    line(body, Vector2(48, 112), 674, RED)
    label(h, body, "声音与存档", Rect2(48, 120, 630, 34), 26, INK, true)
    label(h, body, "背景音乐", Rect2(48, 162, 400, 42), 25, INK, true)
    var music_switch := PaperToggle.new()
    music_switch.name = "MusicEnabled"
    music_switch.position = Vector2(552, 156)
    music_switch.size = Vector2(168, 50)
    music_switch.button_pressed = h.music_enabled
    music_switch.text = "开启" if h.music_enabled else "关闭"
    music_switch.add_theme_font_size_override("font_size",21)
    music_switch.add_theme_stylebox_override("normal",action_style(IVORY,Color(INK,0.6)))
    music_switch.add_theme_stylebox_override("pressed",action_style(RED,IVORY))
    music_switch.toggled.connect(func(value: bool):
        if h.ui_busy():
            music_switch.set_pressed_no_signal(h.music_enabled)
            return
        h.music_enabled = value
        music_switch.text = "开启" if value else "关闭"
        h.play_ui("button_press")
        h.music_changed.emit(value))
    body.add_child(music_switch)
    h.music_toggle = music_switch
    h.press_motion(music_switch)
    label(h,body,"关闭后淡出背景音乐，保留战斗音效",Rect2(48,210,674,26),17,Color("#5c625e"))
    label(h, body, "音乐音量", Rect2(48, 244, 220, 40), 22, INK, true)
    body.add_child(volume_slider(h, "MusicVolume", "music", h.music_volume, Rect2(280, 246, 360, 40)))
    var music_value: Label = label(h, body, h.volume_percent(h.music_volume) if h.has_method("volume_percent") else "100%", Rect2(650, 246, 80, 40), 20, INK, true)
    music_value.name = "MusicVolumeValue"
    music_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    label(h, body, "音效音量", Rect2(48, 292, 220, 40), 22, INK, true)
    body.add_child(volume_slider(h, "SfxVolume", "sfx", h.sfx_volume, Rect2(280, 294, 360, 40)))
    var sfx_value: Label = label(h, body, h.volume_percent(h.sfx_volume) if h.has_method("volume_percent") else "100%", Rect2(650, 294, 80, 40), 20, INK, true)
    sfx_value.name = "SfxVolumeValue"
    sfx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    line(body,Vector2(48,344),674,Color(INK,0.35))
    label(h, body, "伤害数字", Rect2(48, 354, 400, 42), 25, INK, true)
    var numbers := PaperToggle.new()
    numbers.name = "DamageNumbers"
    numbers.position = Vector2(552, 348)
    numbers.size = Vector2(168, 50)
    numbers.button_pressed = h.damage_numbers_enabled
    numbers.text = "开启" if h.damage_numbers_enabled else "关闭"
    numbers.add_theme_font_size_override("font_size",21)
    numbers.add_theme_stylebox_override("normal",action_style(IVORY,Color(INK,0.6)))
    numbers.add_theme_stylebox_override("pressed",action_style(RED,IVORY))
    numbers.toggled.connect(func(value: bool):
        if h.ui_busy():
            numbers.set_pressed_no_signal(h.damage_numbers_enabled)
            return
        h.damage_numbers_enabled = value
        numbers.text = "开启" if value else "关闭"
        h.play_ui("button_press")
        h.damage_numbers_changed.emit(value))
    body.add_child(numbers)
    h.press_motion(numbers)
    label(h, body, "全屏显示", Rect2(48, 404, 400, 42), 25, INK, true)
    var mode := PaperToggle.new()
    mode.name = "FullscreenMode"
    mode.position = Vector2(552, 398)
    mode.size = Vector2(168, 50)
    mode.button_pressed = h.fullscreen_enabled
    mode.text = "全屏" if h.fullscreen_enabled else "窗口"
    mode.add_theme_font_size_override("font_size",21)
    mode.add_theme_stylebox_override("normal",action_style(IVORY,Color(INK,0.6)))
    mode.add_theme_stylebox_override("pressed",action_style(RED,IVORY))
    mode.toggled.connect(func(value: bool):
        if h.ui_busy():
            mode.set_pressed_no_signal(h.fullscreen_enabled)
            return
        h.fullscreen_enabled = value
        mode.text = "全屏" if value else "窗口"
        h.play_ui("button_press")
        h.display_mode_changed.emit(value))
    body.add_child(mode)
    h.press_motion(mode)
    line(body,Vector2(48,456),674,Color(INK,0.35))
    label(h, body, "自动存档", Rect2(48, 466, 400, 42), 25, INK, true)
    var toggle := PaperToggle.new()
    toggle.name = "Autosave"
    toggle.text = "开启" if h.autosave_enabled else "关闭"
    toggle.position = Vector2(552, 460)
    toggle.size = Vector2(168, 50)
    toggle.button_pressed = h.autosave_enabled
    toggle.add_theme_font_size_override("font_size",21)
    toggle.add_theme_stylebox_override("normal",action_style(IVORY,Color(INK,0.6)))
    toggle.add_theme_stylebox_override("pressed",action_style(RED,IVORY))
    toggle.toggled.connect(func(value: bool):
        if h.ui_busy():
            toggle.set_pressed_no_signal(h.autosave_enabled)
            return
        h.autosave_enabled = value
        toggle.text = "开启" if value else "关闭"
        h.play_ui("button_press")
        h.settings_changed.emit(value))
    body.add_child(toggle)
    h.autosave_toggle = toggle
    h.press_motion(toggle)
    label(h,body,"结算、购买与返回首页时自动保存",Rect2(48,514,674,24),17,Color("#5c625e"))
    line(body,Vector2(48,548),674,Color(INK,0.35))
    h.save_note_label = label(h,body,h.save_note,Rect2(48,558,674,44),16,Color("#586e55"))
    h.save_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label(h,body,"也可按取消键关闭",Rect2(48,640,190,32),16)
    button(h,body,"OpenKeyBindings","改按键",Rect2(250,632,200,54),func():h.show_key_bindings(in_run),false,22)
    button(h,body,"Back","完成",Rect2(540,632,180,54),func():h.close_front_modal(),true,25)

static func continued(h) -> void:
    var sheet = modal(h, Rect2(230, 91, 820, 618))
    var body: Control = sheet.content
    label(h, body, "继续存档", Rect2(48, 25, 610, 75), 49, INK, true)
    button(h, body, "CloseModal", "×", Rect2(720, 24, 52, 48), func(): h.close_front_modal(), false, 30)
    line(body, Vector2(48, 112), 724, RED)
    var preview := Control.new()
    preview.name = "SavePreview"
    preview.size = Vector2(820, 450)
    preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    body.add_child(preview)
    label(h, preview, "上次的旅程", Rect2(48, 136, 700, 44), 27, INK, true)
    var state: Dictionary = h.save_summary
    var starter: String = str(state.get("starting_weapon", "sling"))
    if not Catalog.WEAPONS.has(starter):
        starter = "sling"
    var character_id: String = str(state.get("character_id", Catalog.character_id_for_weapon(starter)))
    if not Catalog.CHARACTERS.has(character_id):
        character_id = Catalog.character_id_for_weapon(starter)
    portrait(h, preview, Vector2(176, 279), 1.9, character_id)
    var character_title: Label = label(h, preview, str(Catalog.character(character_id).name), Rect2(328, 178, 430, 44), 32, INK, true)
    character_title.name = "SaveCharacter"
    label(h, preview, "携带武器", Rect2(328, 224, 430, 24), 18, INK, true)
    var held: Array = state.get("inventory", [])
    if held.is_empty():
        held = [{"id": starter, "level": 1}]
    var slot: int = 0
    for item in held:
        var key: String = str(item.get("id", starter))
        if not Catalog.WEAPONS.has(key) or slot >= 6:
            continue
        var x: float = 328.0 + float(slot % 2) * 222.0
        var y: float = 250.0 + float(slot / 2) * 43.0
        weapon(h, preview, Vector2(x + 17.0, y + 17.0), key, 34)
        var weapon_title: Label = label(h, preview, str(Catalog.WEAPONS[key].name), Rect2(x + 42, y - 2, 174, 23), 17, INK, true)
        weapon_title.name = "SaveWeaponName" + str(slot)
        var level_text: String = Growth.weapon_level_text(int(item.get("level", 1)))
        var weapon_level: Label = label(h, preview, level_text, Rect2(x + 42, y + 20, 174, 21), 15, Color("#5c625e"))
        weapon_level.name = "SaveWeaponLevel" + str(slot)
        slot += 1
    line(preview, Vector2(48, 382), 724, Color(INK, 0.55))
    var max_hp: float = Catalog.apply_character_modifiers(Growth.stats(state.get("buff_levels", {})), character_id)["max_hp"]
    var wave_label: Label = label(h, preview, "第 %d 关" % int(state.get("wave", 1)), Rect2(48, 405, 144, 34), 23, INK, true)
    wave_label.name = "SaveWave"
    var life: Label = label(h, preview, "生命 %.1f / %.1f" % [float(state.get("player_hp", 8.0)), max_hp], Rect2(200, 405, 230, 34), 22)
    life.name = "SaveHp"
    var coins: Label = label(h, preview, "金币 %d" % int(state.get("coins", 0)), Rect2(440, 405, 155, 34), 22)
    coins.name = "SaveCoins"
    var level: Label = label(h, preview, "等级 %d" % int(state.get("player_level", 1)), Rect2(610, 405, 158, 34), 22)
    level.name = "SaveLevel"
    h.save_note_label = label(h, body, "从上次保存的位置继续。", Rect2(48, 458, 724, 50), 19, Color("#5c625e"))
    h.save_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    button(h, body, "Back", "← 返回", Rect2(48, 536, 178, 54), func(): h.close_front_modal(), false, 22)
    button(h, body, "ConfirmContinue", "→  继续旅程", Rect2(418, 532, 354, 58), func(): h.continue_requested.emit(), true, 26)

static func help_page(h, page: String, in_run: bool) -> void:
    var sheet = modal(h, Rect2(146, 72, 988, 656))
    var body: Control = sheet.content
    var heading: String = "按键操作" if page == "keys" else ("武器联动" if page == "links" else "玩法说明")
    label(h, body, heading, Rect2(40, 20, 800, 65), 40, INK, true)
    line(body, Vector2(40, 100), 904, RED)
    var text: String = "普通关生存 30 秒，随后进入营地商店。\n每 5 关迎战 Boss：不限时，击败它才能结算。\n\n绿色经验石用于升级，金币用于营地购买。\n成长三选一；不想要的卡片可以出售换金币。\n击败精英恐龙会掉落宝箱，开箱同样三选一。\n最多携带 6 把武器，伙伴不占武器槽。\n\n集齐配对武器后按 %s 打开武器背包。把可以搭配的两件拖到一起即可联动，拖开即可断开。屏幕下方会提示还差哪一件。\n获得有配方的武器时会弹出说明，写出优点和缺点。锁链类联动会从火药筒炮口弹出。\n按 %s 可隐藏大部分战斗界面，生命和经验会保留。\n熔岩地面会持续烫伤。营地可花金币刷新货物。" % [KeyBindings.caption_for("link"), KeyBindings.caption_for("hide_ui")]
    if page == "keys":
        text = "WASD / 方向键    移动 · 镜头跟随\nShift 闪避 · 冷却 1.4 秒（不可改）\n← / → 翻页预览角色，点击画像确认选择\n%s 确认出发 · %s 返回 / 暂停\n%s 角色属性 · %s 手动保存 · %s 隐藏或显示界面\n%s 散射 / 集火切换 · %s 打开武器背包 · %s 切换瞄准目标\n%s / %s / %s 选择成长 · 商店按栏位键直接购买 · 结算页按 %s 再出发" % [KeyBindings.caption_for("confirm"), KeyBindings.caption_for("cancel"), KeyBindings.caption_for("stats"), KeyBindings.caption_for("save"), KeyBindings.caption_for("hide_ui"), KeyBindings.caption_for("scatter"), KeyBindings.caption_for("link"), KeyBindings.caption_for("aim"), KeyBindings.caption_for("shop_1"), KeyBindings.caption_for("shop_2"), KeyBindings.caption_for("shop_3"), KeyBindings.caption_for("confirm")]
    elif page == "links":
        text = "集齐配对武器后，按 %s 打开武器背包。把可以搭配的两件武器拖到一起即可联动，拖开即可断开。不能搭配的拖到一起会提示「这两件武器不能联动」。第一次获得有配方的武器时会弹出说明，写出两件武器、联动名称、优点和缺点。商店和升级卡片也会标明「可联动」或还差哪一件。\n\n火药筒 + 木棒 / 石斧 / 骨刃 → 锁链武器。\n锁链从火药筒炮口弹出并弹射往返；被联动的近战不再环绕，火药筒不再发普通炮弹。\n火药筒 + 魔法杖 → 魔法炮。炮弹化为符能爆炸并留下灼烧，但魔法杖停止独立发射。\n火种壶可附着到火药筒、骨弩、弹弓、石槌或骨镖上，把攻击变成带火的联动。魔法杖也可附着到骨弩、弹弓或骨镖上，让弹道附上符能。\n火种壶 + 战鼓、骨弩 + 图腾、图腾 + 晶簇也有各自配方。\n\n同一时间一把武器只能参加一组联动。每一种联动都有代价，默认不会自动启用。之后可按 %s 打开背包，继续拖拽启用或断开。" % [KeyBindings.caption_for("link"), KeyBindings.caption_for("link")]
    var copy: Label = label(h, body, text, Rect2(44, 118, 894, 378), 20)
    copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    button(h, body, "HelpGameplay", "玩法", Rect2(40, 508, 110, 43), func(): h.show_help("gameplay", in_run), false, 18)
    button(h, body, "HelpKeys", "按键操作", Rect2(160, 508, 150, 43), func(): h.show_help("keys", in_run), false, 18)
    button(h, body, "HelpLinks", "武器联动", Rect2(320, 508, 150, 43), func(): h.show_help("links", in_run), false, 18)
    KeyBindings.attach_to_button(button(h, body, "Stats", "角色属性", Rect2(480, 508, 186, 43), func(): h.stats_requested.emit(), false, 18), "stats")
    button(h, body, "TrialBasic", "基础试用" + (" [F2]" if h.debug_cheats else ""), Rect2(40, 581, 222, 44), func(): h.request_help_trial("base"), false, 18)
    button(h, body, "TrialNew", "新武器试用" + (" [F3]" if h.debug_cheats else ""), Rect2(280, 581, 244, 44), func(): h.request_help_trial("new"), false, 18)
    KeyBindings.attach_to_button(button(h, body, "Back", "返回", Rect2(720, 570, 224, 54), func(): h.close_front_modal(), true, 22), "cancel")

static func help_trial_confirm(h, kind: String, in_run: bool) -> void:
    var sheet = modal(h, Rect2(230, 140, 820, 520))
    var body: Control = sheet.content
    var title: String = "开始新武器试用" if kind == "new" else "开始基础试用"
    label(h, body, title, Rect2(48, 28, 700, 60), 36, INK, true)
    line(body, Vector2(48, 104), 724, RED)
    var detail: String = "试用只用于体验武器和成长，不会覆盖正式存档。\n确认后进入试用关卡；取消则返回说明页。"
    var body_copy: Label = label(h, body, detail, Rect2(48, 130, 724, 160), 22)
    body_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    KeyBindings.attach_to_button(button(h, body, "HelpTrialCancel", "取消", Rect2(48, 380, 220, 54), func(): h.cancel_help_trial(), false, 22), "cancel")
    KeyBindings.attach_to_button(button(h, body, "HelpTrialConfirm", "开始试用", Rect2(430, 376, 342, 58), func(): h.confirm_help_trial(), true, 24), "confirm")

static func key_bindings_page(h, in_run: bool) -> void:
    var sheet = modal(h, Rect2(254, 12, 772, 776))
    var body: Control = sheet.content
    label(h, body, "改按键", Rect2(48, 20, 550, 58), 42, INK, true)
    button(h, body, "CloseModal", "×", Rect2(674, 20, 52, 48), func(): h.show_settings(in_run), false, 30)
    line(body, Vector2(48, 88), 674, RED)
    var intro: Label = label(h, body, "点击右侧按键格，再按下新键；Esc 取消本次改键。\nEsc 不能改到其他功能，恢复默认可改回。\n两个功能不能用同一按键；移动与闪避、调试键不可改。", Rect2(48, 100, 674, 72), 16, Color("#5c625e"))
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var status: Label = label(h, body, h.bind_status if str(h.bind_status) != "" else "默认与目前游戏按键一致", Rect2(48, 174, 674, 28), 17, Color("#704127"))
    status.name = "BindStatus"
    var visible_actions: Array = KeyBindings.settings_order()
    var mid: int = int((visible_actions.size() + 1) / 2)
    var left: Array = visible_actions.slice(0, mid)
    var right: Array = visible_actions.slice(mid, visible_actions.size())
    for column_index in range(2):
        var actions: Array = left if column_index == 0 else right
        var base_x: float = 48.0 if column_index == 0 else 400.0
        for row in range(actions.size()):
            var action: String = str(actions[row])
            var y: float = 214.0 + float(row) * 52.0
            label(h, body, KeyBindings.display_name(action), Rect2(base_x, y, 150, 44), 20, INK, true)
            var bind: Button = button(h, body, str(KeyBindings.BIND_BUTTON[action]), "", Rect2(base_x + 158, y, 150, 44), func(): h.begin_bind_listen(action), false, 16)
            bind.tooltip_text = "点击后按下新键"
            KeyBindings.fill_bind_button(bind, action, str(h.bind_listen_action) == action)
    button(h, body, "ResetKeyBindings", "恢复默认", Rect2(48, 670, 220, 54), func(): h.reset_key_bindings(), false, 22)
    button(h, body, "BackToSettings", "返回设置", Rect2(500, 670, 220, 54), func(): h.show_settings(in_run), true, 24)
