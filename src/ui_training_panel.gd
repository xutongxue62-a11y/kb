extends Control
## Training Camp configuration panel: freely equip/level any weapon (Lv.1-7),
## stack any Buff, spawn test monsters/elites/Boss, and open Q-link pack.

const Catalog = preload("res://src/catalog.gd")
const Growth = preload("res://src/growth.gd")
const GameFonts = preload("res://src/game_fonts.gd")
const UiFrontend = preload("res://src/ui_frontend.gd")
const TornCard = preload("res://src/ui_torn_card.gd")
const KeyBindings = preload("res://src/key_bindings.gd")

signal closed
signal exit_training_requested
signal open_links_requested

var host
var body_font: Font
var sheet: Panel
var status_label: Label
var god_btn: Button
var immortal_btn: Button
var wave_btns: Dictionary = {}
var weapon_labels: Dictionary = {}
var buff_labels: Dictionary = {}

const PANEL_SIZE := Vector2(1140, 744)
const PAPER_BG := Color("#f2e6cb")
const PAPER_ALT := Color("#e8d8b5")
const INK := Color("#362619")
const MUTED := Color("#6b5640")
const ACCENT := Color("#b45036")
const TEAL := Color("#2e6f6b")

func setup(world) -> void:
    host = world
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_preset(Control.PRESET_FULL_RECT)
    body_font = GameFonts.create_system(PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"]))
    _build()
    refresh()

func _style(bg: Color, border: Color = Color("#8f6f4c"), bw: int = 2, radius: int = 4) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = bg
    box.border_color = border
    box.set_border_width_all(bw)
    box.set_corner_radius_all(radius)
    return box

func _lbl(text: String, size: int = 15, color: Color = INK, bold: bool = false) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_override("font", body_font)
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    if bold:
        l.add_theme_constant_override("outline_size", 1)
        l.add_theme_color_override("font_outline_color", Color(color.r, color.g, color.b, 0.22))
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _btn(text: String, rect: Rect2, cb: Callable, bg: Color = Color("#faf1dc"), text_col: Color = INK, font_sz: int = 14) -> Button:
    var b := Button.new()
    b.text = text
    b.position = rect.position
    b.size = rect.size
    b.pivot_offset = rect.size * 0.5
    b.focus_mode = Control.FOCUS_NONE
    b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    b.add_theme_font_override("font", body_font)
    b.add_theme_font_size_override("font_size", font_sz)
    b.add_theme_color_override("font_color", text_col)
    b.add_theme_color_override("font_hover_color", text_col)
    b.add_theme_color_override("font_pressed_color", text_col)
    b.add_theme_stylebox_override("normal", UiFrontend.action_style(bg, Color("#49392c", 0.72)))
    b.add_theme_stylebox_override("hover", UiFrontend.action_style(bg.lightened(0.08), Color("#b45036")))
    b.add_theme_stylebox_override("pressed", UiFrontend.action_style(bg.darkened(0.08), Color("#362619")))
    b.pressed.connect(func():
        if host != null and host.hud != null and host.hud.has_method("play_ui"):
            host.hud.play_ui("button_press")
        cb.call()
    )
    if host != null and host.hud != null and host.hud.has_method("press_motion"):
        host.hud.press_motion(b)
    return b

func set_notice(text: String) -> void:
    if status_label != null:
        status_label.text = text

func _build() -> void:
    var dim := ColorRect.new()
    dim.color = Color(0.08, 0.06, 0.04, 0.56)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.offset_left = -800
    dim.offset_top = -400
    dim.offset_right = 800
    dim.offset_bottom = 400
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dim)

    sheet = Panel.new()
    sheet.name = "TrainingSheet"
    sheet.size = PANEL_SIZE
    sheet.position = Vector2((1280.0 - PANEL_SIZE.x) * 0.5, (800.0 - PANEL_SIZE.y) * 0.5)
    TornCard.apply(sheet, PAPER_BG, Color("#5b4027"), 11, 5.2, 1.8, Vector4.ZERO, true)
    add_child(sheet)

    var title := _lbl("训练营 · 自由配装与测试台", 26, INK, true)
    title.position = Vector2(24, 14)
    sheet.add_child(title)

    var touch_ui: bool = KeyBindings.is_touch_platform()
    status_label = _lbl("不计入正式存档 · 点击右上「训练台」开关本面板 · 点击武器栏拖拽联动" if touch_ui else "不计入正式存档 · 按 T 随时开关本面板 · 按 Q 拖拽武器联动", 14, MUTED)
    status_label.position = Vector2(360, 22)
    sheet.add_child(status_label)

    sheet.add_child(_btn("×", Rect2(PANEL_SIZE.x - 52, 10, 38, 34), func(): closed.emit(), Color("#e8d3b0"), INK, 20))

    # Left section: Weapons (14 items in 2 columns)
    var w_hdr := _lbl("武器配置（最多 6 件 · Lv.1~10）", 17, ACCENT, true)
    w_hdr.position = Vector2(24, 58)
    sheet.add_child(w_hdr)
    sheet.add_child(_btn("已装备全升5级", Rect2(278, 54, 122, 28), func(): _set_all_weapons_level(5), Color("#f6e4bd"), INK, 13))
    sheet.add_child(_btn("去配联动" if touch_ui else "去Q配联动", Rect2(408, 54, 98, 28), func(): open_links_requested.emit(), Color("#dceee9"), TEAL, 13))

    var w_bg := Panel.new()
    w_bg.position = Vector2(20, 88)
    w_bg.size = Vector2(510, 514)
    TornCard.apply(w_bg, PAPER_ALT, Color("#967852"), 23, 3.4, 1.2)
    sheet.add_child(w_bg)

    for i in range(Catalog.IDS.size()):
        var key: String = Catalog.IDS[i]
        var col: int = i % 2
        var row: int = i / 2
        var x: float = 10.0 + float(col) * 248.0
        var y: float = 10.0 + float(row) * 70.0
        var cell := Panel.new()
        cell.position = Vector2(x, y)
        cell.size = Vector2(240, 62)
        TornCard.apply(cell, Color("#faf1da"), Color("#9e805a"), 41 + i * 7, 2.4, 1.15)
        w_bg.add_child(cell)
        var lbl := _lbl("", 14, INK, true)
        lbl.position = Vector2(8, 6)
        lbl.size = Vector2(224, 22)
        cell.add_child(lbl)
        weapon_labels[key] = lbl
        cell.add_child(_btn("-", Rect2(8, 30, 34, 26), func(): _adjust_weapon(key, -1), Color("#eed8bc"), INK, 15))
        cell.add_child(_btn("+", Rect2(46, 30, 34, 26), func(): _adjust_weapon(key, 1), Color("#e2ebd4"), INK, 15))
        cell.add_child(_btn("Lv3", Rect2(86, 30, 44, 26), func(): _set_weapon_exact(key, 3), Color("#f4e4bd"), INK, 12))
        cell.add_child(_btn("Lv5", Rect2(134, 30, 44, 26), func(): _set_weapon_exact(key, 5), Color("#f2d4b0"), ACCENT, 12))
        cell.add_child(_btn("卸", Rect2(182, 30, 48, 26), func(): _set_weapon_exact(key, 0), Color("#ecd2c8"), Color("#8c3024"), 12))

    # Right section: Buffs (16 items in 2 columns)
    var b_hdr := _lbl("Buff 自由叠层", 17, TEAL, true)
    b_hdr.position = Vector2(548, 58)
    sheet.add_child(b_hdr)
    sheet.add_child(_btn("全部清零", Rect2(954, 54, 118, 28), func(): _clear_all_buffs(), Color("#ecd2c8"), Color("#8c3024"), 13))

    var b_bg := Panel.new()
    b_bg.position = Vector2(544, 88)
    b_bg.size = Vector2(576, 514)
    TornCard.apply(b_bg, PAPER_ALT, Color("#967852"), 31, 3.4, 1.2)
    sheet.add_child(b_bg)

    var buff_keys: Array = Growth.BUFFS.keys()
    for i in range(buff_keys.size()):
        var key: String = str(buff_keys[i])
        var col: int = i % 2
        var row: int = i / 2
        var x: float = 10.0 + float(col) * 280.0
        var y: float = 10.0 + float(row) * 62.0
        var cell := Panel.new()
        cell.position = Vector2(x, y)
        cell.size = Vector2(272, 54)
        TornCard.apply(cell, Color("#faf1da"), Color("#9e805a"), 137 + i * 7, 2.4, 1.15)
        b_bg.add_child(cell)
        var lbl := _lbl("", 14, INK, true)
        lbl.position = Vector2(8, 14)
        lbl.size = Vector2(138, 24)
        cell.add_child(lbl)
        buff_labels[key] = lbl
        cell.add_child(_btn("-", Rect2(146, 12, 34, 30), func(): _adjust_buff(key, -1), Color("#eed8bc"), INK, 15))
        cell.add_child(_btn("+1", Rect2(184, 12, 38, 30), func(): _adjust_buff(key, 1), Color("#e2ebd4"), INK, 13))
        cell.add_child(_btn("+5", Rect2(226, 12, 38, 30), func(): _adjust_buff(key, 5), Color("#f4e4bd"), ACCENT, 13))

    # Monster tier & immortality row (Wave 1 / 10 / 20 / 30 / 10万血沙袋 + 怪物不死锁血)
    var ry: float = 612.0
    var tier_lbl := _lbl("怪物强度：", 15, INK, true)
    tier_lbl.position = Vector2(22, ry + 7)
    sheet.add_child(tier_lbl)
    var presets: Array = [[1, "第1关"], [10, "第10关"], [20, "第20关"], [30, "第30关"], [0, "10万血沙袋"]]
    var rx: float = 104.0
    for pr in presets:
        var wv: int = int(pr[0])
        var label_txt: String = str(pr[1])
        var bw: float = 108.0 if wv == 0 else 80.0
        var wb := _btn(label_txt, Rect2(rx, ry, bw, 34), func(): _set_enemy_wave(wv), Color("#f6e4bd"), INK, 13)
        sheet.add_child(wb)
        wave_btns[wv] = wb
        rx += bw + 8.0
    immortal_btn = _btn("怪物锁血：关闭", Rect2(rx + 14.0, ry, 142, 34), func(): _toggle_enemy_immortal(), Color("#e8dfc8"), INK, 13)
    sheet.add_child(immortal_btn)
    var tip_lbl := _lbl("（开启锁血后怪物剩1血不死，仍正常显示伤害与特效）", 13, MUTED)
    tip_lbl.position = Vector2(rx + 166.0, ry + 8)
    sheet.add_child(tip_lbl)

    # Bottom bar: Monster Spawning & Controls
    var by: float = 656.0
    sheet.add_child(_btn("刷普通怪×10", Rect2(20, by, 124, 42), func(): _spawn_pack("mixed", 10), Color("#f6e4bd"), INK, 14))
    sheet.add_child(_btn("刷重甲/远程×6", Rect2(152, by, 136, 42), func(): _spawn_pack("heavy_ranged", 6), Color("#f4d6c4"), INK, 14))
    sheet.add_child(_btn("刷精英怪", Rect2(296, by, 98, 42), func(): _spawn_pack("elite", 1), Color("#f2c8b0"), ACCENT, 14))
    sheet.add_child(_btn("刷 Boss", Rect2(402, by, 92, 42), func(): _spawn_pack("boss", 1), Color("#e8b0a0"), Color("#781c14"), 14))
    sheet.add_child(_btn("清空怪物", Rect2(502, by, 98, 42), func(): _clear_enemies(), Color("#e8dfc8"), INK, 14))
    god_btn = _btn("玩家无敌：开", Rect2(608, by, 122, 42), func(): _toggle_godmode(), Color("#d8ecd8"), Color("#24582c"), 14)
    sheet.add_child(god_btn)
    sheet.add_child(_btn("退出训练营", Rect2(838, by, 126, 42), func(): exit_training_requested.emit(), Color("#ecd2c8"), Color("#8c3024"), 15))
    sheet.add_child(_btn("开始测试 [T]", Rect2(972, by, 148, 42), func(): closed.emit(), ACCENT, Color("#fff7e8"), 16))

