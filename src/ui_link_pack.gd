extends Control
const Catalog = preload("res://src/catalog.gd")
const Rules = preload("res://src/rules.gd")
const Details = preload("res://src/ui_weapon_details.gd")
const Growth = preload("res://src/growth.gd")
const PaperUI = preload("res://src/ui_paper.gd")
const KeyBindings = preload("res://src/key_bindings.gd")
const GameFonts = preload("res://src/game_fonts.gd")

const ERROR_INCOMPATIBLE := "这两件武器不能联动"
const CARD_SIZE := Vector2(232, 214)
const CLUSTER_MID := Vector2(420, 252)
const BOARD_SIZE := Vector2(1104, 580)
const UNLINK_DISTANCE := 86.0
const PACK_WRAP := TextServer.AUTOWRAP_ARBITRARY

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
    var recipes: Array = _recipes_for_weapon(weapon_id)
    if not recipes.is_empty():
        info["linked"] = true
        var names: PackedStringArray = PackedStringArray()
        var ids: PackedStringArray = PackedStringArray()
        var benefits: PackedStringArray = PackedStringArray()
        var costs: PackedStringArray = PackedStringArray()
        for recipe in recipes:
            ids.append(str(recipe.get("id", "none")))
            names.append(str(recipe.get("name", "")))
            benefits.append(Catalog.benefit_text(recipe))
            costs.append(Catalog.cost_text(recipe))
        info["link_id"] = ids[0]
        info["link_ids"] = Array(ids)
        info["link_name"] = "、".join(names)
        info["benefit"] = "；".join(benefits)
        info["cost"] = "；".join(costs)
        info["hint"] = "已联动：%s" % "、".join(names)
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

func try_unlink(weapon_id: String, link_id: String = "") -> Dictionary:
    var result: Dictionary = _apply_unlink(weapon_id, link_id)
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
    var linked: Array = []
    var groups: Array = _cluster_groups()
    for group in groups:
        for recipe in group:
            for weapon_id in recipe.get("weapons", []):
                var key: String = str(weapon_id)
                if ids.has(key) and not linked.has(key):
                    linked.append(key)
    var unlinked: Array = []
    for weapon_id in ids:
        if not linked.has(weapon_id):
            unlinked.append(weapon_id)
    var cursor_y: float = 8.0
    for group in groups:
        var cluster: Control = _make_group_cluster(group)
        cluster.position = Vector2(maxf(4.0, (BOARD_SIZE.x - cluster.size.x) * 0.5), cursor_y)
        board.add_child(cluster)
        var group_id: String = str(group[0].get("id", "link")) if not group.is_empty() else "link"
        clusters[group_id] = cluster
        cursor_y += cluster.size.y + 22.0
    var columns: int = mini(3, maxi(1, unlinked.size()))
    var gap: float = 22.0
    var row_width: float = columns * CARD_SIZE.x + maxf(0, columns - 1) * gap
    var start_x: float = maxf(8.0, (BOARD_SIZE.x - row_width) * 0.5)
    for index in range(unlinked.size()):
        var weapon_id: String = unlinked[index]
        var card: Control = _make_card(weapon_id, false)
        var col: int = index % 3
        var row: int = int(index / 3)
        var jitter: Vector2 = _idle_jitter(weapon_id)
        card.position = Vector2(start_x + col * (CARD_SIZE.x + gap), cursor_y + row * (CARD_SIZE.y + 18.0)) + jitter
        board.add_child(card)
        cards[weapon_id] = card
        card.set_meta("home", card.position)
    _relock_pack_copy(self)
    _fit_pack_copy(self)
    _set_status(_status_copy())
    _apply_drag_highlights()
    if is_inside_tree():
        call_deferred("_finish_pack_layout")

