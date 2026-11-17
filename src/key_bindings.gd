extends RefCounted
class_name KeyBindings
## Official remappable actions. Defaults match current keyboard behavior.
## Movement (WASD / arrows), Shift dodge, and debug keys (R / F2 / F3) stay fixed.

const FIELD := "key_bindings"

const ACTIONS := {
    "confirm": {"name": "确认", "default": KEY_ENTER},
    "cancel": {"name": "取消", "default": KEY_ESCAPE},
    "hide_ui": {"name": "隐藏界面", "default": KEY_V},
    "save": {"name": "手动保存", "default": KEY_F5},
    "scatter": {"name": "散射 / 集火", "default": KEY_SPACE},
    "link": {"name": "武器联动", "default": KEY_Q},
    "aim": {"name": "瞄准目标", "default": KEY_E},
    "stats": {"name": "角色属性", "default": KEY_B},
    "growth_trial": {"name": "试用成长", "default": KEY_G},
    "shop_1": {"name": "栏位 1", "default": KEY_1},
    "shop_2": {"name": "栏位 2", "default": KEY_2},
    "shop_3": {"name": "栏位 3", "default": KEY_3},
    "shop_4": {"name": "栏位 4", "default": KEY_4},
    "shop_5": {"name": "栏位 5", "default": KEY_5},
    "shop_6": {"name": "栏位 6", "default": KEY_6},
}

const ORDER := [
    "confirm", "cancel", "hide_ui", "save", "scatter", "link", "aim", "stats",
    "growth_trial", "shop_1", "shop_2", "shop_3", "shop_4", "shop_5", "shop_6",
]

const BIND_BUTTON := {
    "confirm": "BindConfirm",
    "cancel": "BindCancel",
    "hide_ui": "BindHideUI",
    "save": "BindSave",
    "scatter": "BindScatter",
    "link": "BindLink",
    "aim": "BindAim",
    "stats": "BindStats",
    "growth_trial": "BindGrowthTrial",
    "shop_1": "BindShop1",
    "shop_2": "BindShop2",
    "shop_3": "BindShop3",
    "shop_4": "BindShop4",
    "shop_5": "BindShop5",
    "shop_6": "BindShop6",
}


const BLOCKED := [
    KEY_W, KEY_A, KEY_S, KEY_D,
    KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
    KEY_R, KEY_F2, KEY_F3,
    KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META,
    KEY_TAB, KEY_BACKSPACE, KEY_DELETE, KEY_INSERT,
    KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK,
]

static var current: Dictionary = {}


static func _static_init() -> void:
    reset_defaults()


static func reset_defaults() -> void:
    current = {}
    for action in ACTIONS:
        current[action] = int(ACTIONS[action]["default"])


static func display_name(action: String) -> String:
    return str(ACTIONS.get(action, {}).get("name", action))


static func code_of(action: String) -> int:
    if current.is_empty():
        reset_defaults()
    return int(current.get(action, ACTIONS.get(action, {}).get("default", KEY_NONE)))


static func apply_settings(settings: Dictionary) -> void:
    reset_defaults()
    var raw: Variant = settings.get(FIELD, null)
    if typeof(raw) != TYPE_DICTIONARY:
        return
    for action in raw:
        if not ACTIONS.has(action):
            continue
        if typeof(raw[action]) != TYPE_INT and typeof(raw[action]) != TYPE_FLOAT:
            continue
        var code: int = int(raw[action])
        if code <= 0:
            continue
        current[action] = code


static func export_bindings() -> Dictionary:
    if current.is_empty():
        reset_defaults()
    var payload := {}
    for action in ACTIONS:
        payload[action] = int(current.get(action, ACTIONS[action]["default"]))
    return payload


static func action_for_key(code: int) -> String:
    if current.is_empty():
        reset_defaults()
    for action in ORDER:
        if int(current[action]) == code:
            return action
    return ""


static func set_binding(action: String, code: int) -> Dictionary:
    if not ACTIONS.has(action):
        return {"ok": false, "error": "未知功能"}
    if code == KEY_ESCAPE:
        return {"ok": false, "error": "已取消改键"}
    if is_blocked(code):
        return {"ok": false, "error": "该键不能改绑，请按其他键"}
    var used: String = action_for_key(code)
    if not used.is_empty() and used != action:
        return {"ok": false, "error": "该键已被「%s」占用，请按其他键" % display_name(used)}
    current[action] = code
    return {"ok": true, "error": ""}


static func is_blocked(code: int) -> bool:
    return code in BLOCKED or code == KEY_NONE or code <= 0


