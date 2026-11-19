extends CanvasLayer
const GameFonts=preload("res://src/game_fonts.gd")
const Catalog = preload("res://src/catalog.gd")
const Growth = preload("res://src/growth.gd")
const ActorView = preload("res://src/actor_view.gd")
const FrontUI = preload("res://src/ui_frontend.gd")
const PaperUI = preload("res://src/ui_paper.gd")
const PageTransition = preload("res://src/ui_transition.gd")
const ButtonFx = preload("res://src/ui_ink_button_fx.gd")
const UIAudio = preload("res://src/ui_audio.gd")
const BattleUI = preload("res://src/ui_battle_hud.gd")
const OfferUI = preload("res://src/ui_offer_layout.gd")
const KeyBindings = preload("res://src/key_bindings.gd")

signal start_requested(trial: bool)
signal formation_requested
signal combo_requested
signal elite_requested
signal trial_requested
signal pause_requested
signal restart_requested
signal choice_selected(weapon_id: String)
signal reward_sell_requested(weapon_id: String)
signal starter_selected(weapon_id: String)
signal stats_requested
signal growth_requested
signal new_trial_requested
signal buy_requested(index: int)
signal reroll_requested
signal replace_requested(remove_id: String)
signal replace_cancelled
signal next_round_requested
signal save_requested
signal continue_requested
signal home_requested
signal settings_changed(autosave: bool)
signal music_changed(enabled: bool)
signal volume_changed(kind: String, value: float)
signal damage_numbers_changed(enabled: bool)
signal display_mode_changed(fullscreen: bool)
signal key_bindings_changed
signal link_discovery_enable(link_id)
signal link_discovery_closed

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
var hide_ui_button: Button
var hud_hidden: bool = false
var xp_bar: ProgressBar
var hp_bar: ProgressBar
var xp_label: Label
var last_hp: float = -1.0
var last_xp: float = -1.0
var status_strip: PanelContainer
var growth_label: Label
var growth_button: Button
var current_max_hp: float = 8.0
var screen: String = "start"
var save_available: bool = false
var autosave_enabled: bool = true
var save_note: String = "尚无可继续的存档"
var save_note_label: Label
var coin_label: Label
var boss_label: Label
var boss_bar: ProgressBar
var menu_kills: int = 0
var autosave_toggle: CheckButton
var battle_nodes: Array = []
var menu_hides_hud: bool = true
var choice_ids: Array = []
var replace_pending_view: Dictionary = {}
var replace_inventory_view: Array = []
var replace_stage_view: int = 1
var replace_chosen: String = ""
var replace_confirm_dim: ColorRect = null
var replace_confirm_column: VBoxContainer = null
var link_discover_dim: ColorRect = null
var link_discover_column: VBoxContainer = null
var link_discover_recipes: Array = []
var link_discover_complete: Array = []
var link_discover_over_shop: bool = false
var ink: Color = Color("#17253a")
var cream: Color = Color("#f4ead6")
var stamp: Color = Color("#c0453a")
var last_coins: int = -1
var last_kills: int = -1
var backdrop: TextureRect
var veil
var display_font: SystemFont
var body_font: SystemFont
var sfx_players: Array = []
var sfx_streams: Dictionary = {}
var entered_screen: String = ""
var transition_tween: Tween
var olive: Color = Color("#6d7f55")
var rust: Color = Color("#c0453a")
var dusk: Color = Color("#3d5a58")
var bone: Color = Color("#f4ead6")
var moss: Color = Color("#c5d4a8")
var selected_character: String = "caveman"
var preview_character: String = "caveman"
var character_best_wave: Dictionary = {}
var debug_cheats: bool = false
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var damage_numbers_enabled: bool = true
var fullscreen_enabled: bool = false
var shop_state: Dictionary = {}
var choice_reason: String = ""
var choice_inventory: Array = []
var choice_levels: Dictionary = {}
var choice_offer_levels: Dictionary = {}
var choice_stage: int = 1
var help_in_run: bool = false
var settings_in_run: bool = false
var bind_listen_action: String = ""
var bind_status: String = ""
var pending_help_trial: String = ""
var menu_summary: Dictionary = {}
var hurt_flash_layer: Control
var front_return_screen: String = "title"
var modal_snapshot: Texture2D
var page_snapshot: Texture2D
var save_summary: Dictionary = {}
var input_lock_until: int = 0
var launch_committed: bool = false
var departure_label: Label
var ui_audio
var previous_screen: String = ""
var map_label: Label
var dodge_label: Label
var dodge_bar: ProgressBar
var music_enabled := true
var music_toggle: BaseButton
var scroll_closing := false
var scroll_close_tween: Tween

func can_animate() -> bool:
    return DisplayServer.get_name() != "headless"

func meter_style(background: Color, border: Color = Color("#2a221c")) -> StyleBoxFlat:
    var box: StyleBoxFlat = style(background, border)
    box.content_margin_left = 2
    box.content_margin_right = 2
    box.content_margin_top = 2
    box.content_margin_bottom = 2
    box.set_corner_radius_all(4)
    box.shadow_size = 0
    return box

func style(background: Color, border: Color = Color("#2a221c")) -> StyleBoxFlat:
    var box: StyleBoxFlat = StyleBoxFlat.new()
    box.bg_color = background
    box.border_color = border
    box.set_border_width_all(2)
    box.set_corner_radius_all(3)
    box.content_margin_left = 14
    box.content_margin_right = 14
    box.content_margin_top = 9
    box.content_margin_bottom = 9
    box.shadow_color = Color(0.12, 0.08, 0.05, 0.22)
    box.shadow_size = 8
    box.shadow_offset = Vector2(2, 4)
    return box

func make_stamp(text: String) -> Label:
    var result: Label = make_label(text, 16, stamp)
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result.custom_minimum_size = Vector2(64, 30)
    var box: StyleBoxFlat = style(Color(0, 0, 0, 0), stamp)
    box.shadow_size = 0
    box.set_border_width_all(2)
    box.content_margin_left = 8
    box.content_margin_right = 8
    box.content_margin_top = 3
    box.content_margin_bottom = 3
    result.add_theme_stylebox_override("normal", box)
    return result

func pop_in(node: Control, delay: float = 0.0, tilt: float = -5.0) -> void:
    if node == null or not can_animate():
        return
    node.modulate.a = 0.0
    call_deferred("_begin_pop", node, delay, tilt)