func _apply_drop(weapon_a: String, weapon_b: String) -> Dictionary:
    if host == null:
        return {"ok": false, "error": ERROR_INCOMPATIBLE}
    var owned: Array = weapon_ids()
    if not owned.has(weapon_a) or not owned.has(weapon_b) or weapon_a == weapon_b:
        return {"ok": false, "error": ERROR_INCOMPATIBLE, "link_id": _current_link_id()}
    var recipe: Dictionary = recipe_for_pair(weapon_a, weapon_b)
    if recipe.is_empty():
        return {"ok": false, "error": ERROR_INCOMPATIBLE, "link_id": _current_link_id()}
    var previous_ids: Array = _current_link_ids()
    var wanted: String = str(recipe.get("id", "none"))
    if previous_ids.has(wanted):
        return {"ok": true, "link_id": wanted, "link_ids": previous_ids, "toast": "已在使用「%s」" % str(recipe.get("name", "")), "unchanged": true}
    var resolution: Dictionary = Rules.add_link_ids(previous_ids, wanted, owned)
    var before: Array = previous_ids.duplicate()
    host.select_link(wanted)
    var applied_ids: Array = _current_link_ids()
    var pending: String = str(host.get("pending_link")) if host.get("pending_link") != null else ""
    if pending != "" and not applied_ids.has(wanted):
        var message: String = str(host.get("combo_message"))
        if message.is_empty():
            message = "现在不能改联动"
        return {"ok": false, "error": message, "link_id": before.back() if not before.is_empty() else "none", "link_ids": before, "keep_toast": true}
    if not applied_ids.has(wanted):
        return {"ok": false, "error": "现在不能改联动", "link_id": before.back() if not before.is_empty() else "none", "link_ids": before}
    var dropped: Array = resolution.get("dropped", [])
    var toast := ""
    if dropped.size() == 1:
        toast = "已将「%s」改为「%s」" % [str(Catalog.LINKS[str(dropped[0])].get("name", "")), str(recipe.get("name", ""))]
    elif not dropped.is_empty():
        var dropped_names: PackedStringArray = PackedStringArray()
        for link_id in dropped:
            dropped_names.append(str(Catalog.LINKS[str(link_id)].get("name", "")))
        toast = "已启用「%s」，并解除冲突的「%s」" % [str(recipe.get("name", "")), "、".join(dropped_names)]
    else:
        toast = "已启用「%s」" % str(recipe.get("name", ""))
    return {"ok": true, "link_id": wanted, "link_ids": applied_ids, "toast": toast, "swapped": not dropped.is_empty(), "added": dropped.is_empty(), "dropped": dropped}

func _apply_unlink(weapon_id: String, link_id: String = "") -> Dictionary:
    if host == null:
        return {"ok": false, "error": "现在不能断开"}
    var current_ids: Array = _current_link_ids()
    var involved: Array = Rules.links_for_weapon(current_ids, weapon_id)
    var remove_id: String = link_id
    if remove_id.is_empty():
        if involved.size() == 1:
            remove_id = str(involved[0])
        elif involved.is_empty():
            return {"ok": false, "error": "", "link_id": _current_link_id(), "link_ids": current_ids, "noop": true}
        else:
            return {"ok": false, "error": "", "link_id": _current_link_id(), "link_ids": current_ids, "noop": true}
    if not current_ids.has(remove_id):
        return {"ok": false, "error": "", "link_id": _current_link_id(), "link_ids": current_ids, "noop": true}
    var previous_name: String = str(Catalog.LINKS[remove_id].get("name", "联动"))
    var desired: Array = Rules.remove_link_ids(current_ids, remove_id, weapon_ids())
    if host.has_method("set_links"):
        host.set_links(desired)
    elif host.has_method("apply_links"):
        host.apply_links(desired)
    else:
        host.select_link("none" if desired.is_empty() else str(desired.back()))
    var applied_ids: Array = _current_link_ids()
    if applied_ids.has(remove_id):
        var pending: String = str(host.get("pending_link")) if host.get("pending_link") != null else ""
        var message: String = str(host.get("combo_message")) if pending != "" else "现在不能断开"
        if message.is_empty():
            message = "现在不能断开"
        return {"ok": false, "error": message, "link_id": remove_id, "link_ids": current_ids}
    return {"ok": true, "link_id": applied_ids.back() if not applied_ids.is_empty() else "none", "link_ids": applied_ids, "toast": "已断开「%s」" % previous_name}

func _current_link_ids() -> Array:
    if host == null:
        return []
    if host.has_method("active_link_ids"):
        return host.active_link_ids()
    var link_id: String = _current_link_id()
    return [] if link_id == "none" else [link_id]

func _current_link_id() -> String:
    var ids: Array = []
    if host != null and host.has_method("active_link_ids"):
        ids = host.active_link_ids()
        if not ids.is_empty():
            return str(ids.back())
    if host == null:
        return "none"
    var link: Dictionary = host.active_link if typeof(host.active_link) == TYPE_DICTIONARY else {}
    var link_id: String = str(link.get("id", "none"))
    return link_id if Catalog.LINKS.has(link_id) else "none"

