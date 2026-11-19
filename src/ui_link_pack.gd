extends Control
const Catalog = preload("res://src/catalog.gd")
const Details = preload("res://src/ui_weapon_details.gd")
const Growth = preload("res://src/growth.gd")
const PaperUI = preload("res://src/ui_paper.gd")
const KeyBindings = preload("res://src/key_bindings.gd")
const GameFonts = preload("res://src/game_fonts.gd")

const ERROR_INCOMPATIBLE := "这两件武器不能联动"
const CARD_SIZE := Vector2(196, 172)
const CLUSTER_MID := Vector2(176, 172)
const BOARD_SIZE := Vector2(992, 468)
const UNLINK_DISTANCE := 86.0

signal closed

var hud
var host
var last_error: String = ""
var last_toast: String = ""
var sheet
var board: Control
var status_label: Label
var cards: Dictionary = {}
var clusters: Dictionary = {}
var dragging_id: String = ""
var drag_offset: Vector2 = Vector2.ZERO
var drag_home: Vector2 = Vector2.ZERO
var body_font: Font

func setup(ui, world) -> void:
    hud = ui
    host = world
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_preset(Control.PRESET_FULL_RECT)
    offset_left = 0
    offset_top = 0
    offset_right = 0
    offset_bottom = 0
    body_font = GameFonts.create_system(PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"]))
    _build()
    refresh()

func is_open() -> bool:
    return is_inside_tree() and visible

func weapon_ids() -> Array:
    var ids: Array = []
    if host == null:
        return ids
    for item in host.inventory:
        var key: String = str(item.get("id", ""))
        if not key.is_empty() and not ids.has(key):
            ids.append(key)
    return ids

func node_info(weapon_id: String) -> Dictionary:
    var info: Dictionary = {
        "id": weapon_id,
        "name": Catalog.weapon_name(weapon_id),
        "stats": _stats_text(weapon_id),
        "type": Details.attack_type(weapon_id),
        "hint": "",
        "linked": false,
        "link_id": "none",
        "link_name": "",
        "benefit": "",
        "cost": "",
        "valid_targets": valid_drop_targets(weapon_id)
    }
    var recipe: Dictionary = _active_recipe()
    if not recipe.is_empty() and recipe.get("weapons", []).has(weapon_id):
        info["linked"] = true
        info["link_id"] = str(recipe.get("id", "none"))
        info["link_name"] = str(recipe.get("name", ""))
        info["benefit"] = Catalog.benefit_text(recipe)
        info["cost"] = Catalog.cost_text(recipe)
    else:
        info["hint"] = compatible_hint(weapon_id)
    return info

func pack_nodes() -> Array:
    var result: Array = []
    for weapon_id in weapon_ids():
        result.append(node_info(weapon_id))
    return result

func displayed_text() -> String:
    var parts: PackedStringArray = PackedStringArray()
    _collect_text(self, parts)
    if not last_error.is_empty():
        parts.append(last_error)
    if not last_toast.is_empty():
        parts.append(last_toast)
    return "\n".join(parts)

func error_text() -> String:
    return last_error

func toast_text() -> String:
    return last_toast

func recipe_for_pair(weapon_a: String, weapon_b: String) -> Dictionary:
    if weapon_a.is_empty() or weapon_b.is_empty() or weapon_a == weapon_b:
        return {}
    for key in Catalog.LINK_ORDER:
        if key == "none":
            continue
        var recipe: Dictionary = Catalog.LINKS[key]
        var weapons: Array = recipe.get("weapons", [])
        if weapons.size() != 2:
            continue
        var first: String = str(weapons[0])
        var second: String = str(weapons[1])
        if (first == weapon_a and second == weapon_b) or (first == weapon_b and second == weapon_a):
            return recipe.duplicate(true)
    return {}

func valid_drop_targets(weapon_id: String) -> Array:
    var targets: Array = []
    if weapon_id.is_empty():
        return targets
    var owned: Array = weapon_ids()
    for other in owned:
        if other == weapon_id:
            continue
        if not recipe_for_pair(weapon_id, other).is_empty():
            targets.append(other)
    return targets

func compatible_hint(weapon_id: String) -> String:
    var names: PackedStringArray = PackedStringArray()
    var owned: Array = weapon_ids()
    for other in valid_drop_targets(weapon_id):
        var recipe: Dictionary = recipe_for_pair(weapon_id, other)
        var label: String = Catalog.weapon_name(other)
        if not recipe.is_empty():
            label = "%s→%s" % [Catalog.weapon_name(other), str(recipe.get("name", ""))]
        if not names.has(label):
            names.append(label)
    if names.is_empty():
        for recipe in Catalog.recipes_for_weapon(weapon_id):
            var partner: String = Catalog.partner_id(recipe, weapon_id)
            if partner.is_empty() or owned.has(partner):
                continue
            var label: String = Catalog.weapon_name(partner)
            if not names.has(label):
                names.append(label)
        if names.is_empty():
            return ""
        return "可与%s搭配" % "、".join(names)
    if names.size() > 2:
        return "可与%s、%s等搭配" % [names[0], names[1]]
    return "可与%s搭配" % "、".join(names)

func try_drop(weapon_a: String, weapon_b: String) -> Dictionary:
    var result: Dictionary = _apply_drop(weapon_a, weapon_b)
    if result.get("ok", false):
        last_error = ""
        last_toast = str(result.get("toast", ""))
    else:
        last_error = str(result.get("error", ERROR_INCOMPATIBLE))
        if not result.get("keep_toast", false):
            last_toast = ""
    refresh()
    return result

func try_unlink(weapon_id: String) -> Dictionary:
    var result: Dictionary = _apply_unlink(weapon_id)
    if result.get("ok", false):
        last_error = ""
        last_toast = str(result.get("toast", "已断开联动"))
    else:
        last_error = str(result.get("error", ""))
    refresh()
    return result

func request_close() -> void:
    closed.emit()

func refresh() -> void:
    if board == null:
        _set_status(_status_copy())
        return
    for child in board.get_children():
        board.remove_child(child)
        child.queue_free()
    cards.clear()
    clusters.clear()
    var ids: Array = weapon_ids()
    var recipe: Dictionary = _active_recipe()
    var linked: Array = []
    if not recipe.is_empty():
        for weapon_id in recipe.get("weapons", []):
            if ids.has(str(weapon_id)):
                linked.append(str(weapon_id))
    var unlinked: Array = []
    for weapon_id in ids:
        if not linked.has(weapon_id):
            unlinked.append(weapon_id)
    var cursor_y: float = 8.0
    if linked.size() == 2:
        var cluster: Control = _make_cluster(recipe, linked[0], linked[1])
        cluster.position = Vector2((BOARD_SIZE.x - cluster.size.x) * 0.5, cursor_y)
        board.add_child(cluster)
        clusters[str(recipe.get("id", ""))] = cluster
        cursor_y += cluster.size.y + 28.0
    var columns: int = mini(4, maxi(1, unlinked.size()))
    var gap: float = 18.0
    var row_width: float = columns * CARD_SIZE.x + maxf(0, columns - 1) * gap
    var start_x: float = maxf(8.0, (BOARD_SIZE.x - row_width) * 0.5)
    for index in range(unlinked.size()):
        var weapon_id: String = unlinked[index]
        var card: Control = _make_card(weapon_id, false)
        var col: int = index % 4
        var row: int = int(index / 4)
        var jitter: Vector2 = _idle_jitter(weapon_id)
        card.position = Vector2(start_x + col * (CARD_SIZE.x + gap), cursor_y + row * (CARD_SIZE.y + 20.0)) + jitter
        board.add_child(card)
        cards[weapon_id] = card
        card.set_meta("home", card.position)
    _set_status(_status_copy())
    _apply_drag_highlights()

func _apply_drop(weapon_a: String, weapon_b: String) -> Dictionary:
    if host == null:
        return {"ok": false, "error": ERROR_INCOMPATIBLE}
    var owned: Array = weapon_ids()
    if not owned.has(weapon_a) or not owned.has(weapon_b) or weapon_a == weapon_b:
        return {"ok": false, "error": ERROR_INCOMPATIBLE, "link_id": _current_link_id()}
    var recipe: Dictionary = recipe_for_pair(weapon_a, weapon_b)
    if recipe.is_empty():
        return {"ok": false, "error": ERROR_INCOMPATIBLE, "link_id": _current_link_id()}
    var previous_id: String = _current_link_id()
    var previous_name: String = str(_active_recipe().get("name", "不联动"))
    var wanted: String = str(recipe.get("id", "none"))
    if previous_id == wanted:
        return {"ok": true, "link_id": wanted, "toast": "已在使用「%s」" % str(recipe.get("name", "")), "unchanged": true}
    var before: String = previous_id
    host.select_link(wanted)
    var applied: String = _current_link_id()
    if applied != wanted:
        var pending: String = str(host.get("pending_link")) if host.get("pending_link") != null else ""
        var message: String = str(host.get("combo_message")) if pending != "" else "现在不能改联动"
        if message.is_empty():
            message = "现在不能改联动"
        return {"ok": false, "error": message, "link_id": before, "keep_toast": true}
    var toast := ""
    if previous_id != "none" and previous_id != wanted:
        toast = "已将「%s」改为「%s」" % [previous_name, str(recipe.get("name", ""))]
    else:
        toast = "已启用「%s」" % str(recipe.get("name", ""))
    return {"ok": true, "link_id": wanted, "toast": toast, "swapped": previous_id != "none"}

func _apply_unlink(weapon_id: String) -> Dictionary:
    if host == null:
        return {"ok": false, "error": "现在不能断开"}
    var recipe: Dictionary = _active_recipe()
    if recipe.is_empty() or not recipe.get("weapons", []).has(weapon_id):
        return {"ok": false, "error": "", "link_id": _current_link_id(), "noop": true}
    var previous_name: String = str(recipe.get("name", "联动"))
    var before: String = str(recipe.get("id", "none"))
    host.select_link("none")
    if _current_link_id() != "none":
        var pending: String = str(host.get("pending_link")) if host.get("pending_link") != null else ""
        var message: String = str(host.get("combo_message")) if pending != "" else "现在不能断开"
        if message.is_empty():
            message = "现在不能断开"
        return {"ok": false, "error": message, "link_id": before}
    return {"ok": true, "link_id": "none", "toast": "已断开「%s」" % previous_name}

func _current_link_id() -> String:
    if host == null:
        return "none"
    var link: Dictionary = host.active_link if typeof(host.active_link) == TYPE_DICTIONARY else {}
    var link_id: String = str(link.get("id", "none"))
    return link_id if Catalog.LINKS.has(link_id) else "none"

func _active_recipe() -> Dictionary:
    var link_id: String = _current_link_id()
    if link_id == "none" or not Catalog.LINKS.has(link_id):
        return {}
    return Catalog.LINKS[link_id].duplicate(true)

func _owned_level(weapon_id: String) -> int:
    if host == null:
        return 1
    return maxi(1, Growth.item_level(weapon_id, host.inventory, {}))

func _stats_text(weapon_id: String) -> String:
    var line: String = Details.stats_line(weapon_id, _owned_level(weapon_id))
    var kind: String = Details.attack_type(weapon_id)
    if kind.is_empty():
        return line
    if line.is_empty():
        return kind
    return "%s\n%s" % [kind, line]

func _status_copy() -> String:
    if not last_error.is_empty():
        return last_error
    if not last_toast.is_empty():
        return last_toast
    return "把可以搭配的两件拖到一起即可联动，拖开即可断开。"

func _set_status(text: String) -> void:
    if status_label != null and is_instance_valid(status_label):
        status_label.text = text
        status_label.add_theme_color_override("font_color", Color("#9a3b2c") if not last_error.is_empty() else Color("#66705e"))

func _build() -> void:
    var dim := ColorRect.new()
    dim.name = "LinkPackDim"
    dim.color = Color(0.04, 0.08, 0.13, 0.0)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dim)
    sheet = PaperUI.new()
    sheet.name = "LinkPackSheet"
    sheet.opening_mode = "fold"
    sheet.reveal = 1.0
    sheet.position = Vector2(76, 36)
    sheet.size = Vector2(1128, 728)
    sheet.set_meta("full_width", 1128)
    add_child(sheet)
    var title: Label = _label("武器背包", 32, Color("#17253a"), true)
    title.position = Vector2(64, 28)
    title.size = Vector2(780, 42)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    sheet.content.add_child(title)
    var hint: Label = _label("把可以搭配的两件武器拖到一起即可联动；把已经联动的武器拖开即可断开。不能搭配的拖在一起会提示错误。", 16, Color("#66705e"), false)
    hint.position = Vector2(64, 72)
    hint.size = Vector2(880, 44)
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sheet.content.add_child(hint)
    var close_btn := Button.new()
    close_btn.name = "CloseLinkPack"
    close_btn.text = "关闭"
    close_btn.position = Vector2(960, 30)
    close_btn.size = Vector2(110, 42)
    close_btn.focus_mode = Control.FOCUS_NONE
    _style_button(close_btn)
    close_btn.pressed.connect(request_close)
    KeyBindings.attach_to_button(close_btn, "cancel")
    sheet.content.add_child(close_btn)
    board = Control.new()
    board.name = "LinkPackBoard"
    board.position = Vector2(64, 128)
    board.size = BOARD_SIZE
    board.mouse_filter = Control.MOUSE_FILTER_PASS
    board.clip_contents = false
    sheet.content.add_child(board)
    status_label = _label("", 16, Color("#66705e"), false)
    status_label.name = "LinkPackStatus"
    status_label.position = Vector2(64, 608)
    status_label.size = Vector2(1000, 44)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sheet.content.add_child(status_label)

