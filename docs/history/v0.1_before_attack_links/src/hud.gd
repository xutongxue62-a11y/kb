extends CanvasLayer
const Catalog = preload("res://src/catalog.gd")

signal start_requested(trial: bool)
signal formation_requested
signal combo_requested
signal elite_requested
signal trial_requested
signal pause_requested
signal restart_requested
signal choice_selected(weapon_id: String)

var library
var root: Control
var overlay: ColorRect
var slots: Array = []
var title_label: Label
var health_label: Label
var timer_label: Label
var score_label: Label
var combo_label: Label
var notice_label: Label
var formation_button: Button
var combo_button: Button
var elite_button: Button
var xp_bar: ProgressBar
var choice_ids: Array = []
var ink: Color = Color("#543b2c")
var cream: Color = Color("#f4e8cb")

func style(background: Color, border: Color = Color("#b8a684")) -> StyleBoxFlat:
    var box: StyleBoxFlat = StyleBoxFlat.new()
    box.bg_color = background
    box.border_color = border
    box.set_border_width_all(1)
    box.set_corner_radius_all(10)
    box.content_margin_left = 12
    box.content_margin_right = 12
    box.content_margin_top = 8
    box.content_margin_bottom = 8
    return box

func make_label(text: String, size: int = 18, color: Color = ink) -> Label:
    var result: Label = Label.new()
    result.text = text
    result.add_theme_font_size_override("font_size", size)
    result.add_theme_color_override("font_color", color)
    return result

func make_button(text: String, color: Color = cream) -> Button:
    var result: Button = Button.new()
    result.text = text
    result.add_theme_stylebox_override("normal", style(color))
    result.add_theme_stylebox_override("hover", style(color.lightened(0.09), Color("#927a51")))
    result.add_theme_stylebox_override("pressed", style(color.darkened(0.06), ink))
    result.add_theme_color_override("font_color", ink)
    result.add_theme_color_override("font_hover_color", ink)
    result.add_theme_color_override("font_pressed_color", ink)
    result.add_theme_font_size_override("font_size", 17)
    result.focus_mode = Control.FOCUS_NONE
    result.custom_minimum_size.y = 40
    return result