func _active_recipes() -> Array:
    return Rules.profiles_for_ids(_current_link_ids(), weapon_ids())

func _active_recipe() -> Dictionary:
    var recipes: Array = _active_recipes()
    if recipes.is_empty():
        return {}
    return recipes.back().duplicate(true)

func _recipes_for_weapon(weapon_id: String) -> Array:
    var result: Array = []
    for recipe in _active_recipes():
        if recipe.get("weapons", []).has(weapon_id):
            result.append(recipe)
    return result

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
    return "把可以搭配的两件拖到一起即可联动，已有的其他联动会保留；把其中一对拖开只断开这一组。一种附魔可以同时给多件武器附着。"

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
    sheet.position = Vector2(36, 26)
    sheet.size = Vector2(1208, 752)
    sheet.set_meta("full_width", 1208)
    add_child(sheet)
    var title: Label = _label("武器背包", 34, Color("#17253a"), true)
    title.position = Vector2(48, 16)
    title.size = Vector2(860, 42)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    sheet.content.add_child(title)
    var hint: Label = _label("把可以搭配的两件武器拖到一起即可联动，已有的其他联动会保留。一种附魔可以同时给多件武器附着。把其中一对拖开只断开这一组；不能搭配的拖在一起会提示错误。", 16, Color("#66705e"), false)
    hint.position = Vector2(48, 58)
    _prepare_pack_copy(hint, 1000, 48)
    sheet.content.add_child(hint)
    var close_btn := Button.new()
    close_btn.name = "CloseLinkPack"
    close_btn.text = "关闭"
    close_btn.position = Vector2(1048, 18)
    close_btn.size = Vector2(110, 42)
    close_btn.focus_mode = Control.FOCUS_NONE
    _style_button(close_btn)
    close_btn.pressed.connect(request_close)
    KeyBindings.attach_to_button(close_btn, "cancel")
    sheet.content.add_child(close_btn)
    board = Control.new()
    board.name = "LinkPackBoard"
    board.position = Vector2(48, 112)
    board.size = BOARD_SIZE
    board.mouse_filter = Control.MOUSE_FILTER_PASS
    board.clip_contents = false
    sheet.content.add_child(board)
    status_label = _label("", 16, Color("#66705e"), false)
    status_label.name = "LinkPackStatus"
    status_label.position = Vector2(48, 698)
    _prepare_pack_copy(status_label, 1080, 40)
    sheet.content.add_child(status_label)
    _relock_pack_copy(self)

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
    card.clip_contents = false
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    card.set_meta("weapon_id", weapon_id)
    card.set_meta("in_cluster", in_cluster)
    card.gui_input.connect(func(event): _on_card_input(weapon_id, card, event))
    _paint_card(card, weapon_id, "idle")
    var info: Dictionary = node_info(weapon_id)
    var text_width: float = CARD_SIZE.x - 20.0
    var icon := TextureRect.new()
    icon.position = Vector2((CARD_SIZE.x - 72.0) * 0.5, 10)
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
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _prepare_pack_copy(title, text_width, 24)
    card.add_child(title)
    var stats_copy: String = str(info["stats"])
    var stats: Label = _label(stats_copy, 13, Color("#5a4a36"), false)
    stats.name = "CardStats"
    stats.position = Vector2(10, 80)
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var stats_height: float = maxf(40.0, _wrapped_size(stats_copy, 13, text_width).y + 6.0)
    _prepare_pack_copy(stats, text_width, stats_height)
    card.add_child(stats)
    var hint_copy: String = str(info["hint"])
    if in_cluster and hint_copy.is_empty():
        hint_copy = "已联动"
    var hint: Label = _label(hint_copy, 12, Color("#704127") if not in_cluster else Color("#7a4a22"), false)
    hint.name = "CardHint"
    hint.position = Vector2(10, stats.position.y + stats_height + 4.0)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var hint_height: float = maxf(44.0, _wrapped_size(hint_copy, 12, text_width).y + 8.0)
    _prepare_pack_copy(hint, text_width, hint_height)
    card.add_child(hint)
    var needed_height: float = hint.position.y + hint_height + 10.0
    if needed_height > card.size.y:
        card.size = Vector2(CARD_SIZE.x, needed_height)
        card.custom_minimum_size = card.size
    cards[weapon_id] = card
    return card