static func aliases(action: String, code: int) -> Array:
    var result: Array = [code]
    if action == "confirm" and code == KEY_ENTER:
        result.append(KEY_KP_ENTER)
    if action.begins_with("shop_") and code >= KEY_1 and code <= KEY_6:
        result.append(KEY_KP_1 + (code - KEY_1))
    return result


static func matches_code(code: int, action: String) -> bool:
    return code in aliases(action, code_of(action))


static func matches_event(event: InputEvent, action: String) -> bool:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return false
    return matches_code(event.physical_keycode, action)


static func shop_slot(code: int) -> int:
    for index in range(6):
        if matches_code(code, "shop_%d" % (index + 1)):
            return index
    return -1


static func caption(code: int) -> String:
    match code:
        KEY_ENTER, KEY_KP_ENTER:
            return "ENTER"
        KEY_ESCAPE:
            return "Esc"
        KEY_SPACE:
            return "Space"
        KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12:
            return "F%d" % (code - KEY_F1 + 1)
        KEY_1, KEY_KP_1:
            return "1"
        KEY_2, KEY_KP_2:
            return "2"
        KEY_3, KEY_KP_3:
            return "3"
        KEY_4, KEY_KP_4:
            return "4"
        KEY_5, KEY_KP_5:
            return "5"
        KEY_6, KEY_KP_6:
            return "6"
        KEY_7, KEY_KP_7:
            return "7"
        KEY_8, KEY_KP_8:
            return "8"
        KEY_9, KEY_KP_9:
            return "9"
        KEY_0, KEY_KP_0:
            return "0"
    var raw: String = OS.get_keycode_string(code)
    if raw.is_empty():
        return "?"
    if raw.begins_with("Kp "):
        raw = raw.substr(3)
    return raw


static func caption_for(action: String) -> String:
    return caption(code_of(action))


static func keycap_size(code: int, height: float = 26.0) -> Vector2:
    if code == KEY_SPACE:
        return Vector2(maxf(56.0, height * 2.2), height)
    if code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_ESCAPE:
        return Vector2(maxf(40.0, height * 1.55), height)
    return Vector2(maxf(32.0, height * 1.25), height)


static func make_keycap(action: String, height: float = 26.0) -> Keycap:
    var cap := Keycap.new()
    cap.name = "KeycapHint"
    cap.apply_action(action, code_of(action), caption_for(action))
    cap.custom_minimum_size = keycap_size(code_of(action), height)
    cap.size = cap.custom_minimum_size
    cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return cap


static func attach_to_button(button: BaseButton, action: String) -> void:
    if button == null or not is_instance_valid(button):
        return
    button.set_meta("key_action", action)
    button.text = strip_legacy_hint(button.text)
    var cap: Keycap = button.find_child("KeycapHint", false, false) as Keycap
    if cap == null:
        cap = make_keycap(action, 24.0)
        button.add_child(cap)
    else:
        cap.apply_action(action, code_of(action), caption_for(action))
        cap.custom_minimum_size = keycap_size(code_of(action), 24.0)
        cap.queue_redraw()
    _reserve_keycap_space(button, cap)
    _place_keycap(button, cap)
    if not button.has_meta("_keycap_resized"):
        button.set_meta("_keycap_resized", true)
        button.resized.connect(_on_button_resized.bind(button, cap))


static func _on_button_resized(button: BaseButton, cap: Keycap) -> void:
    if is_instance_valid(button) and is_instance_valid(cap):
        _place_keycap(button, cap)


static func _reserve_keycap_space(button: BaseButton, cap: Keycap) -> void:
    var extra: float = cap.custom_minimum_size.x + 10.0
    for state in ["normal", "hover", "pressed", "disabled"]:
        var box: StyleBox = button.get_theme_stylebox(state)
        if box is StyleBoxFlat:
            var flat: StyleBoxFlat = (box as StyleBoxFlat).duplicate()
            var base: float = float(button.get_meta("_keycap_margin_" + state, flat.content_margin_right))
            button.set_meta("_keycap_margin_" + state, base)
            flat.content_margin_right = maxf(base, extra)
            button.add_theme_stylebox_override(state, flat)


static func _place_keycap(button: BaseButton, cap: Keycap) -> void:
    var size: Vector2 = cap.custom_minimum_size
    var right: float = 8.0
    var box: StyleBox = button.get_theme_stylebox("normal")
    if box != null:
        right = maxf(6.0, box.get_margin(SIDE_RIGHT) - size.x - 2.0)
        if right < 6.0:
            right = 6.0
    cap.size = size
    cap.position = Vector2(button.size.x - size.x - right, (button.size.y - size.y) * 0.5)


