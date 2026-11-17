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
            return "↵"
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


# 保存进度 / 角色属性 stay off the Settings and 改按键 screens.
const SETTINGS_HIDDEN := ["save", "stats"]
const HINT_NAME := "KeyHint"
const HINT_INSET := 18.0
const HINT_GAP := 8.0


static func settings_order() -> Array:
    var result: Array = []
    for action in ORDER:
        if action not in SETTINGS_HIDDEN:
            result.append(action)
    return result


static func hint_font_size(button: BaseButton) -> int:
    # Juniper 指示（2026-11-17）：按键提示字太小看不清，统一用与按钮正文同等
    # 的清晰字号，不再缩小一号。全游戏只有这一套按键提示样式。
    var base: int = button.get_theme_font_size("font_size")
    if base <= 0:
        base = 18
    return clampi(base, 16, 20)


static func measure_hint(button: BaseButton, text: String) -> Vector2:
    var font: Font = button.get_theme_font("font")
    var fs: int = hint_font_size(button)
    if font == null:
        return Vector2(maxf(18.0, float(text.length()) * 10.0), float(fs) + 2.0)
    var measured: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
    return Vector2(ceili(measured.x) + 2.0, maxf(measured.y, float(fs) + 2.0))


static func make_hint(button: BaseButton, action: String) -> KeyHint:
    var hint := KeyHint.new()
    hint.name = HINT_NAME
    hint.apply_action(action, code_of(action), caption_for(action))
    _style_hint(button, hint)
    return hint


static func _style_hint(button: BaseButton, hint: KeyHint) -> void:
    var text: String = "…" if hint.listening else hint.caption
    hint.text = text
    var size: Vector2 = measure_hint(button, text)
    hint.custom_minimum_size = size
    hint.size = size
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", hint_font_size(button))
    var font: Font = button.get_theme_font("font")
    if font != null:
        hint.add_theme_font_override("font", font)
    var ink: Color = Color("#3c3328")
    if button.has_theme_color_override("font_color") or button.get_theme_color("font_color").a > 0.0:
        ink = button.get_theme_color("font_color")
    hint.add_theme_color_override("font_color", ink)
    hint.add_theme_stylebox_override("normal", StyleBoxEmpty.new())


static func attach_to_button(button: BaseButton, action: String) -> void:
    if button == null or not is_instance_valid(button):
        return
    if bool(button.get_meta("bind_row", false)):
        fill_bind_button(button, action, false)
        return
    button.set_meta("key_action", action)
    button.text = strip_legacy_hint(button.text)
    var hint: KeyHint = button.find_child(HINT_NAME, false, false) as KeyHint
    if hint == null:
        hint = make_hint(button, action)
        button.add_child(hint)
    else:
        hint.apply_action(action, code_of(action), caption_for(action))
        _style_hint(button, hint)
    _reserve_hint_space(button, hint)
    _place_hint(button, hint)
    if not button.has_meta("_keyhint_resized"):
        button.set_meta("_keyhint_resized", true)
        button.resized.connect(_on_button_resized.bind(button, hint))


static func fill_bind_button(button: BaseButton, action: String, listening: bool = false) -> void:
    if button == null or not is_instance_valid(button):
        return
    button.set_meta("key_action", action)
    button.set_meta("bind_row", true)
    var leftover: Node = button.find_child(HINT_NAME, false, false)
    if leftover != null:
        leftover.queue_free()
    button.text = "…" if listening else caption_for(action)


static func _on_button_resized(button: BaseButton, hint: KeyHint) -> void:
    if is_instance_valid(button) and is_instance_valid(hint):
        _style_hint(button, hint)
        _place_hint(button, hint)


static func _reserve_hint_space(button: BaseButton, hint: KeyHint) -> void:
    var extra: float = hint.custom_minimum_size.x + HINT_INSET + HINT_GAP
    for state in ["normal", "hover", "pressed", "disabled"]:
        var box: StyleBox = button.get_theme_stylebox(state)
        if box is StyleBoxFlat:
            var flat: StyleBoxFlat = (box as StyleBoxFlat).duplicate()
            var base: float = float(button.get_meta("_keyhint_margin_" + state, flat.content_margin_right))
            button.set_meta("_keyhint_margin_" + state, base)
            flat.content_margin_right = maxf(base, extra)
            button.add_theme_stylebox_override(state, flat)


static func _place_hint(button: BaseButton, hint: KeyHint) -> void:
    var size: Vector2 = hint.custom_minimum_size
    if size.x < 1.0 or size.y < 1.0:
        size = measure_hint(button, hint.text)
        hint.custom_minimum_size = size
    var inset: float = HINT_INSET
    var x: float = button.size.x - size.x - inset
    var y: float = (button.size.y - size.y) * 0.5
    var min_x: float = 8.0
    var max_x: float = button.size.x - size.x - 8.0
    if max_x < min_x:
        x = maxf(4.0, button.size.x - size.x - 4.0)
    else:
        x = clampf(x, min_x, max_x)
    y = clampf(y, 0.0, maxf(0.0, button.size.y - size.y))
    hint.position = Vector2(x, y)
    hint.size = size


static func refresh_tree(node: Node) -> void:
    if node == null:
        return
    if node is BaseButton and node.has_meta("key_action"):
        var action: String = str(node.get_meta("key_action"))
        if bool(node.get_meta("bind_row", false)):
            fill_bind_button(node as BaseButton, action, false)
        else:
            attach_to_button(node as BaseButton, action)
    elif node is KeyHint:
        var hint := node as KeyHint
        if not hint.action_id.is_empty():
            hint.apply_action(hint.action_id, code_of(hint.action_id), caption_for(hint.action_id))
        var parent: Node = hint.get_parent()
        if parent is BaseButton:
            _style_hint(parent as BaseButton, hint)
            _place_hint(parent as BaseButton, hint)
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


class KeyHint extends Label:
    var action_id: String = ""
    var listening: bool = false
    var code: int = KEY_NONE
    var caption: String = ""

    func apply_action(action: String, bind_code: int, bind_caption: String) -> void:
        action_id = action
        code = bind_code
        caption = bind_caption
        text = "…" if listening else bind_caption

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_theme_stylebox_override("normal", StyleBoxEmpty.new())