func _cluster_groups() -> Array:
    var recipes: Array = _active_recipes()
    var groups: Array = []
    for recipe in recipes:
        var hit: Array = []
        for index in range(groups.size()):
            var shares: bool = false
            for other in groups[index]:
                for weapon_id in other.get("weapons", []):
                    if recipe.get("weapons", []).has(weapon_id):
                        shares = true
                        break
                if shares:
                    break
            if shares:
                hit.append(index)
        if hit.is_empty():
            groups.append([recipe])
            continue
        var combined: Array = []
        for index in hit:
            combined.append_array(groups[index])
        combined.append(recipe)
        var leftover: Array = []
        for index in range(groups.size()):
            if not hit.has(index):
                leftover.append(groups[index])
        leftover.append(combined)
        groups = leftover
    for group in groups:
        var ordered: Array = []
        for recipe in recipes:
            if _group_has_id(group, str(recipe.get("id", ""))):
                if not _group_has_id(ordered, str(recipe.get("id", ""))):
                    ordered.append(recipe)
        group.clear()
        group.append_array(ordered)
    return groups

func _group_has_id(group: Array, link_id: String) -> bool:
    for recipe in group:
        if str(recipe.get("id", "")) == link_id:
            return true
    return false

func _shared_weapon(group: Array) -> String:
    var counts: Dictionary = {}
    for recipe in group:
        for weapon_id in recipe.get("weapons", []):
            var key: String = str(weapon_id)
            counts[key] = int(counts.get(key, 0)) + 1
    var best: String = ""
    var best_count: int = 0
    for key in counts:
        if int(counts[key]) > best_count:
            best = key
            best_count = int(counts[key])
    return best if best_count >= 2 else ""

func _make_group_cluster(group: Array) -> Control:
    if group.size() <= 1:
        var recipe: Dictionary = group[0] if not group.is_empty() else {}
        var weapons: Array = recipe.get("weapons", [])
        var first_id: String = str(weapons[0]) if weapons.size() > 0 else ""
        var second_id: String = str(weapons[1]) if weapons.size() > 1 else ""
        return _make_cluster(recipe, first_id, second_id)
    return _make_multi_cluster(group)

func _tag_cluster_card(card: Control, link_id: String, shared: bool = false) -> void:
    if card == null:
        return
    card.set_meta("home", card.position)
    if not shared:
        card.set_meta("unlink_id", link_id)
    card.set_meta("in_cluster", true)

func _make_cluster(recipe: Dictionary, first_id: String, second_id: String) -> Control:
    var cluster := Control.new()
    cluster.name = "LinkCluster_%s" % str(recipe.get("id", "link"))
    cluster.clip_contents = false
    cluster.mouse_filter = Control.MOUSE_FILTER_PASS
    var mid: Panel = make_link_details(recipe)
    var left: Panel = _make_card(first_id, true)
    var right: Panel = _make_card(second_id, true)
    var height: float = maxf(left.size.y, maxf(right.size.y, mid.size.y + 12.0))
    var width: float = CARD_SIZE.x * 2.0 + mid.size.x + 16.0
    cluster.size = Vector2(width, height)
    left.position = Vector2.ZERO
    cluster.add_child(left)
    _tag_cluster_card(left, str(recipe.get("id", "")))
    mid.position = Vector2(CARD_SIZE.x + 8, maxf(0.0, (height - mid.size.y) * 0.5))
    cluster.add_child(mid)
    right.position = Vector2(CARD_SIZE.x + mid.size.x + 16, 0)
    cluster.add_child(right)
    _tag_cluster_card(right, str(recipe.get("id", "")))
    return cluster