func refresh() -> void:
    if host == null:
        return
    for key in weapon_labels:
        var lvl: int = host.weapon_level(key)
        var lbl: Label = weapon_labels[key]
        var wname: String = Catalog.weapon_name(key)
        if lvl > 0:
            var tag: String = "觉醒" if lvl >= 5 else ("进阶" if lvl >= 3 else "")
            lbl.text = "%s · Lv.%d%s" % [wname, lvl, (" " + tag) if not tag.is_empty() else ""]
            lbl.add_theme_color_override("font_color", ACCENT if lvl >= 5 else TEAL)
        else:
            lbl.text = "%s · 未装备" % wname
            lbl.add_theme_color_override("font_color", MUTED)
    for key in buff_labels:
        var lvl: int = int(host.buff_levels.get(key, 0))
        var lbl: Label = buff_labels[key]
        var bname: String = str(Growth.BUFFS[key]["name"])
        lbl.text = "%s ×%d" % [bname, lvl]
        lbl.add_theme_color_override("font_color", TEAL if lvl > 0 else INK)
    if god_btn != null:
        var gm: bool = bool(host.training_godmode)
        god_btn.text = "玩家无敌：开" if gm else "玩家无敌：关"
        _paint_toggle_btn(god_btn, gm)
    if immortal_btn != null:
        var imm: bool = bool(host.training_enemy_immortal)
        immortal_btn.text = "怪物锁血：开启" if imm else "怪物锁血：关闭"
        _paint_toggle_btn(immortal_btn, imm)
    var cur_wave: int = int(host.training_enemy_wave)
    for wv in wave_btns:
        var wb: Button = wave_btns[wv]
        var active: bool = int(wv) == cur_wave
        _paint_toggle_btn(wb, active)