func setup(asset_library) -> void:
    library = asset_library
    layer = 80
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var theme: Theme = Theme.new()
    var font: SystemFont = SystemFont.new()
    font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
    theme.default_font = font
    root.theme = theme
    add_child(root)
    var header: PanelContainer = PanelContainer.new()
    header.position = Vector2(22, 16)
    header.size = Vector2(1236, 66)
    header.add_theme_stylebox_override("panel", style(Color("#f4e8cb")))
    root.add_child(header)
    var header_row: HBoxContainer = HBoxContainer.new()
    header_row.add_theme_constant_override("separation", 26)
    header.add_child(header_row)
    title_label = make_label("原始人大作战", 27)
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header_row.add_child(title_label)
    health_label = make_label("生命 8 / 8", 20)
    header_row.add_child(health_label)
    score_label = make_label("击败 0", 19)
    header_row.add_child(score_label)
    timer_label = make_label("01:00", 25)
    header_row.add_child(timer_label)
    formation_button = make_button("展开扫荡 [空格]")
    formation_button.position = Vector2(26, 92)
    formation_button.size = Vector2(184, 36)
    formation_button.pressed.connect(func(): formation_requested.emit())
    root.add_child(formation_button)
    combo_button = make_button("优先三联动 [Q]")
    combo_button.position = Vector2(220, 92)
    combo_button.size = Vector2(184, 36)
    combo_button.pressed.connect(func(): combo_requested.emit())
    root.add_child(combo_button)
    elite_button = make_button("最近目标 [E]")
    elite_button.position = Vector2(414, 92)
    elite_button.size = Vector2(180, 36)
    elite_button.pressed.connect(func(): elite_requested.emit())
    root.add_child(elite_button)
    var trial_button: Button = make_button("六武器试用 [F2]", Color("#e6d7af"))
    trial_button.position = Vector2(1060, 92)
    trial_button.size = Vector2(194, 36)
    trial_button.pressed.connect(func(): trial_requested.emit())
    root.add_child(trial_button)
    notice_label = make_label("", 17, Color("#6e664d"))
    notice_label.position = Vector2(618, 99)
    root.add_child(notice_label)
    combo_label = make_label("取得武器，激活联动", 16)
    combo_label.position = Vector2(28, 707)
    combo_label.size = Vector2(238, 66)
    combo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(combo_label)
    xp_bar = ProgressBar.new()
    xp_bar.position = Vector2(272, 671)
    xp_bar.size = Vector2(748, 7)
    xp_bar.show_percentage = false
    xp_bar.add_theme_stylebox_override("background", style(Color("#b6b18f")))
    xp_bar.add_theme_stylebox_override("fill", style(Color("#81946c"), Color("#81946c")))
    root.add_child(xp_bar)
    var row: HBoxContainer = HBoxContainer.new()
    row.position = Vector2(272, 687)
    row.size = Vector2(748, 95)
    row.add_theme_constant_override("separation", 8)
    root.add_child(row)
    for index in range(6):
        var panel: PanelContainer = PanelContainer.new()
        panel.custom_minimum_size = Vector2(118, 91)
        panel.add_theme_stylebox_override("panel", style(Color("#eee1c0")))
        row.add_child(panel)
        var column: VBoxContainer = VBoxContainer.new()
        column.add_theme_constant_override("separation", 0)
        panel.add_child(column)
        var icon: TextureRect = TextureRect.new()
        icon.custom_minimum_size = Vector2(48, 42)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.material = library.weapon_material
        column.add_child(icon)
        var name_label: Label = make_label("未装备", 14, Color("#8e826a"))
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        column.add_child(name_label)
        var level_label: Label = make_label("", 12)
        level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        column.add_child(level_label)
        slots.append({"icon": icon, "name": name_label, "level": level_label})
    var help: Label = make_label("WASD / 方向键 移动\nR 重开 · Esc 暂停", 15, Color("#78674d"))
    help.position = Vector2(1040, 710)
    root.add_child(help)
    overlay = ColorRect.new()
    overlay.color = Color(0.18, 0.14, 0.10, 0.30)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(overlay)
    show_menu("start", 0)

func update_state(hp: int, elapsed: float, kills: int, xp: int, xp_needed: int, inventory: Array, collapsed: bool, mode: String, prefer_elite: bool, groups: Array, trial: bool) -> void:
    health_label.text = "生命 %d / 8" % maxi(0, hp)
    score_label.text = "击败 %d" % kills
    var seconds: int = maxi(0, ceili(60.0 - elapsed))
    timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
    formation_button.text = ("收束集火" if collapsed else "展开扫荡") + " [空格]"
    combo_button.text = ("两两联动" if mode == "pair" else "优先三联动") + " [Q]"
    elite_button.text = ("射程内精英优先" if prefer_elite else "最近目标") + " [E]"
    notice_label.text = "六武器试用" if trial else "击败恐龙，选择成长"
    xp_bar.max_value = xp_needed
    xp_bar.value = xp
    var names: PackedStringArray = PackedStringArray()
    for group in groups:
        names.append(group["name"])
    combo_label.text = "联动\n" + (" · ".join(names) if not names.is_empty() else "取得武器后激活")
    for index in range(slots.size()):
        var slot: Dictionary = slots[index]
        if index < inventory.size():
            var item: Dictionary = inventory[index]
            slot["icon"].texture = library.texture("weapons", item["id"])
            slot["name"].text = Catalog.WEAPONS[item["id"]]["name"]
            slot["name"].modulate = Color.WHITE
            slot["level"].text = "Lv.%d" % item["level"]
        else:
            slot["icon"].texture = null
            slot["name"].text = "未装备"
            slot["name"].modulate = Color(1, 1, 1, 0.6)
            slot["level"].text = ""