func _label(text: String, size: int, color: Color, display: bool) -> Label:
    var result: Label = Label.new()
    result.text = text
    result.add_theme_font_size_override("font_size", size)
    result.add_theme_color_override("font_color", color)
    result.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if body_font != null:
        result.add_theme_font_override("font", body_font)
    if display and hud != null and hud.display_font != null:
        result.add_theme_font_override("font", hud.display_font)
    return result

func _style_button(button: Button) -> void:
    if hud != null and hud.has_method("make_button"):
        var sample: Button = hud.make_button("关闭")
        for key in ["normal", "hover", "pressed", "disabled"]:
            var box: StyleBox = sample.get_theme_stylebox(key)
            if box != null:
                button.add_theme_stylebox_override(key, box)
        button.add_theme_color_override("font_color", Color("#17253a"))
        button.add_theme_color_override("font_hover_color", Color("#17253a"))
        button.add_theme_color_override("font_pressed_color", Color("#17253a"))
        button.add_theme_font_size_override("font_size", 18)
        sample.queue_free()
        return
    button.add_theme_font_size_override("font_size", 18)

func _make_card(weapon_id: String, in_cluster: bool) -> Panel:
    var card := Panel.new()
    card.name = "WeaponCard_%s" % weapon_id
    card.size = CARD_SIZE
    card.custom_minimum_size = CARD_SIZE
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    card.set_meta("weapon_id", weapon_id)
    card.set_meta("in_cluster", in_cluster)
    card.gui_input.connect(func(event): _on_card_input(weapon_id, card, event))
    _paint_card(card, weapon_id, "idle")
    var info: Dictionary = node_info(weapon_id)
    var icon := TextureRect.new()
    icon.position = Vector2(62, 10)
    icon.size = Vector2(72, 44)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if host != null and host.library != null:
        icon.texture = host.library.weapon_texture(weapon_id, _owned_level(weapon_id))
        if hud != null and hud.library != null and hud.library.weapon_material != null:
            icon.material = hud.library.weapon_material
        elif host.library.weapon_material != null:
            icon.material = host.library.weapon_material
    card.add_child(icon)
    var title: Label = _label(str(info["name"]), 17, Color("#3a2a1c"), true)
    title.position = Vector2(10, 56)
    title.size = Vector2(176, 24)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(title)
    var stats: Label = _label(str(info["stats"]), 13, Color("#5a4a36"), false)
    stats.position = Vector2(10, 80)
    stats.size = Vector2(176, 44)
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    card.add_child(stats)
    var hint_copy: String = str(info["hint"])
    if in_cluster:
        hint_copy = "已联动"
    var hint: Label = _label(hint_copy, 12, Color("#704127") if not in_cluster else Color("#7a4a22"), false)
    hint.position = Vector2(10, 126)
    hint.size = Vector2(176, 36)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.name = "CardHint"
    card.add_child(hint)
    cards[weapon_id] = card
    return card

