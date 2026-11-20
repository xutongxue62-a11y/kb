extends Control
const Catalog = preload("res://src/catalog.gd")
const Rules = preload("res://src/rules.gd")
const Details = preload("res://src/ui_weapon_details.gd")
const Growth = preload("res://src/growth.gd")
const PaperUI = preload("res://src/ui_paper.gd")
const KeyBindings = preload("res://src/key_bindings.gd")
const GameFonts = preload("res://src/game_fonts.gd")

const ERROR_INCOMPATIBLE := "这两件武器不能联动"
const CARD_SIZE := Vector2(176, 210)
const CLUSTER_MID := Vector2(420, 252)
const BOARD_SIZE := Vector2(1136, 590)
const BOARD_MARGIN := 10.0
const CARD_GAP := 8.0
const MIN_DETAILS_WIDTH := 360.0
const UNLINK_DISTANCE := 86.0
const PACK_WRAP := TextServer.AUTOWRAP_ARBITRARY
const EDGE_ZONE := 28.0
const RESULT_SIZE := Vector2(128, 38)
const KNOT_LIFT := 44.0
const RESULT_GAP := 18.0
const ROW_BOTTOM_PAD := 10.0

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
var results: Dictionary = {}
var ropes: Control
var placeholder: Control
var insert_marker: Control
var tooltip: Control
var tooltip_link_id: String = ""
var dragging_id: String = ""
var drag_offset: Vector2 = Vector2.ZERO
var drag_home: Vector2 = Vector2.ZERO
var body_font: Font
var _reflowing: bool = false

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
		if recipes.size() > 1:
			info["hint"] = "触媒 · 已联动两组"
		elif _is_catalyst(weapon_id):
			info["hint"] = "触媒 · 已联动"
		else:
			info["hint"] = "已联动"
		if valid_drop_targets(weapon_id).size() > recipes.size():
			if not str(info["hint"]).contains("已联动"):
				info["hint"] = "已联动 · 可再连"
			elif not str(info["hint"]).contains("可再连"):
				info["hint"] = str(info["hint"]) + " · 可再连"
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
	return "\n".join(parts)

func error_text() -> String:
	return last_error

func toast_text() -> String:
	return last_toast

func recipe_for_pair(weapon_a: String, weapon_b: String) -> Dictionary:
	if weapon_a.is_empty() or weapon_b.is_empty() or weapon_a == weapon_b:
		return {}
	for key in Catalog.LINK_ORDER:
		if key == "none" or not Catalog.LINKS.has(key):
			continue
		var recipe: Dictionary = Catalog.LINKS[key]
		var weapons: Array = recipe.get("weapons", [])
		if weapons.size() != 2:
			continue
		var first: String = str(weapons[0])
		var second: String = str(weapons[1])
		if (first == weapon_a and second == weapon_b) or (first == weapon_b and second == weapon_a):
			return recipe
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

func try_reorder(weapon_id: String, insertion_index: int) -> Dictionary:
	var result: Dictionary = _apply_reorder(weapon_id, insertion_index)
	if result.get("ok", false):
		last_error = ""
		if not result.get("unchanged", false):
			last_toast = str(result.get("toast", "已调换武器位置"))
	refresh()
	return result

func try_reorder_before(weapon_id: String, target_id: String) -> Dictionary:
	var ids: Array = weapon_ids()
	var index: int = ids.find(target_id)
	if index < 0:
		return {"ok": false, "error": "无法调换位置"}
	return try_reorder(weapon_id, index)

func try_reorder_after(weapon_id: String, target_id: String) -> Dictionary:
	var ids: Array = weapon_ids()
	var index: int = ids.find(target_id)
	if index < 0:
		return {"ok": false, "error": "无法调换位置"}
	return try_reorder(weapon_id, index + 1)

func request_close() -> void:
	closed.emit()

func refresh() -> void:
	if board == null:
		_set_status(_status_copy())
		return
	hide_result_tooltip()
	for child in board.get_children():
		board.remove_child(child)
		child.queue_free()
	cards.clear()
	clusters.clear()
	results.clear()
	ropes = null
	placeholder = null
	insert_marker = null
	var ids: Array = weapon_ids()
	ropes = _make_ropes()
	board.add_child(ropes)
	placeholder = _make_placeholder()
	board.add_child(placeholder)
	insert_marker = _make_insert_marker()
	board.add_child(insert_marker)
	for weapon_id in ids:
		var card: Control = _make_card(weapon_id)
		board.add_child(card)
		cards[weapon_id] = card
	for recipe in _active_recipes():
		var node: Control = _make_result_node(recipe)
		board.add_child(node)
		var link_id: String = str(recipe.get("id", ""))
		results[link_id] = node
		clusters[link_id] = node
	_layout_pack_board()
	_relock_pack_copy(self)
	_fit_pack_copy(self)
	_layout_pack_board()
	_set_status(_status_copy())
	_apply_drag_highlights()
	if is_inside_tree():
		call_deferred("_finish_pack_layout")