func reset_overlay() -> void:
    choice_ids.clear()
    for child in overlay.get_children():
        overlay.remove_child(child)
        child.queue_free()
    overlay.visible = true

func menu_column(width: float = 480.0, top: float = 220.0) -> VBoxContainer:
    var card: PanelContainer = PanelContainer.new()
    card.position = Vector2((1280.0 - width) / 2.0, top)
    card.size = Vector2(width, 0)
    card.add_theme_stylebox_override("panel", style(Color("#f6ead0"), Color("#9c825e")))
    overlay.add_child(card)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 15)
    card.add_child(column)
    return column

func show_menu(kind: String, kills: int) -> void:
    reset_overlay()
    var column: VBoxContainer = menu_column()
    var heading: String = "原始人大作战"
    if kind == "win":
        heading = "生存成功"
    elif kind == "lose":
        heading = "再来一局"
    elif kind == "pause":
        heading = "已暂停"
    var title: Label = make_label(heading, 32)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    var description: Label = make_label("在恐龙包围中坚持 60 秒。\n移动躲避，武器自动攻击；升级时选择武器。", 19)
    if kind == "win" or kind == "lose":
        description.text = "本轮击败 %d 只恐龙。\n试试另一组武器和联动搭配。" % kills
    elif kind == "pause":
        description.text = "移动、攻击和怪物计时均已暂停。"
    description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(description)
    if kind == "pause":
        var resume: Button = make_button("继续战斗", Color("#d1ddba"))
        resume.pressed.connect(func(): pause_requested.emit())
        column.add_child(resume)
    else:
        var start: Button = make_button("出发 · 一把木棒开局" if kind == "start" else "重新出发", Color("#d1ddba"))
        start.pressed.connect(func(): start_requested.emit(false))
        column.add_child(start)
        var trial: Button = make_button("直接试用六武器", Color("#ead6ad"))
        trial.pressed.connect(func(): start_requested.emit(true))
        column.add_child(trial)
    var controls: Label = make_label("WASD 移动 · 空格 阵型 · Q 联动 · E 精英优先", 15, Color("#867458"))
    controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(controls)

func show_choices(ids: Array, inventory: Array) -> void:
    reset_overlay()
    choice_ids = ids.duplicate()
    var column: VBoxContainer = menu_column(940.0, 205.0)
    var heading: Label = make_label("选择成长", 29)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    var row: HBoxContainer = HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    column.add_child(row)
    for index in range(ids.size()):
        var key: String = ids[index]
        var existing_level: int = 0
        for item in inventory:
            if item["id"] == key:
                existing_level = item["level"]
        var card: Button = make_button("")
        card.custom_minimum_size = Vector2(286, 250)
        card.tooltip_text = Catalog.WEAPONS[key]["name"]
        card.pressed.connect(_choose.bind(key))
        row.add_child(card)
        var content: VBoxContainer = VBoxContainer.new()
        content.position = Vector2(18, 18)
        content.size = Vector2(250, 210)
        content.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(content)
        var icon: TextureRect = TextureRect.new()
        icon.texture = library.texture("weapons", key)
        icon.material = library.weapon_material
        icon.custom_minimum_size = Vector2(100, 95)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        content.add_child(icon)
        var name_label: Label = make_label("%d · %s" % [index + 1, Catalog.WEAPONS[key]["name"]], 22)
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        content.add_child(name_label)
        var level_label: Label = make_label("新武器" if existing_level == 0 else "升级至 Lv.%d" % (existing_level + 1), 17, Color("#637650"))
        level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        content.add_child(level_label)
        var description: Label = make_label(Catalog.WEAPONS[key]["description"], 15)
        description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        description.mouse_filter = Control.MOUSE_FILTER_IGNORE
        content.add_child(description)

func _choose(key: String) -> void:
    choice_selected.emit(key)

func choose_index(index: int) -> void:
    if index >= 0 and index < choice_ids.size():
        choice_selected.emit(choice_ids[index])

func hide_menu() -> void:
    overlay.visible = false
    choice_ids.clear()