func _begin_pop(node: Control, delay: float, tilt: float) -> void:
    if not is_instance_valid(node) or not node.is_inside_tree() or not can_animate():
        if is_instance_valid(node):
            node.modulate.a = 1.0
            node.scale = Vector2.ONE
            node.rotation_degrees = 0.0
        return
    if node.size.x < 2.0 or node.size.y < 2.0:
        if not node.has_meta("pop_waiting"):
            node.set_meta("pop_waiting", true)
            node.resized.connect(_begin_pop.bind(node, delay, tilt), CONNECT_ONE_SHOT)
            get_tree().create_timer(0.05).timeout.connect(_begin_pop.bind(node, delay, tilt))
        elif node.has_meta("pop_waiting"):
            node.modulate.a = 1.0
            node.scale = Vector2.ONE
            node.rotation_degrees = 0.0
        return
    node.remove_meta("pop_waiting")
    node.pivot_offset = node.size * 0.5
    node.scale = Vector2(0.88, 0.92)
    node.rotation_degrees = tilt
    var tw: Tween = create_tween()
    tw.set_parallel(true)
    tw.tween_property(node, "modulate:a", 1.0, 0.16).set_delay(delay)
    tw.tween_property(node, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
    tw.tween_property(node, "rotation_degrees", 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)

func pop_children(parent: Node, start_delay: float = 0.05, step: float = 0.05) -> void:
    if not can_animate():
        return
    var index: int = 0
    for child in parent.get_children():
        if child is Control:
            pop_in(child, start_delay + step * float(index), 4.0 if index % 2 == 0 else -4.0)
            index += 1

func pulse(node: Control) -> void:
    if node == null or not can_animate() or not node.is_inside_tree():
        return
    var previous: Tween = node.get_meta("hud_pulse") if node.has_meta("hud_pulse") else null
    if previous != null and previous.is_valid(): previous.kill()
    node.pivot_offset = node.size * 0.5
    var tw: Tween = create_tween()
    node.set_meta("hud_pulse",tw)
    tw.tween_property(node, "scale", Vector2(1.0,1.12) if node is ProgressBar else Vector2(1.16,1.16), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func press_motion(button: BaseButton) -> void:
    if button.get_meta("ui_armed", false):
        return
    button.set_meta("ui_armed", true)
    bind_hover_audio(button)
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var feedback = ButtonFx.new()
    feedback.name = "InkFeedback"
    feedback.button = button
    button.add_child(feedback)
    if not can_animate():
        feedback.set_process(false)

func bind_hover_audio(button: BaseButton) -> void:
    if button.get_meta("hover_audio_bound",false): return
    button.set_meta("hover_audio_bound",true)
    var state: Dictionary={"inside":false}
    button.mouse_entered.connect(func():
        if state.inside: return
        state.inside=true
        if not button.disabled and button.is_visible_in_tree() and not ui_busy(): play_ui("button_hover"))
    button.mouse_exited.connect(func(): state.inside=false)

func play_ui(key: String) -> void:
    if ui_audio == null or not can_animate():
        return
    var aliases := {"ui_hover":"", "ui_click":"button_press", "ui_open":"paper_popup", "ui_whoosh":"page_turn", "ui_back":"paper_close", "ui_stamp":"choice_confirm"}
    var cue: String = str(aliases.get(key, key))
    if not cue.is_empty():
        ui_audio.play(cue)

func preload_ui_sfx() -> void:
    if ui_audio == null:
        ui_audio = UIAudio.new()
        ui_audio.set_volume(sfx_volume)
        add_child(ui_audio)

func present_backdrop(kind: String) -> void:
    if backdrop == null:
        return
    var path: String = ""
    if kind == "title":
        path = "res://assets/ui/title_bg.png"
    elif kind == "home":
        path = "res://assets/ui/home_bg.png"
    elif kind == "arena":
        path = "res://assets/ui/title_arena_clean_v01.png"
    if path.is_empty():
        backdrop.visible = false
        return
    if ResourceLoader.exists(path):
        backdrop.texture = load(path)
    backdrop.visible = true

func play_transition(screen_name: String, _sfx: String = "") -> void:
    var first_page: bool = entered_screen.is_empty()
    entered_screen = screen_name
    if first_page or previous_screen == screen_name or previous_screen.is_empty():
        return
    var mode: String = "compose"
    if previous_screen in ["settings", "help", "continue"]:
        mode = "fade"
    elif screen_name in ["title", "start"]:
        mode = "page"
    page_turn(page_snapshot, mode)

func make_display(text: String, size: int = 36, color: Color = ink) -> Label:
    var result: Label = make_label(text, size, color)
    if display_font != null:
        result.add_theme_font_override("font", display_font)
    return result

func hairline(parent: Node, width: float = 400.0, color: Color = ink) -> ColorRect:
    var line: ColorRect = ColorRect.new()
    line.color = Color(color.r, color.g, color.b, 0.32)
    line.custom_minimum_size = Vector2(width, 2)
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(line)
    return line

func dim_overlay(in_world: bool = false, soft: bool = false) -> void:
    if soft:
        overlay.color = Color(0.08, 0.09, 0.08, 0.22)
    elif in_world:
        overlay.color = Color(0.08, 0.09, 0.08, 0.2)
    else:
        overlay.color = Color(0.13, 0.09, 0.06, 0.58)

func make_label(text: String, size: int = 18, color: Color = ink) -> Label:
    var result: Label = Label.new()
    result.text = text
    result.add_theme_font_size_override("font_size", size)
    result.add_theme_color_override("font_color", color)
    result.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return result

func make_button(text: String, color: Color = cream) -> Button:
    var result: Button = Button.new()
    result.text = text
    result.add_theme_stylebox_override("normal", style(color))
    result.add_theme_stylebox_override("hover", style(color.lightened(0.09), Color("#927a51")))
    result.add_theme_stylebox_override("pressed", style(color.darkened(0.06), ink))
    result.add_theme_stylebox_override("disabled", style(color.darkened(0.04),Color("#d0c5ae")))
    result.add_theme_color_override("font_color", ink)
    result.add_theme_color_override("font_hover_color", ink)
    result.add_theme_color_override("font_pressed_color", ink)
    result.add_theme_color_override("font_disabled_color",Color("#9d9380"))
    result.add_theme_font_size_override("font_size", 18)
    result.focus_mode = Control.FOCUS_NONE
    result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    result.custom_minimum_size.y = 42
    press_motion(result)
    return result


func offer_kind(key: String) -> String:
    if Catalog.WEAPONS.has(key):
        return "weapon"
    if Growth.BUFFS.has(key):
        return "support" if Growth.BUFFS[key]["category"] == "support" else "stat"
    return "supply"

func offer_badge(kind: String) -> String:
    match kind:
        "weapon":
            return "武器"
        "support":
            return "支援"
        "stat":
            return "属性"
        _:
            return "补给"

func offer_paper(kind: String) -> Color:
    match kind:
        "weapon":
            return Color("#f4e0b4")
        "support":
            return Color("#d3e6e7")
        "stat":
            return Color("#dce8c6")
        _:
            return Color("#e8d8b0")

func offer_ink(kind: String) -> Color:
    match kind:
        "weapon":
            return Color("#7a4a22")
        "support":
            return Color("#2f6568")
        "stat":
            return Color("#3f5a2c")
        _:
            return Color("#5f4a28")

func paint_offer_card(card: Button, kind: String) -> void:
    var paper: Color = offer_paper(kind)
    var border: Color = offer_ink(kind)
    var box: StyleBoxFlat = style(paper, border)
    box.set_border_width_all(3 if kind == "weapon" else 2)
    box.set_corner_radius_all(2)
    box.shadow_size = 1
    box.shadow_offset = Vector2(3, 4)
    var hover: StyleBoxFlat = box.duplicate()
    hover.bg_color = paper.lightened(0.08)
    var pressed: StyleBoxFlat = box.duplicate()
    pressed.bg_color = paper.darkened(0.06)
    var dead: StyleBoxFlat = box.duplicate()
    dead.bg_color = paper.darkened(0.04)
    dead.border_color = Color("#d0c5ae")
    card.add_theme_stylebox_override("normal", box)
    card.add_theme_stylebox_override("hover", hover)
    card.add_theme_stylebox_override("pressed", pressed)
    card.add_theme_stylebox_override("disabled", dead)

func make_badge(kind: String, size: int = 22) -> Label:
    var result: Label = make_label("「%s」" % offer_badge(kind), size, offer_ink(kind))
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result.custom_minimum_size = Vector2(108, 36)
    result.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var box: StyleBoxFlat = style(Color(0, 0, 0, 0), offer_ink(kind))
    box.shadow_size = 0
    box.set_border_width_all(2)
    box.set_corner_radius_all(2)
    box.content_margin_left = 8
    box.content_margin_right = 8
    box.content_margin_top = 2
    box.content_margin_bottom = 2
    result.add_theme_stylebox_override("normal", box)
    if display_font != null:
        result.add_theme_font_override("font", display_font)
    return result

func ticket_style(background: Color, border: Color, shape: String = "ticket") -> StyleBoxFlat:
    var box: StyleBoxFlat = style(background, border)
    box.set_border_width_all(3)
    box.shadow_size = 10
    box.content_margin_left = 18
    box.content_margin_right = 18
    box.content_margin_top = 10
    box.content_margin_bottom = 10
    match shape:
        "stamp":
            box.set_corner_radius_all(6)
        "clip":
            box.corner_radius_top_left = 4
            box.corner_radius_top_right = 12
            box.corner_radius_bottom_left = 10
            box.corner_radius_bottom_right = 5
        "seal":
            box.set_corner_radius_all(8)
        "tab":
            box.corner_radius_top_left = 10
            box.corner_radius_top_right = 10
            box.corner_radius_bottom_left = 4
            box.corner_radius_bottom_right = 4
        _:
            box.corner_radius_top_left = 6
            box.corner_radius_top_right = 12
            box.corner_radius_bottom_left = 12
            box.corner_radius_bottom_right = 6
    return box

func news_style(background: Color, border: Color = ink) -> StyleBoxFlat:
    var box: StyleBoxFlat = StyleBoxFlat.new()
    box.bg_color = background
    box.border_color = border
    box.set_border_width_all(2)
    box.set_corner_radius_all(2)
    box.content_margin_left = 16
    box.content_margin_right = 16
    box.content_margin_top = 10
    box.content_margin_bottom = 10
    box.shadow_size = 0
    return box

func style_ticket_button(button: Button, color: Color, shape: String = "ticket") -> void:
    if shape == "news":
        button.add_theme_stylebox_override("normal", news_style(color, ink))
        button.add_theme_stylebox_override("hover", news_style(color.lightened(0.08), stamp))
        button.add_theme_stylebox_override("pressed", news_style(color.darkened(0.06), ink))
        button.add_theme_stylebox_override("disabled", news_style(color.darkened(0.04), Color("#d0c5ae")))
        return
    button.add_theme_stylebox_override("normal", ticket_style(color, ink, shape))
    button.add_theme_stylebox_override("hover", ticket_style(color.lightened(0.09), Color("#927a51"), shape))
    button.add_theme_stylebox_override("pressed", ticket_style(color.darkened(0.06), ink, shape))
    button.add_theme_stylebox_override("disabled", ticket_style(color.darkened(0.04), Color("#d0c5ae"), shape))

func news_action_style(background: Color, border: Color, weight: String = "primary") -> StyleBoxFlat:
    var box: StyleBoxFlat = StyleBoxFlat.new()
    box.bg_color = background
    box.border_color = border
    box.shadow_size = 0
    box.set_corner_radius_all(0)
    match weight:
        "primary":
            box.set_border_width_all(2)
            box.content_margin_left = 22
            box.content_margin_right = 22
            box.content_margin_top = 12
            box.content_margin_bottom = 12
        "secondary":
            box.bg_color = Color(background.r, background.g, background.b, 0.92)
            box.set_border_width_all(2)
            box.content_margin_left = 18
            box.content_margin_right = 18
            box.content_margin_top = 10
            box.content_margin_bottom = 10
        _:
            box.bg_color = Color(0, 0, 0, 0)
            box.set_border_width_all(0)
            box.border_width_bottom = 1
            box.border_color = Color(ink.r, ink.g, ink.b, 0.4)
            box.content_margin_left = 10
            box.content_margin_right = 10
            box.content_margin_top = 8
            box.content_margin_bottom = 8
    return box

func style_news_action(button: Button, color: Color, weight: String = "primary") -> void:
    var border: Color = ink
    var hover_bg: Color = color.lightened(0.08) if weight != "ghost" else Color("#efe6d4")
    var pressed_bg: Color = color.darkened(0.06) if weight != "ghost" else Color("#e4d8c0")
    var dead_bg: Color = color.darkened(0.04) if weight != "ghost" else Color(0, 0, 0, 0)
    if weight == "ghost":
        border = Color(ink.r, ink.g, ink.b, 0.4)
    button.add_theme_stylebox_override("normal", news_action_style(color, border, weight))
    button.add_theme_stylebox_override("hover", news_action_style(hover_bg, stamp if weight != "ghost" else ink, weight))
    button.add_theme_stylebox_override("pressed", news_action_style(pressed_bg, ink, weight))
    button.add_theme_stylebox_override("disabled", news_action_style(dead_bg, Color("#d0c5ae"), weight))

func place_action(key: String, text: String, callback: Callable, color: Color, rect: Rect2, shape: String = "ticket", font_size: int = 18, parent: Node = null) -> Button:
    var button: Button = action(overlay if parent == null else parent, key, text, callback, color)
    button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    button.position = rect.position
    button.size = rect.size
    button.custom_minimum_size = rect.size
    button.add_theme_font_size_override("font_size", font_size)
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.clip_text = false
    button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    if shape in ["primary", "secondary", "ghost", "news"]:
        var weight: String = "secondary" if shape == "news" else shape
        style_news_action(button, color, weight)
        if display_font != null and weight == "primary":
            button.add_theme_font_override("font", display_font)
    else:
        style_ticket_button(button, color, shape)
    return button

func add_paper_shard(rect: Rect2, paper: Color, seed: int = 1, cut: String = "deckle") -> PaperShard:
    var shard: PaperShard = PaperShard.new()
    shard.position = rect.position
    shard.size = rect.size
    shard.paper = paper
    shard.ink_color = ink
    shard.seed = seed
    shard.cut = cut
    shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(shard)
    return shard

func add_paper_sheet(rect: Rect2, paper: Color, seed: int = 1, clip: bool = true, cut: String = "deckle") -> PaperShard:
    var back_rect: Rect2 = Rect2(rect.position + Vector2(-16, 18), rect.size + Vector2(18, -12))
    if cut == "ticket" or cut == "ticket_right":
        back_rect = Rect2(rect.position + Vector2(-10, 14), rect.size + Vector2(8, 10))
    elif cut == "tab":
        back_rect = Rect2(rect.position + Vector2(-18, 12), rect.size + Vector2(22, -20))
    var back: PaperShard = add_paper_shard(back_rect, paper.darkened(0.08), seed + 17, "scrap")
    back.modulate = Color(1, 1, 1, 0.88)
    var sheet: PaperShard = add_paper_shard(rect, paper, seed, cut)
    sheet.clip_contents = clip
    return sheet

func add_masthead_bar(parent: Control, width: float) -> Control:
    var bar: InkBanner = InkBanner.new()
    bar.fill = Color("#c0453a")
    bar.ink_color = ink
    bar.custom_minimum_size = Vector2(width, 10)
    bar.size = Vector2(width, 10)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(bar)
    return bar

func add_wax_seal(parent: Control, at: Vector2, text: String, diameter: float = 58.0) -> Label:
    var seal: Label = make_label(text, 13, Color("#f7e4c8"))
    seal.position = at
    seal.size = Vector2(diameter, diameter)
    seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    seal.clip_text = true
    seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var box: StyleBoxFlat = StyleBoxFlat.new()
    box.bg_color = Color("#c0453a")
    box.border_color = Color("#8d2f28")
    box.set_border_width_all(2)
    box.set_corner_radius_all(int(diameter * 0.5))
    box.shadow_color = Color(0.12, 0.05, 0.04, 0.28)
    box.shadow_size = 6
    box.shadow_offset = Vector2(1, 2)
    box.content_margin_left = 4
    box.content_margin_right = 4
    seal.add_theme_stylebox_override("normal", box)
    parent.add_child(seal)
    return seal

func fill_newsprint() -> void:
    overlay.color = Color("#f3ead8")
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP

func place_rule(at: Vector2, width: float, strength: float = 0.72, parent: Node = null) -> ColorRect:
    var line: ColorRect = ColorRect.new()
    line.color = Color(ink.r, ink.g, ink.b, strength)
    line.position = at
    line.size = Vector2(width, 2)
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    (overlay if parent == null else parent).add_child(line)
    return line

func place_copy(text: String, size: int, color: Color, rect: Rect2, display: bool = false, wrap: bool = false) -> Label:
    var host: Control = Control.new()
    host.position = rect.position
    host.size = rect.size
    host.custom_minimum_size = rect.size
    host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(host)
    var result: Label = make_display(text, size, color) if display else make_label(text, size, color)
    result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result.clip_text = false
    result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    result.size_flags_vertical = Control.SIZE_EXPAND_FILL
    if wrap:
        result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    host.add_child(result)
    return result

func add_stat_cell(at: Vector2, number: String, caption: String, width: float = 132.0) -> void:
    var value: Label = place_copy(number, 40, ink, Rect2(at, Vector2(width, 50)), true)
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    var label: Label = place_copy(caption, 14, Color("#6e6658"), Rect2(at + Vector2(0, 54), Vector2(width, 22)))
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func add_press_photo(rect: Rect2, path: String, caption: String, stamp_text: String) -> Control:
    var host: Control = Control.new()
    host.name = "PressPhoto"
    host.position = rect.position
    host.size = rect.size
    host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(host)
    var frame_h: float = maxf(80.0, rect.size.y - 28.0)
    var frame: Panel = Panel.new()
    frame.position = Vector2.ZERO
    frame.size = Vector2(rect.size.x, frame_h)
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var box: StyleBoxFlat = news_style(Color("#1f1a16"), ink)
    box.content_margin_left = 0
    box.content_margin_right = 0
    box.content_margin_top = 0
    box.content_margin_bottom = 0
    box.set_border_width_all(2)
    box.set_corner_radius_all(0)
    frame.add_theme_stylebox_override("panel", box)
    host.add_child(frame)
    var clip: Control = Control.new()
    clip.position = Vector2(3, 3)
    clip.size = Vector2(maxf(8.0, rect.size.x - 6.0), maxf(8.0, frame_h - 6.0))
    clip.clip_contents = true
    clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(clip)
    var photo: TextureRect = TextureRect.new()
    photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if ResourceLoader.exists(path):
        photo.texture = load(path)
    clip.add_child(photo)
    var mark: Label = make_stamp(stamp_text)
    mark.position = Vector2(rect.size.x - 100, frame_h - 52)
    mark.size = Vector2(84, 34)
    mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
    host.add_child(mark)
    var note: Label = make_label(caption, 14, Color("#6e6658"))
    note.position = Vector2(0, frame_h + 6)
    note.size = Vector2(rect.size.x, 22)
    note.clip_text = true
    note.mouse_filter = Control.MOUSE_FILTER_IGNORE
    host.add_child(note)
    return host

func add_masthead(at: Vector2, width: float, title: String, kicker: String, meta: String, woodcut: String = "") -> void:
    var row: HBoxContainer = HBoxContainer.new()
    row.position = at
    row.size = Vector2(width, 52)
    row.add_theme_constant_override("separation", 14)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(row)
    var name: Label = make_display(title, 36, ink)
    name.clip_text = false
    name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(name)
    var badge: Label = make_stamp(kicker)
    badge.custom_minimum_size = Vector2(72, 30)
    badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(badge)
    var spacer: Control = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(spacer)
    if not woodcut.is_empty() and ResourceLoader.exists(woodcut):
        var frame: Panel = Panel.new()
        frame.custom_minimum_size = Vector2(220, 46)
        frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var box: StyleBoxFlat = news_style(Color("#1f1a16"), ink)
        box.content_margin_left = 0
        box.content_margin_right = 0
        box.content_margin_top = 0
        box.content_margin_bottom = 0
        box.set_border_width_all(2)
        box.set_corner_radius_all(0)
        frame.add_theme_stylebox_override("panel", box)
        row.add_child(frame)
        var cut: TextureRect = TextureRect.new()
        cut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        cut.offset_left = 2
        cut.offset_top = 2
        cut.offset_right = -2
        cut.offset_bottom = -2
        cut.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        cut.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        cut.texture = load(woodcut)
        cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
        frame.add_child(cut)
    place_rule(at + Vector2(0, 58), width, 0.8)
    var line: Label = place_copy(meta, 14, Color("#6e6658"), Rect2(at + Vector2(0, 66), Vector2(width, 22)))
    line.clip_text = false

func add_padded_column(parent: Control, pad: float = 24.0, sep: int = 14) -> VBoxContainer:
    var column: VBoxContainer = VBoxContainer.new()
    column.position = Vector2(pad, pad)
    column.size = Vector2(maxf(40.0, parent.size.x - pad * 2.0), maxf(40.0, parent.size.y - pad * 2.0))
    column.add_theme_constant_override("separation", sep)
    parent.add_child(column)
    return column

func setup(asset_library) -> void:
    library = asset_library
    layer = 80
    process_mode = Node.PROCESS_MODE_ALWAYS
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var theme: Theme = Theme.new()
    body_font = GameFonts.create_system(PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"]))
    body_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
    display_font = GameFonts.create_system(PackedStringArray(["Microsoft YaHei", "SimHei", "Noto Sans CJK SC"]),800)
    display_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Noto Sans CJK SC"])
    display_font.font_weight = 800
    theme.default_font = body_font
    root.theme = theme
    add_child(root)
    BattleUI.build(self)
    battle_nodes = root.get_children().duplicate()
    hurt_flash_layer = HurtVignette.new()
    hurt_flash_layer.name = "HurtFlash"
    hurt_flash_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hurt_flash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hurt_flash_layer.z_index = 18
    root.add_child(hurt_flash_layer)
    refresh_debug_controls()
    backdrop = TextureRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(backdrop)
    overlay = ColorRect.new()
    overlay.color = Color(0.16, 0.12, 0.08, 0.46)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(overlay)
    var ink_veil = PageTransition.new()
    ink_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ink_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ink_veil.z_index = 20
    ink_veil.progress = 1.0
    root.add_child(ink_veil)
    veil = ink_veil
    preload_ui_sfx()
    show_title()

func update_state(hp: float, elapsed: float, kills: int, xp: float, xp_needed: int, inventory: Array, collapsed: bool, link: Dictionary, prefer_elite: bool, trial: bool) -> void:
    health_label.text = "%.1f / %.0f" % [maxf(0, hp), current_max_hp]
    if hp_bar != null:
        hp_bar.max_value = maxf(0.001, current_max_hp)
        hp_bar.value = maxf(0.0, hp)
        if last_hp >= 0.0 and not is_equal_approx(hp, last_hp):
            pulse(hp_bar)
            pulse(health_label)
        last_hp = hp
    score_label.text = "击败 %d" % kills
    if last_kills >= 0 and kills != last_kills:
        pulse(score_label)
    last_kills = kills
    var seconds: int = maxi(0, ceili(30.0 - fmod(elapsed, 30.0)))
    timer_label.text = "第 %d 关  %02d:%02d" % [floori(elapsed / 30.0) + 1, seconds / 60, seconds % 60]
    if formation_button != null:
        formation_button.text = "收束集火" if collapsed else "展开扫荡"
        KeyBindings.attach_to_button(formation_button, "scatter")
    if combo_button != null:
        combo_button.text = str(link["name"])
        KeyBindings.attach_to_button(combo_button, "link")
        combo_button.tooltip_text = link["cost"]
    if elite_button != null:
        elite_button.text = "射程内精英优先" if prefer_elite else "最近目标"
        KeyBindings.attach_to_button(elite_button, "aim")
    notice_label.text = ("试用：按 %s 自选成长" % KeyBindings.caption_for("growth_trial")) if trial else "绿石经验 · 金币用于营地"
    growth_button.visible = trial and screen == "combat" and not hud_hidden and not menu_hides_hud
    combo_label.text = str(link["summary"]).replace("\n", " · ")
    xp_bar.max_value = maxf(1.0, float(xp_needed))
    xp_bar.value = xp
    if xp_label != null:
        xp_label.text = "%.0f / %d" % [xp, xp_needed]
        if last_xp >= 0.0 and not is_equal_approx(xp, last_xp):
            pulse(xp_bar)
            pulse(xp_label)
        last_xp = xp
    for index in range(slots.size()):
        var slot: Dictionary = slots[index]
        if index < inventory.size():
            var item: Dictionary = inventory[index]
            slot["icon"].texture = library.weapon_texture(item["id"],item["level"])
            slot["name"].text = Catalog.WEAPONS[item["id"]]["name"]
            slot["name"].modulate = Color.WHITE
            var tag: String = ""
            if link["kind"] == "rune" and item["id"] == "staff":
                tag = " · 注能"
            elif str(link.get("kind", "")) in ["fire_enchant", "rune_enchant"] and item["id"] == str(link.get("reload_weapon", "")):
                tag = " · 附着"
            elif str(link.get("kind", "")) in ["fire_enchant", "rune_enchant", "rune"] and link.get("suppressed", []).has(item["id"]):
                tag = " · 附着"
            elif link["kind"] == "chain" and item["id"] == link["weapons"][1]:
                tag = " · 弹射"
            slot["level"].text = "Lv.%d" % item["level"] + (" · 觉醒" if item.level>=5 else (" · 进阶" if item.level>=3 else "")) + tag
        else:
            slot["icon"].texture = null
            slot["name"].text = "未装备"
            slot["name"].modulate = Color(1, 1, 1, 0.6)
            slot["level"].text = ""

func update_growth(levels: Dictionary, stats: Dictionary, _wave: int) -> void:
    current_max_hp = stats["max_hp"]
    var supports: int = int(levels.has("pet")) + int(levels.has("drone"))
    var names: Array = []
    for key in ["pet", "drone"]:
        if levels.has(key):
            names.append(("幼龙" if key == "pet" else "石灵") + " Lv.%d" % levels[key])
    growth_label.text = "Buff %d 项 · 支援 %d\n" % [levels.size(), supports] + (" / ".join(names) if not names.is_empty() else "升级可选宠物 / 飞行器")

func reset_overlay() -> void:
    if scroll_close_tween != null and scroll_close_tween.is_valid(): scroll_close_tween.kill()
    scroll_close_tween = null
    scroll_closing = false
    previous_screen = screen
    page_snapshot = snapshot_ui()
    choice_ids.clear()
    save_note_label = null
    autosave_toggle = null
    music_toggle = null
    for child in overlay.get_children():
        overlay.remove_child(child)
        child.queue_free()
    overlay.visible = true

func menu_column(width: float = 480.0, top: float = 220.0) -> VBoxContainer:
    var card: PanelContainer = PanelContainer.new()
    card.position = Vector2((1280.0 - width) / 2.0, top)
    card.size = Vector2(width, 0)
    var panel: StyleBoxFlat = news_style(Color("#f6ead0"), ink)
    panel.content_margin_left = 24
    panel.content_margin_right = 24
    panel.content_margin_top = 20
    panel.content_margin_bottom = 20
    card.add_theme_stylebox_override("panel", panel)
    overlay.add_child(card)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 15)
    card.add_child(column)
    pop_in(card, 0.0, 0.0)
    return column

func parchment_column(width: float, top: float) -> VBoxContainer:
    var frame = PaperUI.new()
    frame.name = "HanddrawnPaper"
    frame.set_meta("full_width", width)
    frame.position = Vector2((1280.0 - width) / 2.0, top)
    frame.size = Vector2(width, 80)
    overlay.add_child(frame)
    var column := VBoxContainer.new()
    column.position = Vector2(46, 28)
    column.size = Vector2(width - 64, 40)
    column.add_theme_constant_override("separation", 12)
    frame.content.add_child(column)
    column.set_meta("scroll_frame", frame)
    return column

func _column_body_height(column: VBoxContainer) -> float:
    var total: float = 0.0
    var sep: float = float(column.get_theme_constant("separation"))
    var first: bool = true
    for child in column.get_children():
        if child is Control and child.visible:
            var min_size: Vector2 = child.get_combined_minimum_size()
            var height: float = maxf(min_size.y, child.custom_minimum_size.y)
            if not first:
                total += sep
            first = false
            total += height
    return total

func open_parchment(column: VBoxContainer, animate: bool) -> void:
    if column == null or not column.has_meta("scroll_frame"):
        return
    _fit_parchment(column)
    # Children measured in the same tick they were created report inflated
    # minimum sizes (their font metrics have not settled yet), which made
    # panels open far taller than their content — the pause menu gained a
    # long blank tail that spilled over the battle HUD. Re-measure on the
    # next frame, once layout has settled, so the sheet hugs its content.
    call_deferred("_fit_parchment", column)
    var frame = column.get_meta("scroll_frame")
    if animate and can_animate():
        var span: float = 0.62 if frame.opening_mode == "scroll" else 0.34
        frame.reveal = 0.02
        lock_ui(span)
        play_ui("scroll_unroll" if frame.opening_mode == "scroll" else "paper_popup")
        var tw: Tween = create_tween()
        tw.tween_property(frame, "reveal", 1.0, span).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    else:
        frame.reveal = 1.0

func _fit_parchment(column: VBoxContainer) -> void:
    if column == null or not is_instance_valid(column) or not column.has_meta("scroll_frame"):
        return
    var frame = column.get_meta("scroll_frame")
    if frame == null or not is_instance_valid(frame):
        return
    var full_w: float = frame.get_meta("full_width", frame.size.x)
    column.position = Vector2(46, 28)
    column.custom_minimum_size.x = full_w - 92
    column.size = Vector2(full_w - 92, maxf(_column_body_height(column), 80))
    frame.size = Vector2(full_w, column.size.y + 56)
    # Never let the sheet run past the bottom of the 1280x800 canvas:
    # shift it up when it fits whole, so a menu cannot spill over the HUD.
    var max_top: float = 800.0 - 12.0 - frame.size.y
    if max_top >= 8.0:
        frame.position.y = minf(frame.position.y, max_top)

func _center_parchment_vertical(column: VBoxContainer) -> void:
    if column == null or not is_instance_valid(column) or not column.has_meta("scroll_frame"):
        return
    var frame = column.get_meta("scroll_frame")
    if frame == null or not is_instance_valid(frame):
        return
    var max_top: float = 800.0 - 12.0 - frame.size.y
    if max_top >= 8.0:
        frame.position.y = clampf((800.0 - frame.size.y) * 0.5, 8.0, max_top)

func action(parent: Node, key: String, text: String, callback: Callable, color: Color = cream) -> Button:
    var button: Button = make_button(text, color)
    button.name = key
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.pressed.connect(func():
        if not ui_busy():
            if key not in ["EnterCamp", "StartSling", "StartClub", "StartSpear", "ConfirmContinue", "Back", "CloseModal", "Settings", "HelpGameplay", "HelpKeys", "Stats", "Home", "NextRound"]:
                play_ui("button_press")
            if key in ["NextRound","Home"] and screen == "shop":
                close_scroll_then(callback)
            else:
                callback.call())
    parent.add_child(button)
    return button

func text_width(text: String, font_size: int, display: bool = false) -> float:
    var font: Font = display_font if display and display_font != null else body_font
    if font == null:
        return maxf(40.0, float(text.length()) * float(font_size) * 0.92)
    return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func add_stack_headline(at: Vector2, width: float, size: int = 72) -> Label:
    var line_h: float = size + 18.0
    var first: Label = place_copy("原始人", size, ink, Rect2(at, Vector2(width, line_h)), true)
    first.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    var second: Label = place_copy("大作战", size, ink, Rect2(at + Vector2(0, line_h + 4.0), Vector2(width, line_h)), true)
    second.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    return first

func add_cast_cutout(rect: Rect2) -> Control:
    var host: Control = Control.new()
    host.name = "CastPortrait"
    host.position = rect.position
    host.size = rect.size
    host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    host.clip_contents = false
    overlay.add_child(host)
    if library == null:
        return host
    var actor = ActorView.new()
    actor.setup(library)
    var marker: Node = actor.get_node_or_null("PlayerMarker")
    if marker != null and marker is CanvasItem:
        (marker as CanvasItem).visible = false
    actor.position = Vector2(rect.size.x * 0.52, rect.size.y * 0.70)
    actor.scale = Vector2.ONE * 2.6
    host.add_child(actor)
    return host

func confirm_cast(weapon_id: String = "") -> void:
    if launch_committed or ui_busy():
        return
    if not weapon_id.is_empty():
        selected_character = Catalog.character_id_for_weapon(weapon_id)
        preview_character = selected_character
    else:
        selected_character = displayed_character()
        preview_character = selected_character
    if not Catalog.can_start_character(selected_character, character_best_wave):
        return
    launch_committed = true
    var profile: Dictionary = Catalog.character(selected_character)
    var key: String = weapon_id if not weapon_id.is_empty() else str(profile.get("starting_weapon", "sling"))
    starter_selected.emit(key)
    start_requested.emit(false)

func clear_launch_commit() -> void:
    launch_committed = false

func place_link_row(items: Array, origin: Vector2, height: float = 42.0, gap: float = 16.0) -> void:
    var cursor: float = origin.x
    for item in items:
        var text: String = str(item[1])
        var font_size: int = 16
        var width: float = maxf(text_width(text, font_size) + 40.0, 120.0)
        width = minf(width, 1232.0 - cursor)
        if width < 40.0:
            break
        var button: Button = place_action(str(item[0]), text, item[2], item[3], Rect2(cursor, origin.y, width, height), "ghost", font_size)
        var fitted: float = maxf(width, button.get_combined_minimum_size().x + 8.0)
        fitted = minf(fitted, 1232.0 - cursor)
        button.position = Vector2(cursor, origin.y)
        button.size = Vector2(maxf(fitted, 40.0), height)
        button.custom_minimum_size = button.size
        cursor = button.position.x + button.size.x + gap

func show_title() -> void:
    reset_overlay()
    set_battle_visible(false)
    screen = "title"
    launch_committed = false
    FrontUI.title(self)
    play_transition("title", "ui_open")

func show_cast(sfx: String = "ui_open", keep_preview: bool = false) -> void:
    reset_overlay()
    set_battle_visible(false)
    screen = "cast"
    launch_committed = false
    if not keep_preview or preview_character.is_empty() or not Catalog.CHARACTERS.has(preview_character):
        preview_character = selected_character if Catalog.CHARACTERS.has(selected_character) else "caveman"
    FrontUI.cast(self)
    play_transition("cast", sfx)

func refresh_debug_controls() -> void:
    if root == null:
        return
    var trial: BaseButton = root.find_child("BattleTrial", true, false) as BaseButton
    if trial != null:
        var show_trial: bool = debug_cheats and not menu_hides_hud
        trial.visible = show_trial
        trial.disabled = not show_trial
        trial.mouse_filter = Control.MOUSE_FILTER_STOP if show_trial else Control.MOUSE_FILTER_IGNORE

func make_placed_stamp(at: Vector2, text: String) -> Label:
    var stamp_label: Label = make_stamp(text)
    stamp_label.position = at
    stamp_label.size = Vector2(88, 36)
    stamp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return stamp_label

func show_menu(kind: String, kills: int, sfx: String = "ui_open", summary: Dictionary = {}) -> void:
    menu_kills = kills
    if not summary.is_empty():
        menu_summary = summary.duplicate(true)
    if kind == "cast":
        show_cast(sfx)
        return
    if kind in ["start", "title"]:
        show_title()
        screen = kind
        return
    reset_overlay()
    set_battle_visible(kind == "pause")
    present_backdrop("none")
    overlay.color = Color(0.04, 0.08, 0.13, 0.64)
    screen = kind
    var column: VBoxContainer = parchment_column(650, 100)
    column.get_meta("scroll_frame").opening_mode = "fold"
    if kind in ["lose", "win"]:
        launch_committed = false
    column.add_theme_constant_override("separation", 12)
    var title: Label = make_display("已暂停" if kind == "pause" else ("再来一局" if kind == "lose" else "生存成功"), 36)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    var status: Label = make_label("本局击败 %d 只恐龙" % kills, 19, Color("#66705e"))
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(status)
    if kind in ["win", "lose"] and not menu_summary.is_empty():
        var seconds: int = maxi(0, int(floor(float(menu_summary.get("elapsed", 0.0)))))
        var loadout: PackedStringArray = PackedStringArray()
        for item in menu_summary.get("weapons", []):
            var key: String = str(item.get("id", ""))
            var weapon_title: String = str(Catalog.WEAPONS.get(key, {}).get("name", key))
            loadout.append("%s %s" % [weapon_title, Growth.weapon_level_text(int(item.get("level", 1)))])
        var loadout_text: String = "、".join(loadout) if loadout.size() > 0 else "无"
        var recap: Label = make_label("到达第 %d 关 · 用时 %02d:%02d · 等级 %d\n最终配装：%s" % [int(menu_summary.get("wave", 1)), seconds / 60, seconds % 60, int(menu_summary.get("level", 1)), loadout_text], 17, Color("#66705e"))
        recap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        recap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        recap.custom_minimum_size = Vector2(560, 48)
        column.add_child(recap)
    if kind == "pause":
        bind_shortcut(action(column, "Resume", "继续战斗", func(): pause_requested.emit()), "cancel")
        bind_shortcut(action(column, "SaveNow", "保存进度", func(): save_requested.emit()), "save")
        bind_shortcut(action(column, "Stats", "角色属性", func(): stats_requested.emit()), "stats")
        action(column, "HelpGameplay", "玩法说明", func(): show_help("gameplay", true))
        action(column, "Settings", "设置", func(): show_settings(true))
        action(column, "RestartRun", "重新开始本局", func(): show_restart_confirm())
        action(column, "Home", "返回首页", func(): home_requested.emit())
    else:
        var retry: Dictionary = Catalog.character(selected_character)
        bind_shortcut(action(column, "StartSling", "再出发 · " + str(retry.get("weapon_label", "弹弓")), func(): confirm_cast()), "confirm")
        action(column, "ChangeCharacter", "重新选择角色", func(): show_cast())
        action(column, "Home", "返回首页", func(): home_requested.emit())
    save_note_label = make_label(save_note, 16, Color("#66705e"))
    save_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(save_note_label)
    open_parchment(column, true)
    if kind in ["lose", "win"]:
        call_deferred("_center_parchment_vertical", column)

func show_choices(ids: Array, inventory: Array, levels: Dictionary = {}, reason: String = "xp", stage: int = 1, offer_levels: Dictionary = {}) -> void:
    reset_overlay()
    set_battle_visible(false)
    present_backdrop("none")
    dim_overlay(false,true)
    screen = "growth"
    choice_ids = ids.duplicate()
    choice_reason = reason
    choice_inventory = inventory.duplicate(true)
    choice_levels = levels.duplicate(true)
    choice_offer_levels = offer_levels.duplicate(true)
    choice_stage = stage
    OfferUI.growth(self,ids,inventory,levels,reason,offer_levels,stage)

func show_replace(pending: Dictionary, inventory: Array, stage: int = 1) -> void:
    replace_pending_view = pending.duplicate(true)
    replace_inventory_view = inventory.duplicate(true)
    replace_stage_view = stage
    replace_chosen = ""
    replace_confirm_dim = null
    replace_confirm_column = null
    reset_overlay()
    set_battle_visible(false)
    present_backdrop("none")
    dim_overlay(false,true)
    screen = "replace"
    choice_ids.clear()
    OfferUI.replace(self, pending, inventory, stage)

func _replace_outgoing(key: String) -> Dictionary:
    for item in replace_inventory_view:
        if str(item.get("id", "")) == key:
            return item
    return {"id": key, "level": 1}

func choose_replace_slot(key: String) -> void:
    if screen != "replace" or replace_pending_view.is_empty():
        return
    replace_chosen = key
    # The confirmation is a layer over the replace page: the six weapons stay
    # visible underneath (dimmed), exactly like the original shop confirm.
    replace_confirm_dim = ColorRect.new()
    replace_confirm_dim.name = "ReplaceConfirmDim"
    replace_confirm_dim.color = Color(0.04, 0.08, 0.13, 0.55)
    replace_confirm_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    replace_confirm_dim.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(replace_confirm_dim)
    screen = "replace_confirm"
    replace_confirm_column = OfferUI.replace_confirm(self, replace_pending_view, _replace_outgoing(key), replace_stage_view)
    if replace_confirm_column != null:
        replace_confirm_column.get_meta("scroll_frame").name = "ReplaceConfirmSheet"
        call_deferred("_center_parchment_vertical", replace_confirm_column)

func _close_replace_confirm_layer() -> void:
    if replace_confirm_column != null and is_instance_valid(replace_confirm_column):
        var frame = replace_confirm_column.get_meta("scroll_frame", null)
        if frame != null and is_instance_valid(frame):
            frame.queue_free()
    replace_confirm_column = null
    if replace_confirm_dim != null and is_instance_valid(replace_confirm_dim):
        replace_confirm_dim.queue_free()
    replace_confirm_dim = null
    replace_chosen = ""

func confirm_replace_choice() -> void:
    if screen == "replace_confirm" and not replace_chosen.is_empty():
        var chosen: String = replace_chosen
        replace_confirm_column = null
        replace_confirm_dim = null
        replace_chosen = ""
        replace_requested.emit(chosen)

func cancel_replace_confirm() -> void:
    if screen != "replace_confirm":
        return
    _close_replace_confirm_layer()
    screen = "replace"

func show_stats(levels: Dictionary, stats: Dictionary, difficulty: Dictionary = {}) -> void:
    reset_overlay()
    present_backdrop("none")
    dim_overlay(false)
    screen = "stats"
    var column: VBoxContainer = menu_column(1040, 64)
    column.add_theme_constant_override("separation", 12)
    var heading: Label = make_display("属性与 Buff · 战斗已暂停" if bool(difficulty.get("in_combat", false)) else "属性与 Buff", 28)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    var summary: Label = make_label("生命上限 %.0f    移速 %.0f    伤害 +%.0f%%    攻速 +%.0f%%\n暴击率 %.0f%%    暴击伤害 %.0f%%    减伤 %.0f%%    闪避 %.0f%%\n命中辅助 +%.0f    拾取范围 %.0f    经验 +%.0f%%    回复 %.2f/秒\n范围 +%.0f%%    穿透 +%d    弹射 +%d" % [stats["max_hp"], stats["speed"], (stats["damage_multiplier"] - 1) * 100, (stats["attack_speed"] - 1) * 100, stats["crit_chance"] * 100, stats["crit_multiplier"] * 100, stats["reduction"] * 100, stats["dodge"] * 100, stats["hit_radius"], stats["pickup_radius"], (stats["xp_multiplier"] - 1) * 100, stats["regen"], (stats["area_multiplier"] - 1) * 100, stats["pierce"], stats["ricochet"]], 18)
    summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(summary)
    if not difficulty.is_empty():
        var enemy: Dictionary = difficulty["enemy"]
        var difficulty_label: Label = make_label("第%d关 · 普通恐龙生命 %.1f / 伤害 %.2f / 闪避 %.1f%% · 适应倍率 ×%.2f" % [difficulty["wave"], enemy["hp"], enemy["damage"], enemy["dodge"] * 100, difficulty["adaptive"]], 16, Color("#9a4359"))
        difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        column.add_child(difficulty_label)
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(1008, 318)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    var grid: GridContainer = GridContainer.new()
    grid.columns = 2
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 16)
    grid.add_theme_constant_override("v_separation", 8)
    scroll.add_child(grid)
    for key in Growth.BUFFS:
        var data: Dictionary = Growth.BUFFS[key]
        var level: int = int(levels.get(key, 0))
        var entry: PanelContainer = PanelContainer.new()
        entry.custom_minimum_size = Vector2(484, 64)
        entry.add_theme_stylebox_override("panel", style(Color("#dce6cc") if level > 0 else Color("#eee4cb")))
        grid.add_child(entry)
        var label: Label = make_label(("已选  " if level > 0 else "可成长  ") + data["name"] + "  Lv.%d\n" % [level] + data["description"].split("\n")[0], 16, ink if level > 0 else Color("#8b806b"))
        entry.add_child(label)
    var legend: Label = make_label("%s 查看属性 · %s 保存    品红尖刺是敌方攻击    绿石给经验，金币用于营地购买" % [KeyBindings.caption_for("stats"), KeyBindings.caption_for("save")], 16, Color("#78674d"))
    legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(legend)
    var in_combat: bool = bool(difficulty.get("in_combat", false))
    var resume: Button = make_button("继续战斗" if in_combat else "返回", Color("#d1ddba"))
    resume.name = "Back"
    resume.pressed.connect(func(): stats_requested.emit())
    KeyBindings.attach_to_button(resume, "stats")
    column.add_child(resume)
    play_transition("stats", "ui_open")

func _choose(key: String) -> void:
    if ui_busy() or not choice_ids.has(key):
        return
    if can_animate():
        close_scroll_then(func():
            play_ui("choice_confirm")
            choice_selected.emit(key))
    else:
        choice_selected.emit(key)

func choose_index(index: int) -> void:
    if not ui_busy() and index >= 0 and index < choice_ids.size():
        _choose(choice_ids[index])

func _sell_reward(key: String) -> void:
    if ui_busy() or screen != "growth" or not choice_ids.has(key) or (not Catalog.WEAPONS.has(key) and not Growth.BUFFS.has(key)):
        return
    if can_animate():
        close_scroll_then(func():
            play_ui("choice_confirm")
            reward_sell_requested.emit(key))
    else:
        reward_sell_requested.emit(key)

func hide_menu() -> void:
    var closing: bool = screen in ["growth", "shop", "pause", "replace"]
    var previous: Texture2D = snapshot_ui() if closing else null
    overlay.visible = false
    present_backdrop("none")
    screen = "combat"
    choice_ids.clear()
    set_battle_visible(true)
    entered_screen = "combat"
    if closing:
        page_turn(previous, "fade", false)

func set_battle_visible(value: bool) -> void:
    menu_hides_hud = not value
    if not value:
        hud_hidden = false
    apply_battle_visibility()

func toggle_hud_hidden() -> void:
    if menu_hides_hud or ui_busy() or screen not in ["combat", ""]:
        return
    hud_hidden = not hud_hidden
    apply_battle_visibility()

func apply_battle_visibility() -> void:
    for node in battle_nodes:
        if node == null or not is_instance_valid(node):
            continue
        var vital: bool = bool(node.get_meta("vital_hud", false))
        if node == boss_bar or node == boss_label:
            if menu_hides_hud:
                node.visible = false
            continue
        if menu_hides_hud:
            node.visible = false
            continue
        if vital:
            node.visible = true
        else:
            node.visible = not hud_hidden
    if hide_ui_button != null and is_instance_valid(hide_ui_button):
        hide_ui_button.visible = not menu_hides_hud and not hud_hidden
        hide_ui_button.text = "隐藏界面"
        KeyBindings.attach_to_button(hide_ui_button, "hide_ui")
    refresh_debug_controls()

func configure_save(available: bool, autosave: bool, note: String = "", summary: Dictionary = {}) -> void:
    save_available = available
    autosave_enabled = autosave
    save_summary = summary.duplicate(true)
    if not note.is_empty():
        save_note = note
    elif not available:
        save_note = "尚无可继续的存档 · 开始一局后可保存"
    elif save_note.begins_with("尚无"):
        save_note = "可继续上次旅程"
    var resume: BaseButton = overlay.find_child("ContinueSave", true, false) as BaseButton
    if resume != null:
        resume.disabled = not available
        resume.tooltip_text = save_note
    var confirmation: BaseButton = overlay.find_child("ConfirmContinue", true, false) as BaseButton
    if confirmation != null:
        confirmation.disabled = not available
        var preview: Control = overlay.find_child("SavePreview", true, false) as Control
        if preview != null:
            preview.visible = available
    if is_instance_valid(save_note_label):
        save_note_label.text = save_note
        if screen == "continue":
            save_note_label.add_theme_color_override("font_color", Color("#af4833") if not available else ink)
    if overlay != null and not summary.is_empty():
        var coins_label: Label = overlay.find_child("SaveCoins", true, false) as Label
        if coins_label != null:
            coins_label.text = "金币 %d" % int(summary.get("coins", 0))
        var hp_label: Label = overlay.find_child("SaveHp", true, false) as Label
        if hp_label != null:
            var character_id: String = str(summary.get("character_id", Catalog.character_id_for_weapon(str(summary.get("starting_weapon", "sling")))))
            var max_hp: float = Catalog.apply_character_modifiers(Growth.stats(summary.get("buff_levels", {})), character_id)["max_hp"]
            hp_label.text = "生命 %.1f / %.1f" % [float(summary.get("player_hp", 8.0)), max_hp]
    if is_instance_valid(autosave_toggle):
        autosave_toggle.set_pressed_no_signal(autosave_enabled)
        autosave_toggle.text = "开启" if autosave_enabled else "关闭"

func update_round(stage: int, stage_time: float, is_boss: bool, coins: int, boss_hp: float = 0.0, boss_max: float = 0.0, boss_name: String = "") -> void:
    var remaining: int = maxi(0,ceili(30.0-stage_time))
    timer_label.text = "第 %d 关 · Boss不限时" % stage if is_boss else "第 %d 关  %02d:%02d" % [stage,remaining/60,remaining%60]
    var urgent: bool = not is_boss and remaining <= 10
    timer_label.add_theme_font_size_override("font_size",18 if urgent else 17)
    timer_label.add_theme_color_override("font_color",Color("#b2362b") if urgent else ink)
    if urgent:
        timer_label.text = "第 %d 关 · 最后 %d 秒" % [stage,remaining]
        if can_animate() and remaining<=5:
            timer_label.modulate = Color(1,0.76+0.24*absf(sin(stage_time*7)),0.76+0.24*absf(sin(stage_time*7)))
    else: timer_label.modulate = Color.WHITE
    coin_label.text = "金币 %d" % coins
    if last_coins >= 0 and coins != last_coins:
        pulse(coin_label)
    last_coins = coins
    var was_boss: bool = boss_bar.visible
    boss_bar.visible = not menu_hides_hud and is_boss and boss_max > 0.0
    boss_label.visible = boss_bar.visible
    boss_bar.max_value = maxf(0.001,boss_max)
    boss_bar.value = maxf(0.0,boss_hp)
    boss_label.text = "%s  ·  %.0f / %.0f" % ["首领" if boss_name.is_empty() else boss_name,maxf(0,boss_hp),boss_max]
    if boss_bar.visible and not was_boss:
        pop_in(boss_label, 0.0, 0.0)
        pop_in(boss_bar, 0.04, 0.0)

func show_help(page: String = "gameplay", in_run: bool = false) -> void:
    remember_modal_origin()
    reset_overlay()
    set_battle_visible(in_run)
    screen = "help"
    help_in_run = in_run
    pending_help_trial = ""
    FrontUI.help_page(self, page, in_run)

func request_help_trial(kind: String) -> void:
    if ui_busy():
        return
    pending_help_trial = kind
    remember_modal_origin()
    reset_overlay()
    set_battle_visible(help_in_run)
    screen = "help_confirm"
    FrontUI.help_trial_confirm(self, kind, help_in_run)

func confirm_help_trial() -> void:
    if ui_busy():
        return
    var kind: String = pending_help_trial
    pending_help_trial = ""
    show_help("gameplay", help_in_run)
    if kind == "new":
        new_trial_requested.emit()
    else:
        trial_requested.emit()

func cancel_help_trial() -> void:
    pending_help_trial = ""
    show_help("gameplay", help_in_run)

func show_restart_confirm() -> void:
    if ui_busy():
        return
    reset_overlay()
    set_battle_visible(true)
    present_backdrop("none")
    overlay.color = Color(0.04, 0.08, 0.13, 0.64)
    screen = "restart_confirm"
    var column: VBoxContainer = parchment_column(650, 160)
    column.get_meta("scroll_frame").opening_mode = "fold"
    column.add_theme_constant_override("separation", 14)
    var title: Label = make_display("重新开始本局", 32)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    var body: Label = make_label("将以当前角色从第 1 关重新出发。正式存档与试用存档互不覆盖；取消则返回暂停菜单。", 18, Color("#66705e"))
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.custom_minimum_size = Vector2(560, 72)
    column.add_child(body)
    bind_shortcut(action(column, "RestartConfirm", "确定重新开始", func(): restart_requested.emit()), "confirm")
    bind_shortcut(action(column, "RestartCancel", "取消", func(): cancel_restart()), "cancel")
    open_parchment(column, true)

func cancel_restart() -> void:
    show_menu("pause", menu_kills, "ui_back")
    play_ui("ui_open")

func confirm_restart() -> void:
    # Keyboard counterpart of the RestartConfirm button (Enter).
    if screen == "restart_confirm":
        restart_requested.emit()

func show_link_discovery(recipes: Array, owned: Array) -> void:
    link_discover_recipes = []
    link_discover_complete = []
    for recipe in recipes:
        if typeof(recipe) != TYPE_DICTIONARY:
            continue
        var copy: Dictionary = recipe.duplicate(true)
        link_discover_recipes.append(copy)
        if Catalog.recipe_complete(copy, owned):
            link_discover_complete.append(str(copy.get("id", "")))
    if link_discover_recipes.is_empty():
        return
    link_discover_over_shop = screen == "shop"
    _close_link_discovery_layer()
    if not link_discover_over_shop:
        reset_overlay()
        set_battle_visible(true)
        present_backdrop("none")
        overlay.color = Color(0.04, 0.08, 0.13, 0.64)
        overlay.visible = true
        overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    else:
        link_discover_dim = ColorRect.new()
        link_discover_dim.name = "LinkDiscoverDim"
        link_discover_dim.color = Color(0.04, 0.08, 0.13, 0.55)
        link_discover_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
        link_discover_dim.mouse_filter = Control.MOUSE_FILTER_STOP
        overlay.add_child(link_discover_dim)
    screen = "link_discover"
    var column: VBoxContainer = parchment_column(720, 80)
    link_discover_column = column
    column.get_meta("scroll_frame").name = "LinkDiscoverSheet"
    column.get_meta("scroll_frame").opening_mode = "fold"
    column.add_theme_constant_override("separation", 10)
    var title: Label = make_display("发现武器联动", 30)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    var intro: Label = make_label("这两件武器可以搭配使用。优点和缺点都写在下面。不会自动启用，需要你选择后才会生效。", 16, Color("#66705e"))
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    intro.custom_minimum_size = Vector2(620, 44)
    column.add_child(intro)
    for recipe in link_discover_recipes:
        var weapons: Array = recipe.get("weapons", [])
        var first: String = Catalog.weapon_name(str(weapons[0])) if weapons.size() > 0 else ""
        var second: String = Catalog.weapon_name(str(weapons[1])) if weapons.size() > 1 else ""
        var ready: bool = link_discover_complete.has(str(recipe.get("id", "")))
        var status: String = "现在可启用" if ready else ("还差%s" % (second if not owned.has(str(weapons[1])) else first))
        if not ready:
            var missing: PackedStringArray = PackedStringArray()
            for weapon_id in weapons:
                if not owned.has(str(weapon_id)):
                    missing.append(Catalog.weapon_name(str(weapon_id)))
            if not missing.is_empty():
                status = "还差%s" % "、".join(missing)
        var block: Label = make_label("%s + %s  →  %s\n优点：%s\n缺点：%s\n%s" % [first, second, str(recipe.get("name", "")), Catalog.benefit_text(recipe), Catalog.cost_text(recipe), status], 16, Color("#3a2a1c"))
        block.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        block.custom_minimum_size = Vector2(620, 92)
        column.add_child(block)
    if not link_discover_complete.is_empty():
        if link_discover_complete.size() == 1:
            var only: String = str(link_discover_complete[0])
            var name: String = str(Catalog.LINKS.get(only, {}).get("name", only))
            bind_shortcut(action(column, "LinkEnable", "启用·%s" % name, func(): _emit_link_enable(only), Color("#b4583e")), "confirm")
        else:
            for link_id in link_discover_complete:
                var name: String = str(Catalog.LINKS.get(link_id, {}).get("name", link_id))
                action(column, "LinkEnable_%s" % link_id, "启用·%s" % name, func(): _emit_link_enable(str(link_id)), Color("#b4583e"))
        bind_shortcut(action(column, "LinkDecline", "先不用", func(): cancel_link_discovery()), "cancel")
    else:
        bind_shortcut(action(column, "LinkDismiss", "知道了", func(): cancel_link_discovery()), "confirm")
    open_parchment(column, true)
    call_deferred("_center_parchment_vertical", column)

func link_discovery_recipes() -> Array:
    return link_discover_recipes.duplicate(true)

func _emit_link_enable(link_id: String) -> void:
    if screen != "link_discover":
        return
    link_discovery_enable.emit(link_id)

func confirm_link_discovery() -> void:
    if screen != "link_discover":
        return
    if link_discover_complete.size() == 1:
        _emit_link_enable(str(link_discover_complete[0]))
    else:
        cancel_link_discovery()

func cancel_link_discovery() -> void:
    if screen != "link_discover":
        return
    link_discovery_closed.emit()

func hide_link_discovery(keep_shop: bool = false) -> void:
    _close_link_discovery_layer()
    link_discover_recipes.clear()
    link_discover_complete.clear()
    if keep_shop or link_discover_over_shop:
        screen = "shop"
        link_discover_over_shop = false
        return
    link_discover_over_shop = false
    if screen == "link_discover":
        hide_menu()

func _close_link_discovery_layer() -> void:
    if link_discover_column != null and is_instance_valid(link_discover_column):
        var frame = link_discover_column.get_meta("scroll_frame", null)
        if frame != null and is_instance_valid(frame):
            frame.queue_free()
        elif is_instance_valid(link_discover_column):
            link_discover_column.queue_free()
    link_discover_column = null
    if link_discover_dim != null and is_instance_valid(link_discover_dim):
        link_discover_dim.queue_free()
    link_discover_dim = null

func shop_index_available(index: int) -> bool:
    # Mirrors the shop card's mouse disabled state (ui_offer_layout.shop):
    # sold out, unaffordable, or a heal at full HP cannot be picked.
    if shop_state.is_empty():
        return false
    var stock: Array = shop_state.get("stock", [])
    if index < 0 or index >= stock.size():
        return false
    var offer: Dictionary = stock[index]
    if bool(offer.get("sold", false)):
        return false
    if int(shop_state.get("coins", 0)) < int(offer.get("price", 0)):
        return false
    if str(offer.get("id", "")) == "heal" and float(shop_state.get("hp", 0.0)) >= float(shop_state.get("max_hp", 0.0)):
        return false
    return true

func show_settings(in_run: bool) -> void:
    if screen != "keybindings":
        remember_modal_origin()
    settings_in_run = in_run
    bind_listen_action = ""
    reset_overlay()
    set_battle_visible(in_run)
    screen = "settings"
    FrontUI.settings(self, in_run)
    play_ui("ui_open")

func show_shop(stock: Array, coins: int, finished_wave: int, inventory: Array, levels: Dictionary, hp: float, max_hp: float, animate: bool = true, highlight: int = -1, reroll_cost: int = -1) -> void:
    shop_state = {
        "stock": stock,
        "coins": coins,
        "wave": finished_wave,
        "inventory": inventory,
        "levels": levels,
        "hp": hp,
        "max_hp": max_hp,
        "reroll_cost": reroll_cost,
    }
    reset_overlay()
    set_battle_visible(false)
    present_backdrop("none")
    dim_overlay(false,true)
    screen = "shop"
    OfferUI.shop(self,stock,coins,finished_wave,inventory,levels,hp,max_hp,animate,highlight,reroll_cost)

func request_shop_buy(index: int) -> void:
    # One-click purchase: no confirmation sheet. The world validates the
    # offer again in buy_shop_item, and a full-loadout weapon purchase
    # still routes through the replace page, which is the confirmation.
    if ui_busy() or shop_state.is_empty():
        return
    var stock: Array = shop_state.get("stock", [])
    if index < 0 or index >= stock.size():
        return
    buy_requested.emit(index)


func stage_panel(parent: Node) -> void:
    if not can_animate():
        return
    var order: int = 0
    for child in parent.get_children():
        if not child is CanvasItem:
            continue
        child.modulate.a = 0.0
        var tween: Tween = create_tween()
        tween.tween_interval(0.07 + minf(order * 0.012, 0.14))
        tween.tween_property(child, "modulate:a", 1.0, 0.18)
        order += 1

func conceal_front_chrome() -> void:
    if overlay == null:
        return
    for child in overlay.get_children():
        if str(child.name) == "HanddrawnPaper":
            continue
        if child is CanvasItem:
            child.visible = false

func restore_front_chrome() -> void:
    if overlay == null:
        return
    for child in overlay.get_children():
        if child is CanvasItem:
            child.visible = true

func snapshot_departure_previous() -> Texture2D:
    conceal_front_chrome()
    return snapshot_ui()

func snapshot_ui() -> Texture2D:
    if not can_animate() or not is_inside_tree():
        return null
    var texture: Texture2D = get_viewport().get_texture()
    if texture == null or texture.get_width() < 2:
        return null
    var image: Image = texture.get_image()
    if image == null or image.is_empty():
        return null
    return ImageTexture.create_from_image(image)

func lock_ui(seconds: float) -> void:
    input_lock_until = maxi(input_lock_until, Time.get_ticks_msec() + int(seconds * 1000.0))

func ui_busy() -> bool:
    return scroll_closing or screen == "departure" or Time.get_ticks_msec() < input_lock_until or (veil != null and veil.active())

func page_turn(previous: Texture2D, effect: String = "compose", sound: bool = true) -> void:
    if veil == null:
        return
    veil.effect = effect
    if not can_animate():
        return
    var cue: String = {"burn":"parchment_burn", "page":"page_turn", "fade":"paper_close", "compose":"paper_popup"}.get(effect, "paper_popup")
    if sound:
        play_ui(cue)
    veil.play(previous, effect)

func remember_modal_origin() -> void:
    if screen not in ["settings", "help", "continue", "keybindings"]:
        front_return_screen = screen
        modal_snapshot = snapshot_ui()

func close_front_modal() -> void:
    var origin: String = front_return_screen
    modal_snapshot = null
    if origin == "cast":
        show_cast("ui_back")
    elif origin == "pause":
        show_menu("pause", menu_kills, "ui_back")
    else:
        show_title()

func show_continue() -> void:
    if not save_available:
        return
    remember_modal_origin()
    reset_overlay()
    set_battle_visible(false)
    screen = "continue"
    FrontUI.continued(self)
    play_ui("ui_open")

func displayed_character() -> String:
    var id: String = preview_character if not preview_character.is_empty() else selected_character
    return id if Catalog.CHARACTERS.has(id) else "caveman"

func change_character(direction: int) -> void:
    if ui_busy() or Catalog.CHARACTER_ORDER.size() <= 1:
        return
    var index: int = maxi(0, Catalog.CHARACTER_ORDER.find(displayed_character()))
    index = posmod(index + direction, Catalog.CHARACTER_ORDER.size())
    preview_character = Catalog.CHARACTER_ORDER[index]
    show_cast("ui_hover", true)

func commit_character(id: String = "") -> void:
    if ui_busy():
        return
    var chosen: String = id if not id.is_empty() else displayed_character()
    if not Catalog.CHARACTERS.has(chosen):
        chosen = "caveman"
    selected_character = chosen
    preview_character = chosen
    show_cast("ui_click", true)

func show_departure(seconds: float) -> void:
    reset_overlay()
    present_backdrop("none")
    set_battle_visible(true)
    screen = "departure"
    overlay.color = Color(0.04, 0.08, 0.13, 0.28)
    var paper = FrontUI.paper(self, Rect2(440, 225, 400, 310), false)
    FrontUI.label(self, paper.content, "整装出发", Rect2(50, 28, 300, 58), 37, ink, true)
    departure_label = FrontUI.label(self, paper.content, "3", Rect2(50, 93, 300, 126), 86, FrontUI.RED, true)
    departure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    FrontUI.label(self, paper.content, "准备好，迎战恐龙", Rect2(58, 245, 290, 34), 20)
    update_departure(seconds)

func update_departure(seconds: float) -> void:
    if is_instance_valid(departure_label):
        departure_label.text = str(maxi(1, ceili(seconds / 0.8)))

func handle_front_key(code: int) -> bool:
    if ui_busy():
        return true
    if screen == "keybindings":
        if KeyBindings.matches_code(code, "cancel"):
            show_settings(settings_in_run)
            return true
        return not bind_listen_action.is_empty()
    if screen in ["settings", "continue", "help"] and KeyBindings.matches_code(code, "cancel"):
        close_front_modal()
        return true
    if screen == "help_confirm":
        if KeyBindings.matches_code(code, "cancel"):
            cancel_help_trial()
            return true
        if KeyBindings.matches_code(code, "confirm"):
            confirm_help_trial()
            return true
    if screen == "restart_confirm":
        if KeyBindings.matches_code(code, "cancel"):
            cancel_restart()
            return true
        if KeyBindings.matches_code(code, "confirm"):
            confirm_restart()
            return true
    if screen == "link_discover":
        if KeyBindings.matches_code(code, "cancel"):
            cancel_link_discovery()
            return true
        if KeyBindings.matches_code(code, "confirm"):
            confirm_link_discovery()
            return true
        return true
    if screen == "cast":
        if code == KEY_LEFT or code == KEY_RIGHT:
            change_character(-1 if code == KEY_LEFT else 1)
            return true
        if KeyBindings.matches_code(code, "confirm"):
            confirm_cast()
            return true
        if KeyBindings.matches_code(code, "cancel"):
            show_title()
            return true
    elif screen in ["title", "start"] and KeyBindings.matches_code(code, "confirm"):
        show_cast()
        return true
    return false

func bind_shortcut(button: BaseButton, action: String) -> BaseButton:
    KeyBindings.attach_to_button(button, action)
    return button

func refresh_key_hints() -> void:
    KeyBindings.refresh_tree(root)
    KeyBindings.refresh_tree(overlay)

func show_key_bindings(in_run: bool) -> void:
    settings_in_run = in_run
    reset_overlay()
    set_battle_visible(in_run)
    screen = "keybindings"
    FrontUI.key_bindings_page(self, in_run)
    play_ui("ui_open")

func begin_bind_listen(action: String) -> void:
    if ui_busy() or not KeyBindings.ACTIONS.has(action):
        return
    bind_listen_action = action
    bind_status = "请按下新按键，Esc 取消本次改键"
    play_ui("button_press")
    _refresh_bind_page()

func reset_key_bindings() -> void:
    if ui_busy():
        return
    KeyBindings.reset_defaults()
    bind_listen_action = ""
    bind_status = "已恢复默认按键"
    key_bindings_changed.emit()
    refresh_key_hints()
    _refresh_bind_page()

func handle_bind_listen(code: int) -> void:
    if bind_listen_action.is_empty():
        return
    if code == KEY_ESCAPE:
        bind_listen_action = ""
        bind_status = "已取消改键"
        _refresh_bind_page()
        return
    var result: Dictionary = KeyBindings.set_binding(bind_listen_action, code)
    if not bool(result.get("ok", false)):
        bind_status = str(result.get("error", "请按其他键"))
        _refresh_bind_page()
        return
    bind_listen_action = ""
    bind_status = "已更新按键"
    key_bindings_changed.emit()
    refresh_key_hints()
    _refresh_bind_page()

func _refresh_bind_page() -> void:
    if screen != "keybindings":
        return
    var keep_in_run: bool = settings_in_run
    var keep_status: String = bind_status
    var keep_listen: String = bind_listen_action
    reset_overlay()
    set_battle_visible(keep_in_run)
    screen = "keybindings"
    FrontUI.key_bindings_page(self, keep_in_run)
    bind_status = keep_status
    bind_listen_action = keep_listen
    var status: Label = overlay.find_child("BindStatus", true, false) as Label
    if status != null:
        status.text = bind_status

func _bind_button_name(action: String) -> String:
    return str(KeyBindings.BIND_BUTTON.get(action, "Bind" + action.capitalize()))

class HurtVignette extends Control:
    var strength: float = 0.0:
        set(value):
            strength = value
            queue_redraw()

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _notification(what: int) -> void:
        if what == NOTIFICATION_RESIZED:
            queue_redraw()

    func _draw() -> void:
        if strength <= 0.01 or size.x < 8.0 or size.y < 8.0:
            return
        var band: float = 78.0
        var steps: int = 6
        for index in range(steps):
            var fade: float = 1.0 - float(index) / float(steps)
            var alpha: float = 0.28 * strength * fade * fade
            var color := Color(0.62, 0.10, 0.11, alpha)
            var t: float = band * float(index) / float(steps)
            var thick: float = band / float(steps) + 2.0
            draw_rect(Rect2(0, t, size.x, thick), color, true)
            draw_rect(Rect2(0, size.y - t - thick, size.x, thick), color, true)
            draw_rect(Rect2(t, 0, thick, size.y), color, true)
            draw_rect(Rect2(size.x - t - thick, 0, thick, size.y), color, true)

class ParchmentScroll extends Control:
    const SIDE: float = 24.0
    const CLOSED_WIDTH: float = 48.0
    var full_width: float = 0.0
    var unroll: float = 1.0:
        set(value):
            unroll = value
            queue_redraw()
    var parchment: Color = Color("#ead6a8")
    var ink_color: Color = Color("#2a221c")

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP

    func _notification(what: int) -> void:
        if what == NOTIFICATION_RESIZED:
            queue_redraw()

    func _draw() -> void:
        var area: Vector2 = size
        if area.x < 8.0 or area.y < 8.0:
            return
        var body: Rect2 = Rect2(8.0, 8.0, maxf(4.0, area.x - 16.0), maxf(4.0, area.y - 16.0))
        draw_rect(Rect2(body.position + Vector2(3, 5), body.size), Color(0.12, 0.08, 0.05, 0.16), true)
        draw_rect(body, parchment, true)
        var curl: Color = parchment.darkened(0.10)
        curl.a = 0.42
        var shine: Color = parchment.lightened(0.10)
        shine.a = 0.35
        draw_rect(Rect2(body.position, Vector2(9.0, body.size.y)), curl, true)
        draw_rect(Rect2(body.position + Vector2(9.0, 0.0), Vector2(5.0, body.size.y)), shine, true)
        var fold: float = lerpf(20.0, 10.0, clampf(unroll, 0.0, 1.0))
        draw_rect(Rect2(body.position.x + body.size.x - fold, body.position.y, fold, body.size.y), parchment.darkened(0.07), true)
        draw_rect(Rect2(body.position.x + body.size.x - 5.0, body.position.y, 5.0, body.size.y), Color(0.12, 0.08, 0.05, 0.10), true)
        draw_rect(Rect2(body.position + Vector2(14, 10), body.size - Vector2(28, 20)), Color(ink_color.r, ink_color.g, ink_color.b, 0.16), false, 1.1)
        draw_rect(body, ink_color, false, 2.0)


class InkBanner extends Control:
    var fill: Color = Color("#c0453a")
    var ink_color: Color = Color("#2a221c")
    var seed: int = 1

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _notification(what: int) -> void:
        if what == NOTIFICATION_RESIZED:
            queue_redraw()

    func _draw() -> void:
        var w: float = size.x
        var h: float = size.y
        if w < 8.0 or h < 3.0:
            return
        var tip: float = minf(16.0, w * 0.08)
        var pts: PackedVector2Array = PackedVector2Array()
        pts.append(Vector2(0.0, h * 0.22 + sin(float(seed)) * 1.2))
        for index in range(7):
            var x: float = lerpf(0.0, w - tip, float(index) / 6.0)
            var y: float = 0.6 + sin(float(seed + index) * 1.3) * 1.1
            pts.append(Vector2(x, y))
        pts.append(Vector2(w, h * 0.5))
        for index in range(6, -1, -1):
            var x: float = lerpf(0.0, w - tip, float(index) / 6.0)
            var y: float = h - 0.6 - sin(float(seed + index) * 1.05) * 1.1
            pts.append(Vector2(x, y))
        pts.append(Vector2(0.0, h * 0.82))
        draw_colored_polygon(pts, fill)
        var outline: PackedVector2Array = pts.duplicate()
        outline.append(pts[0])
        draw_polyline(outline, ink_color, 1.4, true)


class PaperShard extends Control:
    var paper: Color = Color("#f3ead4")
    var ink_color: Color = Color("#2a221c")
    var seed: int = 1
    var cut: String = "deckle"

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _notification(what: int) -> void:
        if what == NOTIFICATION_RESIZED:
            queue_redraw()

    func _chamfer() -> float:
        if cut == "fold":
            return minf(58.0, minf(size.x, size.y) * 0.14)
        if cut == "ticket":
            return minf(32.0, minf(size.x, size.y) * 0.10)
        if cut == "scrap":
            return minf(48.0, minf(size.x, size.y) * 0.20)
        return 0.0

    func _draw() -> void:
        var pts: PackedVector2Array = _points()
        if pts.size() < 3:
            return
        var shadow: PackedVector2Array = PackedVector2Array()
        var skew: Vector2 = Vector2(6, 8) if cut == "scrap" else Vector2(4, 5)
        for point in pts:
            shadow.append(point + skew)
        draw_colored_polygon(shadow, Color(0.12, 0.08, 0.05, 0.16))
        draw_colored_polygon(pts, paper)
        var outline: PackedVector2Array = pts.duplicate()
        outline.append(pts[0])
        draw_polyline(outline, ink_color, 2.4, true)
        var inner: PackedVector2Array = PackedVector2Array()
        var mid: Vector2 = size * 0.5
        for point in pts:
            inner.append(point.lerp(mid, 0.032))
        if inner.size() >= 2:
            inner.append(inner[0])
            draw_polyline(inner, Color(ink_color.r, ink_color.g, ink_color.b, 0.18), 1.2, true)
        _draw_fold()
        _draw_eyes()

    func _draw_fold() -> void:
        if cut != "fold" and cut != "scrap":
            return
        var w: float = size.x
        var h: float = size.y
        var chamfer: float = _chamfer()
        if chamfer < 8.0:
            return
        var a: Vector2 = Vector2(w - chamfer - 1.0, h - 6.0)
        var b: Vector2 = Vector2(w - 6.0, h - chamfer - 1.0)
        var inward: Vector2 = Vector2(w - chamfer * 0.62, h - chamfer * 0.62)
        draw_colored_polygon(PackedVector2Array([a, b, inward]), paper.darkened(0.10))
        draw_polyline(PackedVector2Array([a, inward, b]), ink_color, 1.8, true)
        draw_line(a, b, Color(ink_color.r, ink_color.g, ink_color.b, 0.55), 1.4, true)

    func _draw_eyes() -> void:
        if cut != "ticket" and cut != "ticket_right" and cut != "tab":
            return
        var spots: Array = []
        if cut == "ticket":
            spots = [Vector2(20.0, 22.0), Vector2(size.x - 20.0, 22.0)]
        elif cut == "ticket_right":
            spots = [Vector2(size.x - 20.0, 22.0), Vector2(size.x - 20.0, size.y - 22.0)]
        else:
            spots = [Vector2(22.0, 15.0)]
        for at in spots:
            draw_circle(at, 7.0, Color(ink_color.r, ink_color.g, ink_color.b, 0.9))
            draw_circle(at, 4.6, paper.darkened(0.16))
            draw_arc(at, 7.0, 0.0, TAU, 20, ink_color, 1.6, true)

    func _deckle_point(point: Vector2, normal: Vector2, edge_index: int, step: int) -> Vector2:
        var jag: float = sin(float(seed * 3 + edge_index * 7 + step * 2)) * 5.8
        jag += sin(float(seed * 5 + step * 3) * 0.73) * 3.2
        if step % 4 == 2:
            jag += 4.2 if (seed + edge_index) % 2 == 0 else -3.4
        if cut == "scrap":
            jag *= 1.15
        jag = clampf(jag, -6.0, 11.0)
        return point + normal * jag

    func _append_edge(pts: PackedVector2Array, a: Vector2, b: Vector2, edge_index: int, notched: bool = false) -> void:
        var delta: Vector2 = b - a
        var length: float = maxf(delta.length(), 1.0)
        var normal: Vector2 = delta.orthogonal().normalized()
        var notches: Array = [0.3, 0.7] if notched else []
        var radius: float = 11.0
        var steps: int = 9 if cut == "scrap" else 8
        var marks: Array = []
        for step in range(steps):
            marks.append(["point", float(step) / float(steps)])
        for fraction in notches:
            marks.append(["notch", float(fraction)])
        marks.sort_custom(func(left, right): return left[1] < right[1])
        var step_index: int = 0
        for mark in marks:
            var t: float = float(mark[1])
            if mark[0] == "notch":
                var center: Vector2 = a.lerp(b, t)
                var unit: Vector2 = delta / length
                var arc_steps: int = 7
                for arc in range(arc_steps + 1):
                    var angle: float = PI * float(arc) / float(arc_steps)
                    pts.append(center - unit * radius * cos(angle) + normal * radius * sin(angle))
                continue
            var near_notch: bool = false
            for fraction in notches:
                if absf(t - float(fraction)) < (radius + 1.6) / length:
                    near_notch = true
                    break
            if near_notch:
                continue
            pts.append(_deckle_point(a.lerp(b, t), normal, edge_index, step_index))
            step_index += 1

    func _points() -> PackedVector2Array:
        var w: float = size.x
        var h: float = size.y
        var margin: float = 5.0
        var chamfer: float = _chamfer()
        var tab_h: float = 18.0 if cut == "tab" else 0.0
        var tab_x: float = 40.0
        var tab_w: float = minf(132.0, w * 0.28)
        var top: float = margin + tab_h
        var tl: Vector2 = Vector2(margin, top)
        var tr: Vector2 = Vector2(w - margin, top)
        var br: Vector2 = Vector2(w - margin, h - margin)
        var bl: Vector2 = Vector2(margin, h - margin)
        if cut == "fold" or cut == "scrap":
            br = Vector2(w - margin, h - margin - chamfer)
        elif cut == "ticket":
            tr = Vector2(w - margin - chamfer, top)
        var pts: PackedVector2Array = PackedVector2Array()
        if cut == "tab":
            var tab_left: Vector2 = Vector2(tab_x, top)
            var tab_top_l: Vector2 = Vector2(tab_x + 8.0, margin)
            var tab_top_r: Vector2 = Vector2(tab_x + tab_w - 8.0, margin)
            var tab_right: Vector2 = Vector2(tab_x + tab_w, top)
            _append_edge(pts, tl, tab_left, 0)
            _append_edge(pts, tab_left, tab_top_l, 4)
            _append_edge(pts, tab_top_l, tab_top_r, 5)
            _append_edge(pts, tab_top_r, tab_right, 6)
            _append_edge(pts, tab_right, tr, 0)
        else:
            _append_edge(pts, tl, tr, 0)
        if cut == "ticket":
            var tr_down: Vector2 = Vector2(w - margin, top + chamfer)
            _append_edge(pts, tr, tr_down, 7)
            _append_edge(pts, tr_down, br, 1, true)
        else:
            var right_end: Vector2 = br
            _append_edge(pts, tr, right_end, 1, cut == "ticket_right")
        if cut == "fold" or cut == "scrap":
            var br_cut: Vector2 = Vector2(w - margin - chamfer, h - margin)
            _append_edge(pts, br, br_cut, 8)
            _append_edge(pts, br_cut, bl, 2)
        else:
            _append_edge(pts, br, bl, 2)
        _append_edge(pts, bl, tl, 3, cut == "ticket")
        return pts



func configure_music(enabled: bool) -> void:
    music_enabled = enabled
    if is_instance_valid(music_toggle):
        music_toggle.set_pressed_no_signal(enabled)
        music_toggle.text = "开启" if enabled else "关闭"

func configure_volumes(music_value: float, sfx_value: float) -> void:
    music_volume = clampf(music_value, 0.0, 1.0)
    sfx_volume = clampf(sfx_value, 0.0, 1.0)
    if ui_audio != null:
        ui_audio.set_volume(sfx_volume)
    var music_slider: Slider = overlay.find_child("MusicVolume", true, false) as Slider if overlay != null else null
    var sfx_slider: Slider = overlay.find_child("SfxVolume", true, false) as Slider if overlay != null else null
    if music_slider != null:
        music_slider.set_value_no_signal(music_volume)
    if sfx_slider != null:
        sfx_slider.set_value_no_signal(sfx_volume)
    var music_value_label: Label = overlay.find_child("MusicVolumeValue", true, false) as Label if overlay != null else null
    var sfx_value_label: Label = overlay.find_child("SfxVolumeValue", true, false) as Label if overlay != null else null
    if music_value_label != null:
        music_value_label.text = volume_percent(music_volume)
    if sfx_value_label != null:
        sfx_value_label.text = volume_percent(sfx_volume)

func volume_percent(value: float) -> String:
    return "%d%%" % int(round(clampf(value, 0.0, 1.0) * 100.0))

func configure_display(show_numbers: bool, fullscreen: bool) -> void:
    damage_numbers_enabled = show_numbers
    fullscreen_enabled = fullscreen
    if overlay == null:
        return
    var numbers: BaseButton = overlay.find_child("DamageNumbers", true, false) as BaseButton
    if numbers != null:
        numbers.set_pressed_no_signal(damage_numbers_enabled)
        numbers.text = "开启" if damage_numbers_enabled else "关闭"
    var mode: BaseButton = overlay.find_child("FullscreenMode", true, false) as BaseButton
    if mode != null:
        mode.set_pressed_no_signal(fullscreen_enabled)
        mode.text = "全屏" if fullscreen_enabled else "窗口"

func set_hurt_flash(amount: float) -> void:
    if hurt_flash_layer == null or not is_instance_valid(hurt_flash_layer):
        return
    hurt_flash_layer.visible = amount > 0.01
    hurt_flash_layer.set("strength", clampf(amount, 0.0, 1.0))
    if hurt_flash_layer.has_method("queue_redraw"):
        hurt_flash_layer.queue_redraw()

func update_world_status(map_name: String, dodge_cooldown: float, dodge_total: float, links: Array, link_hint: String = "") -> void:
    map_label.text = map_name + " · 向四周自由探索"
    dodge_label.text = "就绪" if dodge_cooldown <= 0 else "%.1fs" % dodge_cooldown
    dodge_bar.value = 1 - clampf(dodge_cooldown / maxf(0.01,dodge_total),0,1)
    if combo_button != null and combo_button.text.begins_with("不联动"):
        combo_button.text = "联动可用" if links.size() > 1 else "等待配方"
        KeyBindings.attach_to_button(combo_button, "link")
    if links.size() <= 1:
        if combo_button != null:
            combo_button.tooltip_text = "获得可搭配的武器时会提示联动与优缺点。集齐后按 %s 切换，不会自动开启。" % KeyBindings.caption_for("link")
        # When the player already holds one half of a recipe, main passes a
        # hint naming the missing piece instead of the generic recipe list.
        combo_label.text = link_hint if link_hint != "" else ("获得可搭配的武器时会提示联动与优缺点。集齐后按 %s 切换。" % KeyBindings.caption_for("link"))
    elif link_hint != "":
        combo_label.text = link_hint

func close_scroll_then(callback: Callable) -> void:
    if scroll_closing: return
    var frame = overlay.find_child("HanddrawnPaper",true,false)
    if not can_animate() or frame == null or frame.opening_mode != "scroll":
        callback.call()
        return
    var origin: String = screen
    screen = origin + "_closing"
    scroll_closing = true
    lock_ui(0.38)
    play_ui("paper_close")
    scroll_close_tween = create_tween()
    scroll_close_tween.tween_property(frame,"reveal",0.015,0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    scroll_close_tween.tween_callback(func():
        scroll_closing = false
        scroll_close_tween = null
        callback.call()
        if screen == origin + "_closing" and overlay.visible:
            screen = origin
            frame.reveal = 1.0)