func _make_cluster(recipe: Dictionary, first_id: String, second_id: String) -> Control:
    var cluster := Control.new()
    cluster.name = "LinkCluster_%s" % str(recipe.get("id", "link"))
    var width: float = CARD_SIZE.x * 2.0 + CLUSTER_MID.x + 16.0
    cluster.size = Vector2(width, CARD_SIZE.y)
    cluster.mouse_filter = Control.MOUSE_FILTER_PASS
    var left: Panel = _make_card(first_id, true)
    left.position = Vector2.ZERO
    cluster.add_child(left)
    left.set_meta("home", left.position)
    var mid := Panel.new()
    mid.name = "LinkDetails"
    mid.position = Vector2(CARD_SIZE.x + 8, 6)
    mid.size = Vector2(CLUSTER_MID.x, CARD_SIZE.y - 12)
    mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var mid_box := StyleBoxFlat.new()
    mid_box.bg_color = Color("#efe0be")
    mid_box.border_color = Color("#b4583e")
    mid_box.set_border_width_all(2)
    mid_box.set_corner_radius_all(3)
    mid.add_theme_stylebox_override("panel", mid_box)
    var name_label: Label = _label(str(recipe.get("name", "")), 17, Color("#9a3b2c"), true)
    name_label.position = Vector2(8, 6)
    name_label.size = Vector2(CLUSTER_MID.x - 16, 28)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mid.add_child(name_label)
    var body: Label = _label("优点：%s\n缺点：%s" % [Catalog.benefit_text(recipe), Catalog.cost_text(recipe)], 12, Color("#3a2a1c"), false)
    body.position = Vector2(8, 36)
    body.size = Vector2(CLUSTER_MID.x - 16, 120)
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    mid.add_child(body)
    cluster.add_child(mid)
    var right: Panel = _make_card(second_id, true)
    right.position = Vector2(CARD_SIZE.x + CLUSTER_MID.x + 16, 0)
    cluster.add_child(right)
    right.set_meta("home", right.position)
    return cluster