func connection_pairs() -> Array:
	var pairs: Array = []
	for recipe in _active_recipes():
		var weapons: Array = recipe.get("weapons", [])
		if weapons.size() < 2:
			continue
		var a: String = str(weapons[0])
		var b: String = str(weapons[1])
		if a.is_empty() or b.is_empty() or a == b:
			continue
		var pair: Array = [a, b] if a < b else [b, a]
		if not pairs.has(pair):
			pairs.append(pair)
	return pairs

func card_icon(weapon_id: String) -> TextureRect:
	var card: Control = cards.get(weapon_id, null)
	if card == null or not is_instance_valid(card):
		return null
	return card.find_child("CardIcon", true, false) as TextureRect

func appearance_level(weapon_id: String) -> int:
	return _owned_level(weapon_id)

func result_control(link_id: String) -> Control:
	return results.get(link_id, null)

func hover_result(link_id: String) -> void:
	_show_result_tooltip(link_id)

func hide_result_tooltip() -> void:
	tooltip_link_id = ""
	if tooltip != null and is_instance_valid(tooltip):
		tooltip.visible = false
		tooltip.queue_free()
		tooltip = null

func tooltip_text() -> String:
	if tooltip == null or not is_instance_valid(tooltip) or not tooltip.visible:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	_collect_text(tooltip, parts)
	return "\n".join(parts)

func drop_at(source_id: String, global_pos: Vector2) -> Dictionary:
	return _apply_pointer_drop(source_id, global_pos)

func card_face_point(weapon_id: String) -> Vector2:
	var card: Control = cards.get(weapon_id, null)
	if card == null or not is_instance_valid(card):
		return Vector2.ZERO
	return card.get_global_rect().get_center()

func card_edge_point(weapon_id: String, side: String) -> Vector2:
	var card: Control = cards.get(weapon_id, null)
	if card == null or not is_instance_valid(card):
		return Vector2.ZERO
	var rect: Rect2 = card.get_global_rect()
	if side == "after" or side == "right":
		return Vector2(rect.end.x - 8.0, rect.get_center().y)
	return Vector2(rect.position.x + 8.0, rect.get_center().y)

func _apply_drop(weapon_a: String, weapon_b: String) -> Dictionary:
	if host == null:
		return {"ok": false, "error": ERROR_INCOMPATIBLE, "link_id": _current_link_id()}
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

func _apply_reorder(weapon_id: String, insertion_index: int) -> Dictionary:
	if host == null or weapon_id.is_empty():
		return {"ok": false, "error": "无法调换位置"}
	var ids: Array = weapon_ids()
	var from: int = ids.find(weapon_id)
	if from < 0:
		return {"ok": false, "error": "无法调换位置"}
	var target: int = clampi(insertion_index, 0, ids.size())
	if target > from:
		target -= 1
	target = clampi(target, 0, ids.size() - 1)
	if target == from:
		return {"ok": true, "unchanged": true, "order": ids, "toast": ""}
	var inventory: Array = host.inventory
	var item = null
	var from_inv: int = -1
	for index in range(inventory.size()):
		if str(inventory[index].get("id", "")) == weapon_id:
			item = inventory[index]
			from_inv = index
			break
	if item == null or from_inv < 0:
		return {"ok": false, "error": "无法调换位置"}
	inventory.remove_at(from_inv)
	var dest: int = clampi(target, 0, inventory.size())
	inventory.insert(dest, item)
	return {"ok": true, "order": weapon_ids(), "toast": "已调换武器位置", "unchanged": false}

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

func _is_catalyst(weapon_id: String) -> bool:
	return weapon_id in ["staff", "firepot", "totem"]