static func refresh_tree(node: Node) -> void:
    if node == null:
        return
    if node is BaseButton and node.has_meta("key_action"):
        attach_to_button(node as BaseButton, str(node.get_meta("key_action")))
    elif node is Keycap:
        var cap := node as Keycap
        if not cap.action_id.is_empty():
            cap.apply_action(cap.action_id, code_of(cap.action_id), caption_for(cap.action_id))
        cap.queue_redraw()
    for child in node.get_children():
        refresh_tree(child)


static func strip_legacy_hint(text: String) -> String:
    var cleaned: String = text
    var patterns := [
        " [回车]", " [Enter]", " [Esc]", " [ESC]", " [V]", " [Q]", " [E]", " [B]", " [G]",
        " [F5]", " [F2]", " [F3]", " [空格]", "  [Enter]", "  [Esc]",
    ]
    for token in patterns:
        cleaned = cleaned.replace(token, "")
    return cleaned.strip_edges()


static func contains_forbidden_hint(text: String) -> bool:
    return text.contains("回车")


class Keycap extends Control:
    var action_id: String = ""
    var listening: bool = false
    var code: int = KEY_NONE
    var caption: String = ""

    func apply_action(action: String, bind_code: int, bind_caption: String) -> void:
        action_id = action
        code = bind_code
        caption = bind_caption
        queue_redraw()

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        if custom_minimum_size == Vector2.ZERO:
            custom_minimum_size = Vector2(32, 24)
        queue_redraw()

    func _notification(what: int) -> void:
        if what == NOTIFICATION_RESIZED:
            queue_redraw()

    func _draw() -> void:
        var w: float = size.x
        var h: float = size.y
        if w < 8.0 or h < 8.0:
            return
        var face := Color("#f7efe0")
        var edge := Color("#3c3328")
        var lip := Color("#cbb89a")
        if listening:
            face = Color("#f3d27a")
            edge = Color("#7a4a16")
        var radius: float = 4.0
        draw_rect(Rect2(1.0, 3.0, w - 2.0, h - 3.0), lip, true)
        _draw_round_rect(Rect2(1.0, 0.0, w - 2.0, h - 4.0), face, edge, radius)
        if listening:
            var font: Font = ThemeDB.fallback_font
            var fs: int = clampi(int(h * 0.55), 9, 13)
            draw_string(font, Vector2(0.0, (h - 4.0) * 0.5 + fs * 0.35), "…", HORIZONTAL_ALIGNMENT_CENTER, w, fs, edge)
            return
        if code == KEY_ENTER or code == KEY_KP_ENTER:
            _draw_enter_arrow(Rect2(4.0, 2.0, w - 8.0, h - 7.0), edge)
        else:
            var label: String = caption
            var font: Font = ThemeDB.fallback_font
            var fs: int = clampi(int(h * (0.46 if label.length() > 2 else 0.58)), 9, 14)
            var ty: float = (h - 4.0) * 0.5 + fs * 0.35
            draw_string(font, Vector2(0.0, ty), label, HORIZONTAL_ALIGNMENT_CENTER, w, fs, edge)

    func _draw_round_rect(rect: Rect2, fill: Color, border: Color, radius: float) -> void:
        draw_rect(rect, fill, true)
        draw_rect(rect, border, false, 1.4)
        # Corner ticks so the chip reads as a key, even without rounded primitives.
        var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.25)
        var pts := PackedVector2Array([
            rect.position + Vector2(r, 0.0),
            rect.position + Vector2(rect.size.x - r, 0.0),
            rect.position + Vector2(rect.size.x, r),
            rect.position + Vector2(rect.size.x, rect.size.y - r),
            rect.position + Vector2(rect.size.x - r, rect.size.y),
            rect.position + Vector2(r, rect.size.y),
            rect.position + Vector2(0.0, rect.size.y - r),
            rect.position + Vector2(0.0, r),
        ])
        draw_polyline(pts + PackedVector2Array([pts[0]]), border, 1.4, true)

    func _draw_enter_arrow(rect: Rect2, color: Color) -> void:
        var y: float = rect.position.y + rect.size.y * 0.38
        var x1: float = rect.position.x + rect.size.x * 0.18
        var x2: float = rect.position.x + rect.size.x * 0.78
        var stem: float = rect.size.y * 0.42
        var mid: float = x1 + (x2 - x1) * 0.22
        draw_line(Vector2(x2, y), Vector2(mid, y), color, 1.8, true)
        draw_line(Vector2(mid, y), Vector2(mid, y + stem), color, 1.8, true)
        var tip := Vector2(mid, y + stem)
        var left := Vector2(mid - 5.0, y + stem - 4.5)
        var right := Vector2(mid + 5.0, y + stem - 4.5)
        draw_colored_polygon(PackedVector2Array([tip, left, right]), color)