func _paint_card(card: Panel, _weapon_id: String, mode: String) -> void:
    var box := StyleBoxFlat.new()
    box.bg_color = Color("#f4e0b4")
    box.border_color = Color("#7a4a22")
    box.set_border_width_all(2)
    box.set_corner_radius_all(3)
    box.shadow_color = Color(0.12, 0.08, 0.05, 0.22)
    box.shadow_size = 6
    box.shadow_offset = Vector2(2, 3)
    card.modulate = Color.WHITE
    match mode:
        "valid":
            box.bg_color = Color("#f3d59a")
            box.border_color = Color("#b4583e")
            box.set_border_width_all(3)
        "invalid":
            box.bg_color = Color("#e4d8c0")
            box.border_color = Color("#9d9380")
            card.modulate = Color(0.78, 0.74, 0.68, 0.92)
        "drag":
            box.bg_color = Color("#f7e7c0")
            box.border_color = Color("#3a2a1c")
            box.shadow_size = 10
        "linked":
            box.border_color = Color("#b4583e")
    if mode == "idle" and bool(card.get_meta("in_cluster", false)):
        box.border_color = Color("#b4583e")
    card.add_theme_stylebox_override("panel", box)

func _idle_jitter(weapon_id: String) -> Vector2:
    var seed: int = 0
    for i in range(weapon_id.length()):
        seed += weapon_id.unicode_at(i) * (i + 3)
    return Vector2(float((seed * 13) % 15) - 7.0, float((seed * 7) % 13) - 6.0)