func _paint_toggle_btn(b: Button, active: bool) -> void:
    var bg: Color = ACCENT if active else Color("#f6e4bd")
    var fg: Color = Color("#fff7e8") if active else INK
    var bd: Color = Color("#5c2414") if active else Color("#49392c", 0.72)
    b.add_theme_stylebox_override("normal", UiFrontend.action_style(bg, bd))
    b.add_theme_stylebox_override("hover", UiFrontend.action_style(bg.lightened(0.08), Color("#5c2414") if active else ACCENT))
    b.add_theme_stylebox_override("pressed", UiFrontend.action_style(bg.darkened(0.08), INK))
    b.add_theme_color_override("font_color", fg)
    b.add_theme_color_override("font_hover_color", fg)
    b.add_theme_color_override("font_pressed_color", fg)

func _adjust_weapon(key: String, delta_lvl: int) -> void:
    if host == null:
        return
    var cur: int = host.weapon_level(key)
    _set_weapon_exact(key, clampi(cur + delta_lvl, 0, Growth.MAX_WEAPON_LEVEL))

func _set_weapon_exact(key: String, target_lvl: int) -> void:
    if host == null:
        return
    var cur: int = host.weapon_level(key)
    if target_lvl <= 0:
        if cur > 0:
            host.training_remove_weapon(key)
            status_label.text = "已卸下「%s」" % Catalog.weapon_name(key)
    else:
        if cur <= 0 and host.inventory.size() >= 6:
            status_label.text = "武器栏已满（6/6），请先点「卸」腾出一个槽位"
            return
        host.training_set_weapon_level(key, target_lvl)
        status_label.text = "已设置「%s」为 Lv.%d" % [Catalog.weapon_name(key), target_lvl]
    refresh()