func _make_multi_cluster(group: Array) -> Control:
    var shared: String = _shared_weapon(group)
    var hosts: Array = []
    var host_links: Dictionary = {}
    for recipe in group:
        for weapon_id in recipe.get("weapons", []):
            var key: String = str(weapon_id)
            if key == shared:
                continue
            if not hosts.has(key):
                hosts.append(key)
            host_links[key] = str(recipe.get("id", ""))
    if shared.is_empty() or hosts.is_empty():
        return _make_cluster(group[0], str(group[0]["weapons"][0]), str(group[0]["weapons"][1]))
    var cluster := Control.new()
    cluster.name = "LinkCluster_%s" % str(group[0].get("id", "link"))
    cluster.clip_contents = false
    cluster.mouse_filter = Control.MOUSE_FILTER_PASS
    var gap: float = 18.0
    var card_row: Array = [shared]
    card_row.append_array(hosts)
    var cards_width: float = card_row.size() * CARD_SIZE.x + maxf(0, card_row.size() - 1) * gap
    var details_width: float = maxf(CLUSTER_MID.x, cards_width)
    var mid: Panel = make_link_details_list(group, details_width)
    var width: float = maxf(cards_width, mid.size.x)
    var catalyst: Panel = _make_card(shared, true)
    cluster.add_child(catalyst)
    catalyst.position = Vector2(0, 0)
    _tag_cluster_card(catalyst, "", true)
    var host_cards: Array = []
    for index in range(hosts.size()):
        var host_id: String = hosts[index]
        var card: Panel = _make_card(host_id, true)
        card.position = Vector2((index + 1) * (CARD_SIZE.x + gap), 0)
        cluster.add_child(card)
        _tag_cluster_card(card, str(host_links.get(host_id, "")))
        host_cards.append(card)
    var card_height: float = catalyst.size.y
    for card in host_cards:
        card_height = maxf(card_height, card.size.y)
    mid.position = Vector2(maxf(0.0, (width - mid.size.x) * 0.5), card_height + 14.0)
    cluster.add_child(mid)
    cluster.size = Vector2(width, mid.position.y + mid.size.y)
    var lines := Control.new()
    lines.name = "LinkConnections"
    lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
    lines.anchor_left = 0
    lines.anchor_top = 0
    lines.anchor_right = 0
    lines.anchor_bottom = 0
    lines.position = Vector2.ZERO
    lines.size = cluster.size
    cluster.add_child(lines)
    cluster.move_child(lines, 0)
    var from: Vector2 = catalyst.position + catalyst.size * 0.5
    lines.draw.connect(func():
        for card in host_cards:
            if card == null or not is_instance_valid(card):
                continue
            var to: Vector2 = card.position + card.size * 0.5
            lines.draw_line(from, to, Color("#7a4a22"), 6.0, true)
            lines.draw_line(from, to, Color("#b4583e"), 3.0, true)
    )
    lines.queue_redraw()
    return cluster


func make_link_details(recipe: Dictionary) -> Panel:
    return make_link_details_list([recipe], CLUSTER_MID.x)

func make_link_details_list(recipes: Array, width: float = CLUSTER_MID.x) -> Panel:
    var mid := Panel.new()
    mid.name = "LinkDetails"
    if recipes.size() == 1:
        mid.set_meta("link_id", str(recipes[0].get("id", "")))
    mid.clip_contents = false
    mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var mid_box := StyleBoxFlat.new()
    mid_box.bg_color = Color("#efe0be")
    mid_box.border_color = Color("#b4583e")
    mid_box.set_border_width_all(2)
    mid_box.set_corner_radius_all(3)
    mid.add_theme_stylebox_override("panel", mid_box)
    _fill_link_details(mid, recipes, width)
    return mid

func _fill_link_details(mid: Panel, recipes: Array, width: float) -> void:
    var pad := 14.0
    var text_width: float = maxf(80.0, width - pad * 2.0)
    var cursor := 10.0
    for index in range(recipes.size()):
        var recipe: Dictionary = recipes[index]
        var name_label: Label = _label(str(recipe.get("name", "")), 17, Color("#9a3b2c"), true)
        name_label.name = "ClusterName" if recipes.size() == 1 else "ClusterName_%d" % index
        name_label.position = Vector2(pad, cursor)
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var name_height: float = maxf(26.0, _wrapped_size(str(recipe.get("name", "")), 17, text_width).y + 6.0)
        _prepare_pack_copy(name_label, text_width, name_height)
        mid.add_child(name_label)
        cursor += name_height + 4.0
        var benefit_name: String = "ClusterBenefit" if recipes.size() == 1 else "ClusterBenefit_%d" % index
        var cost_name: String = "ClusterCost" if recipes.size() == 1 else "ClusterCost_%d" % index
        cursor += _add_detail_block(mid, "优点", Catalog.benefit_text(recipe), benefit_name, pad, cursor, text_width)
        cursor += 8.0
        cursor += _add_detail_block(mid, "缺点", Catalog.cost_text(recipe), cost_name, pad, cursor, text_width)
        cursor += 12.0
    mid.size = Vector2(width, maxf(CLUSTER_MID.y if recipes.size() == 1 else 120.0, cursor + 4.0))
    mid.custom_minimum_size = mid.size
    _fit_pack_copy(mid)
    if mid.is_inside_tree():
        _finish_details_layout(mid)
    else:
        mid.ready.connect(_finish_details_layout.bind(mid), CONNECT_ONE_SHOT)