func _on_card_input(weapon_id: String, card: Control, event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _begin_drag(weapon_id, card, event.position)
            card.accept_event()
        elif dragging_id == weapon_id:
            _finish_drag(card.get_global_mouse_position())
            card.accept_event()
    elif event is InputEventMouseMotion and dragging_id == weapon_id:
        card.global_position += event.relative
        _apply_drag_highlights()
        card.accept_event()

func _begin_drag(weapon_id: String, card: Control, local_pos: Vector2) -> void:
    dragging_id = weapon_id
    drag_offset = local_pos
    drag_home = card.position
    card.z_index = 20
    _paint_card(card, weapon_id, "drag")
    last_error = ""
    _apply_drag_highlights()
    _set_status("拖到可搭配的武器上即可联动；拖到空白处可断开。")

func _finish_drag(global_pos: Vector2) -> void:
    var source_id: String = dragging_id
    var source_card: Control = cards.get(source_id, null)
    dragging_id = ""
    if source_card != null and is_instance_valid(source_card):
        source_card.z_index = 0
    var target_id: String = _card_at(global_pos, source_id)
    if not target_id.is_empty():
        try_drop(source_id, target_id)
        return
    if source_card != null and is_instance_valid(source_card) and bool(source_card.get_meta("in_cluster", false)):
        if source_card.position.distance_to(drag_home) >= UNLINK_DISTANCE or not _still_over_cluster(source_card):
            try_unlink(source_id)
            return
    refresh()

func _still_over_cluster(card: Control) -> bool:
    var parent: Node = card.get_parent()
    if parent == null or not (parent is Control):
        return false
    var area: Rect2 = (parent as Control).get_global_rect()
    return area.grow(-18.0).intersects(card.get_global_rect())

func _card_at(global_pos: Vector2, except: String) -> String:
    for weapon_id in cards:
        if weapon_id == except:
            continue
        var card: Control = cards[weapon_id]
        if card != null and is_instance_valid(card) and card.get_global_rect().has_point(global_pos):
            return weapon_id
    return ""

func _apply_drag_highlights() -> void:
    var valid: Array = valid_drop_targets(dragging_id) if not dragging_id.is_empty() else []
    for weapon_id in cards:
        var card: Control = cards[weapon_id]
        if card == null or not is_instance_valid(card):
            continue
        if dragging_id.is_empty():
            _paint_card(card, weapon_id, "idle")
            continue
        if weapon_id == dragging_id:
            _paint_card(card, weapon_id, "drag")
        elif valid.has(weapon_id):
            _paint_card(card, weapon_id, "valid")
        else:
            _paint_card(card, weapon_id, "invalid")

func _collect_text(node: Node, parts: PackedStringArray) -> void:
    if node is Label or node is Button:
        var value: String = str(node.text).strip_edges()
        if not value.is_empty():
            parts.append(value)
    for child in node.get_children():
        _collect_text(child, parts)

func _input(event: InputEvent) -> void:
    if dragging_id.is_empty():
        return
    if event is InputEventMouseMotion:
        var card: Control = cards.get(dragging_id, null)
        if card != null and is_instance_valid(card):
            card.global_position = card.get_global_mouse_position() - drag_offset
            _apply_drag_highlights()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        _finish_drag(get_global_mouse_position())
        get_viewport().set_input_as_handled()