func _set_all_weapons_level(lvl: int) -> void:
    if host == null:
        return
    for item in host.inventory.duplicate():
        host.training_set_weapon_level(str(item["id"]), lvl)
    status_label.text = "已将当前装备的全部武器升至 Lv.%d" % lvl
    refresh()

func _adjust_buff(key: String, delta_lvl: int) -> void:
    if host == null:
        return
    var cur: int = int(host.buff_levels.get(key, 0))
    var nxt: int = maxi(0, cur + delta_lvl)
    host.training_set_buff(key, nxt)
    status_label.text = "「%s」层数已调整为 %d" % [str(Growth.BUFFS[key]["name"]), nxt]
    refresh()

func _clear_all_buffs() -> void:
    if host == null:
        return
    for key in Growth.BUFFS:
        host.buff_levels[key] = 0
    host.refresh_stats()
    host.player_hp = float(host.stats["max_hp"])
    host.update_hud()
    status_label.text = "已清零全部 Buff"
    refresh()

func _spawn_pack(kind: String, count: int) -> void:
    if host == null:
        return
    host.training_spawn(kind, count)
    status_label.text = "已刷出测试目标，点「开始测试」关闭面板开打！" if KeyBindings.is_touch_platform() else "已刷出测试目标，点「开始测试」或按 T 关闭面板开打！"

func _clear_enemies() -> void:
    if host == null:
        return
    host.clear_enemies()
    host.projectiles.clear()
    host.burning_fields.clear()
    status_label.text = "已清空场上怪物与弹丸"

func _toggle_godmode() -> void:
    if host == null:
        return
    host.training_godmode = not host.training_godmode
    if host.training_godmode:
        host.player_hp = float(host.stats["max_hp"])
    refresh()

func _set_enemy_wave(wv: int) -> void:
    if host == null:
        return
    host.training_set_enemy_wave(wv)
    status_label.text = "刷怪强度已切换为：%s" % ("10万血沙袋" if wv == 0 else "第 %d 关数值" % wv)
    refresh()

func _toggle_enemy_immortal() -> void:
    if host == null:
        return
    host.training_enemy_immortal = not host.training_enemy_immortal
    status_label.text = "怪物锁血已%s（%s）" % ["开启" if host.training_enemy_immortal else "关闭", "怪物剩1血不死，方便测特效与DPS" if host.training_enemy_immortal else "怪物可被正常击杀"]
    refresh()