func _add_detail_block(mid: Panel, title_copy: String, body_copy: String, body_name: String, pad: float, cursor: float, text_width: float) -> float:
    var title: Label = _label(title_copy, 14, Color("#9a3b2c"), true)
    title.name = body_name + "Title"
    title.position = Vector2(pad, cursor)
    _prepare_pack_copy(title, text_width, 24)
    mid.add_child(title)
    var body_height: float = maxf(26.0, _wrapped_size(body_copy, 13, text_width).y + 8.0)
    var body: Label = _label(body_copy, 13, Color("#3a2a1c"), false)
    body.name = body_name
    body.position = Vector2(pad, cursor + 24.0)
    _prepare_pack_copy(body, text_width, body_height)
    mid.add_child(body)
    return 24.0 + body_height

func _prepare_pack_copy(label: Label, width: float, height: float) -> void:
    label.autowrap_mode = PACK_WRAP
    label.clip_text = false
    label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    var wanted := Vector2(width, height)
    label.custom_minimum_size = Vector2.ZERO
    label.custom_minimum_size = Vector2(wanted.x, 0)
    label.size = wanted
    if label.size != wanted:
        label.custom_minimum_size = Vector2(wanted.x, 0)
        label.size = wanted
    label.set_meta("pack_copy_size", wanted)

func _relock_pack_copy(node: Node = null) -> void:
    var root: Node = self if node == null else node
    if not is_instance_valid(root):
        return
    if root is Label and root.has_meta("pack_copy_size"):
        var wanted: Vector2 = root.get_meta("pack_copy_size")
        root.custom_minimum_size = Vector2(wanted.x, 0)
        root.size = wanted
        if root.autowrap_mode == PACK_WRAP:
            root.clip_text = false
            root.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    for child in root.get_children():
        _relock_pack_copy(child)

func _label_font(label: Label, fallback_size: int = 13) -> Dictionary:
    var font: Font = label.get_theme_font("font") if label != null else body_font
    if font == null:
        font = body_font
    var font_size: int = label.get_theme_font_size("font_size") if label != null else fallback_size
    if font_size <= 0:
        font_size = fallback_size
    return {"font": font, "size": font_size}

func _fit_pack_copy(node: Node = null) -> void:
    var root: Node = self if node == null else node
    if not is_instance_valid(root):
        return
    if root is Label and root.has_meta("pack_copy_size"):
        var wanted: Vector2 = root.get_meta("pack_copy_size")
        var info: Dictionary = _label_font(root)
        var font: Font = info["font"]
        var measured: Vector2 = wanted
        if font != null:
            measured = font.get_multiline_string_size(root.text, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, wanted.x), int(info["size"]), -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_GRAPHEME_BOUND)
        var height: float = maxf(wanted.y, measured.y + 8.0)
        var size := Vector2(wanted.x, height)
        root.custom_minimum_size = Vector2(size.x, 0)
        root.size = size
        root.set_meta("pack_copy_size", size)
        root.clip_text = false
        root.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    for child in root.get_children():
        _fit_pack_copy(child)
    if root is Control and (root.name.begins_with("LinkDetails") or root.name.begins_with("WeaponCard_")):
        var bottom: float = 8.0
        for child in root.get_children():
            if child is Control:
                bottom = maxf(bottom, child.position.y + child.size.y)
        if bottom + 10.0 > root.size.y:
            root.size = Vector2(root.size.x, bottom + 10.0)
            root.custom_minimum_size = root.size

func _finish_details_layout(mid: Control) -> void:
    if mid == null or not is_instance_valid(mid):
        return
    _relock_pack_copy(mid)
    _fit_pack_copy(mid)

func _finish_pack_layout() -> void:
    _relock_pack_copy(self)
    _fit_pack_copy(self)

func _wrapped_size(text: String, font_size: int, width: float) -> Vector2:
    var font: Font = body_font
    if font == null or text.is_empty():
        return Vector2(width, float(font_size + 8))
    return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, width), font_size, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_GRAPHEME_BOUND)

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
            var unlink_id: String = str(source_card.get_meta("unlink_id", ""))
            var involved: Array = _recipes_for_weapon(source_id)
            if unlink_id.is_empty() and involved.size() == 1:
                unlink_id = str(involved[0].get("id", ""))
            if involved.size() > 1 and unlink_id.is_empty():
                refresh()
                last_toast = "请把要断开的那一件拖开"
                _set_status(last_toast)
                return
            try_unlink(source_id, unlink_id)
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