func _owned_level(weapon_id: String) -> int:
	if host == null:
		return 1
	if host.has_method("weapon_level"):
		return maxi(1, int(host.weapon_level(weapon_id)))
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
	return "把能搭配的两件拖到卡面上即可连上，拖到侧边或空档可调换位置；把其中一对拖开只断开这一组。优点缺点把鼠标放到结果上再看。"

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
	sheet.position = Vector2(24, 22)
	sheet.size = Vector2(1232, 756)
	sheet.set_meta("full_width", 1232)
	add_child(sheet)
	var title: Label = _label("武器背包", 34, Color("#17253a"), true)
	title.position = Vector2(44, 14)
	title.size = Vector2(860, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sheet.content.add_child(title)
	var hint: Label = _label("把能搭配的两件拖到卡面上，就会用绳子连上。拖到卡片侧边或空档可以调换位置，方便整理。已有的其他联动会保留；把其中一对拖开只断开这一组。把鼠标放到结果节点上，再看优点和缺点。", 16, Color("#66705e"), false)
	hint.position = Vector2(44, 54)
	_prepare_pack_copy(hint, 1020, 52)
	sheet.content.add_child(hint)
	var close_btn := Button.new()
	close_btn.name = "CloseLinkPack"
	close_btn.text = "关闭"
	close_btn.position = Vector2(1070, 16)
	close_btn.size = Vector2(110, 42)
	close_btn.focus_mode = Control.FOCUS_NONE
	_style_button(close_btn)
	close_btn.pressed.connect(request_close)
	KeyBindings.attach_to_button(close_btn, "cancel")
	sheet.content.add_child(close_btn)
	board = Control.new()
	board.name = "LinkPackBoard"
	board.position = Vector2(40, 110)
	board.size = BOARD_SIZE
	board.mouse_filter = Control.MOUSE_FILTER_PASS
	board.clip_contents = false
	sheet.content.add_child(board)
	status_label = _label("", 16, Color("#66705e"), false)
	status_label.name = "LinkPackStatus"
	status_label.position = Vector2(44, 704)
	_prepare_pack_copy(status_label, 1140, 40)
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

func _make_card(weapon_id: String) -> Panel:
	var card := Panel.new()
	card.name = "WeaponCard_%s" % weapon_id
	card.size = CARD_SIZE
	card.custom_minimum_size = CARD_SIZE
	card.clip_contents = false
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.set_meta("weapon_id", weapon_id)
	card.set_meta("in_cluster", not _recipes_for_weapon(weapon_id).is_empty())
	var involved: Array = _recipes_for_weapon(weapon_id)
	if involved.size() == 1:
		card.set_meta("unlink_id", str(involved[0].get("id", "")))
	else:
		card.set_meta("unlink_id", "")
	card.gui_input.connect(func(event): _on_card_input(weapon_id, card, event))
	_paint_card(card, weapon_id, "idle")
	var info: Dictionary = node_info(weapon_id)
	var text_width: float = CARD_SIZE.x - 16.0
	var icon := TextureRect.new()
	icon.name = "CardIcon"
	icon.position = Vector2((CARD_SIZE.x - 88.0) * 0.5, 8)
	icon.size = Vector2(88, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color.WHITE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if host != null and host.library != null:
		icon.texture = host.library.weapon_texture(weapon_id, _owned_level(weapon_id))
		if hud != null and hud.library != null and hud.library.weapon_material != null:
			icon.material = hud.library.weapon_material
		elif host.library.weapon_material != null:
			icon.material = host.library.weapon_material
	card.add_child(icon)
	var ports := Control.new()
	ports.name = "CardPorts"
	ports.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ports.set_anchors_preset(Control.PRESET_FULL_RECT)
	ports.offset_left = 0
	ports.offset_top = 0
	ports.offset_right = 0
	ports.offset_bottom = 0
	ports.draw.connect(func():
		_draw_card_ports(ports, card)
	)
	card.add_child(ports)
	var title: Label = _label(str(info["name"]), 16, Color("#3a2a1c"), true)
	title.position = Vector2(8, 82)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prepare_pack_copy(title, text_width, 22)
	card.add_child(title)
	var stats_copy: String = str(info["stats"])
	var stats: Label = _label(stats_copy, 12, Color("#5a4a36"), false)
	stats.name = "CardStats"
	stats.position = Vector2(8, 104)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats_height: float = maxf(36.0, _wrapped_size(stats_copy, 12, text_width).y + 4.0)
	_prepare_pack_copy(stats, text_width, stats_height)
	card.add_child(stats)
	var hint_copy: String = str(info["hint"])
	var hint: Label = _label(hint_copy, 11, Color("#704127") if not bool(info["linked"]) else Color("#7a4a22"), false)
	hint.name = "CardHint"
	hint.position = Vector2(8, stats.position.y + stats_height + 2.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint_height: float = maxf(36.0, _wrapped_size(hint_copy, 11, text_width).y + 6.0)
	_prepare_pack_copy(hint, text_width, hint_height)
	card.add_child(hint)
	var needed_height: float = hint.position.y + hint_height + 8.0
	if needed_height > card.size.y:
		card.size = Vector2(CARD_SIZE.x, needed_height)
		card.custom_minimum_size = card.size
	ports.queue_redraw()
	return card

func _draw_card_ports(canvas: Control, card: Control) -> void:
	if card == null or not is_instance_valid(card):
		return
	var size: Vector2 = card.size
	var spots := PackedVector2Array([
		Vector2(size.x * 0.5, 5.0),
		Vector2(5.0, size.y * 0.42),
		Vector2(size.x - 5.0, size.y * 0.42),
		Vector2(5.0, size.y * 0.72),
		Vector2(size.x - 5.0, size.y * 0.72)
	])
	for at in spots:
		canvas.draw_circle(at, 3.4, Color("#c4a06a"))
		canvas.draw_arc(at, 3.4, 0.0, TAU, 12, Color("#7a4a22"), 1.2, true)

func _make_result_node(recipe: Dictionary) -> Panel:
	var node := Panel.new()
	var link_id: String = str(recipe.get("id", ""))
	node.name = "LinkResult_%s" % link_id
	node.size = RESULT_SIZE
	node.custom_minimum_size = RESULT_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.mouse_default_cursor_shape = Control.CURSOR_ARROW
	node.set_meta("link_id", link_id)
	node.set_meta("recipe", recipe)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#5c3a24")
	box.border_color = Color("#3a2416")
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.shadow_color = Color(0.12, 0.08, 0.05, 0.2)
	box.shadow_size = 4
	box.shadow_offset = Vector2(1, 2)
	node.add_theme_stylebox_override("panel", box)
	var caption: Label = _label("联动结果", 10, Color("#e8d3a8"), false)
	caption.name = "ResultCaption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(4, 1)
	_prepare_pack_copy(caption, RESULT_SIZE.x - 8.0, 14)
	node.add_child(caption)
	var name_copy: String = str(recipe.get("name", ""))
	var name_label: Label = _label(name_copy, 15, Color("#f7ecd3"), true)
	name_label.name = "ResultName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(4, 14)
	var name_width: float = maxf(RESULT_SIZE.x - 8.0, _wrapped_size(name_copy, 15, 220.0).x + 8.0)
	var name_height: float = maxf(20.0, _wrapped_size(name_copy, 15, name_width).y + 2.0)
	_prepare_pack_copy(name_label, name_width, name_height)
	node.add_child(name_label)
	var wanted_w: float = maxf(RESULT_SIZE.x, name_width + 8.0)
	var wanted_h: float = maxf(RESULT_SIZE.y, name_label.position.y + name_height + 4.0)
	node.size = Vector2(wanted_w, wanted_h)
	node.custom_minimum_size = node.size
	name_label.position.x = (node.size.x - name_label.size.x) * 0.5
	caption.size.x = node.size.x - 8.0
	node.mouse_entered.connect(func(): _show_result_tooltip(link_id))
	node.mouse_exited.connect(func():
		if tooltip_link_id == link_id:
			hide_result_tooltip()
	)
	return node

func _make_ropes() -> Control:
	var lines := Control.new()
	lines.name = "LinkRopes"
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.position = Vector2.ZERO
	lines.size = BOARD_SIZE
	lines.draw.connect(_draw_ropes.bind(lines))
	return lines

func _make_placeholder() -> Control:
	var slot := Control.new()
	slot.name = "DragPlaceholder"
	slot.size = CARD_SIZE
	slot.visible = false
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.draw.connect(func():
		var rect := Rect2(Vector2(3, 3), slot.size - Vector2(6, 6))
		slot.draw_rect(rect, Color(0.48, 0.36, 0.22, 0.12), false, 2.0)
		var dash := 8.0
		var gap := 5.0
		var color := Color("#9a7a52")
		_draw_dashed_rect(slot, rect, color, dash, gap)
	)
	return slot

func _make_insert_marker() -> Control:
	var marker := Control.new()
	marker.name = "InsertMarker"
	marker.visible = false
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.size = Vector2(8, CARD_SIZE.y)
	marker.draw.connect(func():
		var top := Vector2(4, 0)
		var bottom := Vector2(4, marker.size.y)
		marker.draw_line(top, bottom, Color("#7a4a22"), 4.0, true)
		marker.draw_line(top, bottom, Color("#d4a25a"), 1.8, true)
	)
	return marker

func _draw_dashed_rect(canvas: Control, rect: Rect2, color: Color, dash: float, gap: float) -> void:
	var points := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		rect.position
	])
	for index in range(points.size() - 1):
		var start: Vector2 = points[index]
		var finish: Vector2 = points[index + 1]
		var travel: Vector2 = finish - start
		var length: float = travel.length()
		if length <= 0.001:
			continue
		var direction: Vector2 = travel / length
		var cursor: float = 0.0
		while cursor < length:
			var a: Vector2 = start + direction * cursor
			var b: Vector2 = start + direction * minf(length, cursor + dash)
			canvas.draw_line(a, b, color, 1.6, true)
			cursor += dash + gap

func _draw_ropes(canvas: Control) -> void:
	if canvas == null or not is_instance_valid(canvas):
		return
	for recipe in _active_recipes():
		_draw_recipe_rope(canvas, recipe, Color("#6a3f22"), Color("#c9894a"), Color("#e8c98a"))
	if dragging_id.is_empty():
		return
	var source: Control = cards.get(dragging_id, null)
	if source == null or not is_instance_valid(source):
		return
	for other in valid_drop_targets(dragging_id):
		var target: Control = cards.get(other, null)
		if target == null or not is_instance_valid(target):
			continue
		var preview: Dictionary = {"weapons": [dragging_id, other], "id": "", "name": ""}
		_draw_recipe_rope(canvas, preview, Color("#6a3f22", 0.45), Color("#d4a25a", 0.7), Color("#f0d9a8", 0.5), source, target)

func _draw_recipe_rope(canvas: Control, recipe: Dictionary, ink: Color, rope: Color, highlight: Color, left_override: Control = null, right_override: Control = null) -> void:
	var weapons: Array = recipe.get("weapons", [])
	if weapons.size() < 2:
		return
	var left: Control = left_override if left_override != null else cards.get(str(weapons[0]), null)
	var right: Control = right_override if right_override != null else cards.get(str(weapons[1]), null)
	if left == null or right == null or not is_instance_valid(left) or not is_instance_valid(right):
		return
	if left.position.x > right.position.x:
		var swap_card: Control = left
		left = right
		right = swap_card
	var start: Vector2 = _port_point(left)
	var finish: Vector2 = _port_point(right)
	var knot: Vector2 = _knot_point_for_cards(left, right)
	var result_node: Control = results.get(str(recipe.get("id", "")), null)
	if result_node != null and is_instance_valid(result_node) and str(recipe.get("id", "")) != "":
		knot.x = result_node.position.x + result_node.size.x * 0.5
		var bottom: float = result_node.position.y + result_node.size.y
		var stem := PackedVector2Array([
			Vector2(knot.x, bottom),
			Vector2(knot.x, knot.y)
		])
		_stroke_rope(canvas, stem, ink, rope, highlight)
	var left_ctrl := Vector2(start.x, knot.y + 6.0)
	var right_ctrl := Vector2(finish.x, knot.y + 6.0)
	_stroke_rope(canvas, _curve_points(start, left_ctrl, knot), ink, rope, highlight)
	_stroke_rope(canvas, _curve_points(finish, right_ctrl, knot), ink, rope, highlight)
	_draw_knot(canvas, knot, ink, rope, highlight)

func _stroke_rope(canvas: Control, points: PackedVector2Array, ink: Color, rope: Color, highlight: Color) -> void:
	if points.size() < 2:
		return
	canvas.draw_polyline(points, ink, 7.0, true)
	canvas.draw_polyline(points, rope, 4.2, true)
	var lifted := PackedVector2Array()
	for point in points:
		lifted.append(point + Vector2(-0.8, -0.9))
	canvas.draw_polyline(lifted, highlight, 1.4, true)

func _draw_knot(canvas: Control, at: Vector2, ink: Color, rope: Color, highlight: Color) -> void:
	canvas.draw_circle(at, 7.2, ink)
	canvas.draw_circle(at, 5.4, rope)
	canvas.draw_circle(at + Vector2(-1.2, -1.4), 2.0, highlight)
	canvas.draw_arc(at, 6.4, 0.4, 2.2, 8, Color(ink, 0.85), 1.6, true)
	canvas.draw_arc(at, 6.4, 3.4, 5.2, 8, Color(ink, 0.85), 1.6, true)

func _curve_points(start: Vector2, control: Vector2, finish: Vector2, steps: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps + 1):
		var t: float = float(index) / float(steps)
		var u: float = 1.0 - t
		points.append(u * u * start + 2.0 * u * t * control + t * t * finish)
	return points

func _port_point(card: Control) -> Vector2:
	return Vector2(card.position.x + card.size.x * 0.5, card.position.y + 4.0)

func _knot_point_for_cards(left: Control, right: Control) -> Vector2:
	var start: Vector2 = _port_point(left)
	var finish: Vector2 = _port_point(right)
	return Vector2((start.x + finish.x) * 0.5, minf(start.y, finish.y) - KNOT_LIFT)

func _layout_pack_board() -> void:
	if board == null or _reflowing:
		return
	_reflowing = true
	var ids: Array = weapon_ids()
	var heights: Array = []
	var card_height: float = CARD_SIZE.y
	for weapon_id in ids:
		var card: Control = cards.get(weapon_id, null)
		if card == null or not is_instance_valid(card):
			continue
		card_height = maxf(card_height, card.size.y)
		heights.append(card.size.y)
	for weapon_id in ids:
		var card: Control = cards.get(weapon_id, null)
		if card == null or not is_instance_valid(card):
			continue
		if card.size.y != card_height or card.size.x != CARD_SIZE.x:
			card.size = Vector2(CARD_SIZE.x, card_height)
			card.custom_minimum_size = card.size
	var count: int = ids.size()
	var row_width: float = float(count) * CARD_SIZE.x + float(maxi(0, count - 1)) * CARD_GAP
	var start_x: float = maxf(BOARD_MARGIN, (BOARD_SIZE.x - row_width) * 0.5)
	var row_y: float = BOARD_SIZE.y - card_height - ROW_BOTTOM_PAD
	for index in range(count):
		var card: Control = cards.get(ids[index], null)
		if card == null or not is_instance_valid(card):
			continue
		if dragging_id == str(ids[index]):
			card.set_meta("home", Vector2(start_x + float(index) * (CARD_SIZE.x + CARD_GAP), row_y))
			continue
		card.position = Vector2(start_x + float(index) * (CARD_SIZE.x + CARD_GAP), row_y)
		card.set_meta("home", card.position)
		card.z_index = 2
	if placeholder != null and is_instance_valid(placeholder):
		placeholder.size = Vector2(CARD_SIZE.x, card_height)
		if not dragging_id.is_empty() and cards.has(dragging_id):
			placeholder.position = cards[dragging_id].get_meta("home", drag_home)
			placeholder.visible = true
			placeholder.z_index = 1
			placeholder.queue_redraw()
		else:
			placeholder.visible = false
	_layout_result_nodes(row_y)
	if ropes != null and is_instance_valid(ropes):
		ropes.position = Vector2.ZERO
		ropes.size = board.size
		ropes.z_index = 0
		ropes.queue_redraw()
	if tooltip != null and is_instance_valid(tooltip) and tooltip.visible and not tooltip_link_id.is_empty():
		_place_tooltip(tooltip_link_id)
	_reflowing = false

func _layout_result_nodes(row_y: float) -> void:
	var placed: Array = []
	for recipe in _active_recipes():
		var link_id: String = str(recipe.get("id", ""))
		var node: Control = results.get(link_id, null)
		if node == null or not is_instance_valid(node):
			continue
		var weapons: Array = recipe.get("weapons", [])
		var left: Control = cards.get(str(weapons[0]), null) if weapons.size() >= 2 else null
		var right: Control = cards.get(str(weapons[1]), null) if weapons.size() >= 2 else null
		if left == null or right == null:
			continue
		if left.position.x > right.position.x:
			var swap_card: Control = left
			left = right
			right = swap_card
		var knot: Vector2 = _knot_point_for_cards(left, right)
		var pos := Vector2(knot.x - node.size.x * 0.5, knot.y - RESULT_GAP - node.size.y)
		pos.x = clampf(pos.x, BOARD_MARGIN, BOARD_SIZE.x - node.size.x - BOARD_MARGIN)
		pos.y = clampf(pos.y, BOARD_MARGIN, maxf(BOARD_MARGIN, row_y - node.size.y - 36.0))
		var box := Rect2(pos, node.size)
		for other in placed:
			var hit: Rect2 = other
			if not box.grow(8.0).intersects(hit):
				continue
			if box.position.x <= hit.position.x:
				box.position.x = maxf(BOARD_MARGIN, hit.position.x - box.size.x - 10.0)
			else:
				box.position.x = minf(BOARD_SIZE.x - box.size.x - BOARD_MARGIN, hit.end.x + 10.0)
			if box.grow(6.0).intersects(hit):
				box.position.y = maxf(BOARD_MARGIN, hit.position.y - box.size.y - 8.0)
		node.position = box.position
		node.z_index = 4
		placed.append(Rect2(node.position, node.size))

func _show_result_tooltip(link_id: String) -> void:
	if link_id.is_empty() or not Catalog.LINKS.has(link_id) or link_id == "none":
		return
	var recipe: Dictionary = Catalog.LINKS[link_id]
	if tooltip != null and is_instance_valid(tooltip):
		tooltip.queue_free()
	tooltip = make_link_details(recipe)
	tooltip.name = "LinkTooltip"
	tooltip.z_index = 30
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(tooltip)
	tooltip_link_id = link_id
	tooltip.visible = true
	_place_tooltip(link_id)

func _place_tooltip(link_id: String) -> void:
	if tooltip == null or not is_instance_valid(tooltip):
		return
	var anchor: Control = results.get(link_id, null)
	var pos := Vector2(BOARD_MARGIN, BOARD_MARGIN)
	if anchor != null and is_instance_valid(anchor):
		pos = Vector2(anchor.position.x - tooltip.size.x - 12.0, anchor.position.y - 8.0)
		if pos.x < BOARD_MARGIN:
			pos.x = anchor.position.x + anchor.size.x + 12.0
		if pos.x + tooltip.size.x > BOARD_SIZE.x - BOARD_MARGIN:
			pos.x = BOARD_SIZE.x - tooltip.size.x - BOARD_MARGIN
		if pos.y + tooltip.size.y > BOARD_SIZE.y - BOARD_MARGIN:
			pos.y = BOARD_SIZE.y - tooltip.size.y - BOARD_MARGIN
		pos.y = maxf(BOARD_MARGIN, pos.y)
	tooltip.position = pos

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
	mid.set_meta("recipes", recipes)
	_fill_link_details(mid, recipes, width)
	return mid

func _fill_link_details(mid: Panel, recipes: Array, width: float) -> void:
	var pad := 14.0
	var columns: int = 1
	if recipes.size() >= 2 and width >= 520.0:
		columns = mini(recipes.size(), 2)
		if recipes.size() >= 3 and width >= 780.0:
			columns = mini(recipes.size(), 3)
	var col_gap := 16.0
	var col_width: float = width - pad * 2.0 if columns <= 1 else (width - pad * 2.0 - col_gap * float(columns - 1)) / float(columns)
	var text_width: float = maxf(80.0, col_width)
	var col_cursor: Array = []
	for _col in range(columns):
		col_cursor.append(10.0)
	for index in range(recipes.size()):
		var recipe: Dictionary = recipes[index]
		var col: int = index % columns
		var origin_x: float = pad + float(col) * (text_width + col_gap)
		var cursor: float = float(col_cursor[col])
		var name_label: Label = _label(str(recipe.get("name", "")), 17, Color("#9a3b2c"), true)
		name_label.name = "ClusterName" if recipes.size() == 1 else "ClusterName_%d" % index
		name_label.position = Vector2(origin_x, cursor)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var name_height: float = maxf(26.0, _wrapped_size(str(recipe.get("name", "")), 17, text_width).y + 6.0)
		_prepare_pack_copy(name_label, text_width, name_height)
		mid.add_child(name_label)
		cursor += name_height + 4.0
		var benefit_name: String = "ClusterBenefit" if recipes.size() == 1 else "ClusterBenefit_%d" % index
		var cost_name: String = "ClusterCost" if recipes.size() == 1 else "ClusterCost_%d" % index
		cursor += _add_detail_block(mid, "优点", Catalog.benefit_text(recipe), benefit_name, origin_x, cursor, text_width)
		cursor += 8.0
		cursor += _add_detail_block(mid, "缺点", Catalog.cost_text(recipe), cost_name, origin_x, cursor, text_width)
		cursor += 12.0
		col_cursor[col] = cursor
	var bottom: float = 10.0
	for cursor in col_cursor:
		bottom = maxf(bottom, float(cursor))
	var min_h: float = CLUSTER_MID.y if recipes.size() == 1 and columns == 1 else 120.0
	mid.custom_minimum_size = Vector2.ZERO
	mid.size = Vector2(width, maxf(min_h, bottom + 4.0))
	mid.custom_minimum_size = mid.size
	mid.set_meta("recipes", recipes)
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
	if root is Control and (str(root.name).begins_with("LinkDetails") or str(root.name).begins_with("WeaponCard_") or str(root.name).begins_with("LinkTooltip") or str(root.name).begins_with("LinkResult_")):
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
	_layout_pack_board()
	_relock_pack_copy(self)
	_fit_pack_copy(self)
	_layout_pack_board()

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
		_on_drag_moved()
		card.accept_event()

func _begin_drag(weapon_id: String, card: Control, local_pos: Vector2) -> void:
	hide_result_tooltip()
	dragging_id = weapon_id
	drag_offset = local_pos
	drag_home = card.position
	card.set_meta("home", card.position)
	card.z_index = 20
	_paint_card(card, weapon_id, "drag")
	last_error = ""
	_apply_drag_highlights()
	_on_drag_moved()
	_set_status("拖到可搭配的卡面上即可联动；拖到侧边或空档可调换位置；拖开已连上的那一对即可断开。")

func _on_drag_moved() -> void:
	_apply_drag_highlights()
	if ropes != null and is_instance_valid(ropes):
		ropes.queue_redraw()
	_update_insert_marker()

func _update_insert_marker() -> void:
	if insert_marker == null or not is_instance_valid(insert_marker):
		return
	if dragging_id.is_empty():
		insert_marker.visible = false
		return
	var pointer: Vector2 = get_global_mouse_position()
	var intent: Dictionary = _intent_at(pointer, dragging_id)
	if str(intent.get("kind", "")) != "reorder":
		insert_marker.visible = false
		return
	var index: int = int(intent.get("index", 0))
	var ids: Array = weapon_ids()
	var count: int = ids.size()
	var row_width: float = float(count) * CARD_SIZE.x + float(maxi(0, count - 1)) * CARD_GAP
	var start_x: float = maxf(BOARD_MARGIN, (BOARD_SIZE.x - row_width) * 0.5)
	var row_y: float = BOARD_SIZE.y - CARD_SIZE.y - ROW_BOTTOM_PAD
	var first: Control = cards.get(ids[0], null) if not ids.is_empty() else null
	if first != null and is_instance_valid(first):
		row_y = first.get_meta("home", first.position).y
		insert_marker.size.y = first.size.y
	var x: float = start_x + float(index) * (CARD_SIZE.x + CARD_GAP) - CARD_GAP * 0.5 - 4.0
	insert_marker.position = Vector2(x, row_y)
	insert_marker.visible = true
	insert_marker.z_index = 6
	insert_marker.queue_redraw()

func _finish_drag(global_pos: Vector2) -> void:
	var source_id: String = dragging_id
	var source_card: Control = cards.get(source_id, null)
	dragging_id = ""
	if insert_marker != null and is_instance_valid(insert_marker):
		insert_marker.visible = false
	if source_card != null and is_instance_valid(source_card):
		source_card.z_index = 0
	_apply_pointer_drop(source_id, global_pos)

func _apply_pointer_drop(source_id: String, global_pos: Vector2) -> Dictionary:
	if source_id.is_empty():
		refresh()
		return {"ok": false, "kind": "none"}
	var intent: Dictionary = _intent_at(global_pos, source_id)
	var kind: String = str(intent.get("kind", ""))
	if kind == "link":
		var result: Dictionary = try_drop(source_id, str(intent.get("target_id", "")))
		result["kind"] = "link"
		return result
	if kind == "reorder":
		var result: Dictionary = try_reorder(source_id, int(intent.get("index", 0)))
		result["kind"] = "reorder"
		return result
	if kind == "unlink":
		var unlink_id: String = str(intent.get("link_id", ""))
		var involved: Array = _recipes_for_weapon(source_id)
		if unlink_id.is_empty() and involved.size() == 1:
			unlink_id = str(involved[0].get("id", ""))
		if involved.size() > 1 and unlink_id.is_empty():
			refresh()
			last_toast = "请把要断开的那一件拖开"
			_set_status(last_toast)
			return {"ok": false, "kind": "unlink", "error": last_toast}
		var result: Dictionary = try_unlink(source_id, unlink_id)
		result["kind"] = "unlink"
		return result
	refresh()
	return {"ok": true, "kind": "cancel", "unchanged": true}

func _intent_at(global_pos: Vector2, source_id: String) -> Dictionary:
	var ids: Array = weapon_ids()
	var hit: Dictionary = _hit_card_zone(global_pos, source_id, ids)
	if not hit.is_empty():
		return hit
	var row: Dictionary = _hit_row_gap(global_pos, source_id, ids)
	if not row.is_empty():
		return row
	var source_card: Control = cards.get(source_id, null)
	if source_card != null and is_instance_valid(source_card) and not _recipes_for_weapon(source_id).is_empty():
		var home: Vector2 = source_card.get_meta("home", drag_home)
		var home_center: Vector2 = source_card.global_position - source_card.position + home + source_card.size * 0.5
		var moved: bool = source_card.position.distance_to(home) >= UNLINK_DISTANCE
		var pointer_away: bool = global_pos.distance_to(home_center) >= UNLINK_DISTANCE
		if moved or pointer_away:
			var unlink_id: String = str(source_card.get_meta("unlink_id", ""))
			return {"kind": "unlink", "link_id": unlink_id}
	return {"kind": "cancel"}

func _hit_card_zone(global_pos: Vector2, source_id: String, ids: Array) -> Dictionary:
	for index in range(ids.size()):
		var weapon_id: String = str(ids[index])
		if weapon_id == source_id:
			continue
		var card: Control = cards.get(weapon_id, null)
		if card == null or not is_instance_valid(card):
			continue
		var rect: Rect2 = card.get_global_rect()
		if not rect.has_point(global_pos):
			continue
		var local_x: float = global_pos.x - rect.position.x
		if local_x <= EDGE_ZONE:
			return {"kind": "reorder", "index": index, "side": "before", "target_id": weapon_id}
		if local_x >= rect.size.x - EDGE_ZONE:
			return {"kind": "reorder", "index": index + 1, "side": "after", "target_id": weapon_id}
		return {"kind": "link", "target_id": weapon_id}
	return {}

func _hit_row_gap(global_pos: Vector2, source_id: String, ids: Array) -> Dictionary:
	if ids.is_empty():
		return {}
	var first: Control = cards.get(ids[0], null)
	if first == null or not is_instance_valid(first):
		return {}
	var top: float = first.get_global_rect().position.y - 18.0
	var bottom: float = first.get_global_rect().end.y + 18.0
	if global_pos.y < top or global_pos.y > bottom:
		return {}
	var count: int = ids.size()
	for index in range(count):
		var card: Control = cards.get(ids[index], null)
		if card == null or not is_instance_valid(card):
			continue
		var rect: Rect2 = card.get_global_rect()
		if index == 0 and global_pos.x < rect.position.x:
			return {"kind": "reorder", "index": 0, "side": "before", "target_id": str(ids[0])}
		var next_left: float = rect.end.x + CARD_GAP
		if index < count - 1:
			var nxt: Control = cards.get(ids[index + 1], null)
			if nxt != null and is_instance_valid(nxt):
				next_left = nxt.get_global_rect().position.x
		else:
			next_left = board.get_global_rect().end.x
		if global_pos.x >= rect.end.x and global_pos.x <= next_left:
			return {"kind": "reorder", "index": index + 1, "side": "after", "target_id": str(ids[index])}
	return {}

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
	if node is CanvasItem and not node.visible:
		return
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
			_on_drag_moved()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(get_global_mouse_position())
		get_viewport().set_input_as_handled()
