extends SceneTree

const Hud = preload("res://src/hud.gd")
const Assets = preload("res://src/asset_library.gd")
const Growth = preload("res://src/growth.gd")
const Catalog = preload("res://src/catalog.gd")
const Economy = preload("res://src/economy.gd")

var checks: int = 0
var failures: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func descendents(node: Node) -> Array:
    var result: Array = []
    for child in node.get_children():
        result.append(child)
        result.append_array(descendents(child))
    return result

func named_button(hud, key: String) -> BaseButton:
    for node in descendents(hud.overlay):
        if node is BaseButton and node.name == key:
            return node
    return null

func label_text(hud) -> String:
    var result: PackedStringArray = []
    for node in descendents(hud.overlay):
        if node is Label:
            result.append(node.text)
    return "\n".join(result)

func card_text(button: Node) -> String:
    var result: PackedStringArray = []
    if button == null:
        return ""
    for node in descendents(button):
        if node is Label:
            result.append(node.text)
    return "\n".join(result)

func settle() -> void:
    await process_frame
    await process_frame

func click(button: BaseButton) -> void:
    expect(button != null, "navigation target is an actual button")
    if button == null:
        return
    await settle()
    var point: Vector2 = button.get_global_rect().get_center()
    var move: InputEventMouseMotion = InputEventMouseMotion.new()
    move.position = point
    move.global_position = point
    Input.parse_input_event(move)
    await process_frame
    for down in [true, false]:
        var event: InputEventMouseButton = InputEventMouseButton.new()
        event.position = point
        event.global_position = point
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        Input.parse_input_event(event)
        await process_frame

func inside_button(node: Node) -> bool:
    var current: Node = node
    while current != null:
        if current is BaseButton:
            return true
        current = current.get_parent()
    return false

func named_ancestor(node: Node, key: String) -> bool:
    var current: Node = node
    while current != null:
        if str(current.name) == key:
            return true
        current = current.get_parent()
    return false

func button_label_fits(button: BaseButton, context: String) -> void:
    if button.text.is_empty():
        return
    var font: Font = button.get_theme_font("font")
    var font_size: int = button.get_theme_font_size("font_size")
    if font == null:
        return
    var needed: Vector2 = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    var inner: float = button.get_global_rect().size.x
    var style: StyleBox = button.get_theme_stylebox("normal")
    if style != null:
        inner -= style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
    expect(needed.x <= inner + 1.0, context + " keeps button label fully visible: " + str(button.name) + " / " + button.text)

func copy_fits(node: Label, context: String) -> void:
    if node.text.is_empty():
        return
    var font: Font = node.get_theme_font("font")
    var font_size: int = node.get_theme_font_size("font_size")
    if font == null:
        return
    var rect: Rect2 = node.get_global_rect()
    var needed: Vector2
    if node.autowrap_mode != TextServer.AUTOWRAP_OFF or node.text.contains("\n"):
        needed = font.get_multiline_string_size(node.text, node.horizontal_alignment, maxf(1.0, rect.size.x), font_size)
    else:
        needed = font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    expect(needed.x <= rect.size.x + 2.0 and needed.y <= rect.size.y + 2.0, context + " keeps copy inside its box: " + node.text.substr(0, 20))

func _block_id(node: Control) -> String:
    if node is Label:
        return "label:" + node.text.substr(0, 18) + str(node.get_global_rect())
    return str(node.name) + str(node.get_global_rect())

func check_layout(hud, context: String) -> void:
    await settle()
    var buttons: Array = []
    var blocks: Array = []
    var strict: bool = context in ["title page", "start page", "character select"]
    for node in descendents(hud.overlay):
        if not (node is Control and node.is_visible_in_tree()):
            continue
        var rect: Rect2 = node.get_global_rect()
        if node is BaseButton:
            if context in ["shop confirm", "choice confirm"] and not named_ancestor(node, "ShopConfirmSheet") and not str(node.name).begins_with("ShopBuy"):
                continue
            expect(rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= 1280.1 and rect.end.y <= 800.1, context + " keeps actionable controls inside 1280×800: " + str(node.name))
            expect(rect.size.x >= 40.0 and rect.size.y >= 34.0, context + " retains usable target size: " + str(node.name))
            button_label_fits(node, context)
            for other in buttons:
                expect(not rect.intersects(other.get_global_rect()), context + " does not overlap navigation targets: " + str(node.name) + " / " + str(other.name))
            buttons.append(node)
            blocks.append(node)
        elif node is Label and not node.text.is_empty() and not inside_button(node):
            if strict:
                expect(rect.position.x >= -0.1 and rect.position.y >= -0.1 and rect.end.x <= 1280.1 and rect.end.y <= 800.1, context + " keeps labels inside 1280×800: " + node.text.substr(0, 16))
                copy_fits(node, context)
                if not named_ancestor(node, "PressPhoto"):
                    blocks.append(node)
        elif str(node.name) in ["PressPhoto", "CastPortrait", "GameTitleInk"]:
            expect(rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= 1280.1 and rect.end.y <= 800.1, context + " keeps the press image inside 1280×800")
            if strict:
                blocks.append(node)
    if strict:
        for index in range(blocks.size()):
            var left: Control = blocks[index]
            var left_rect: Rect2 = left.get_global_rect().grow(-1.0)
            for other_index in range(index + 1, blocks.size()):
                var right: Control = blocks[other_index]
                if named_ancestor(left, str(right.name)) or named_ancestor(right, str(left.name)):
                    continue
                expect(not left_rect.intersects(right.get_global_rect().grow(-1.0)), context + " does not let typography, the photo or actions cover each other: " + _block_id(left) + " / " + _block_id(right))

func _initialize() -> void:
    call_deferred("run_checks")

func run_checks() -> void:
    root.size = Vector2i(1280, 800)
    var hud = Hud.new()
    root.add_child(hud)
    hud.setup(Assets.new())
    var complete_api: bool = true
    for method in ["configure_save", "show_help", "show_settings", "show_shop", "update_round"]:
        var present: bool = hud.has_method(method)
        expect(present, "HUD implements the " + method + " interaction contract")
        complete_api = complete_api and present
    for key in ["new_trial_requested", "buy_requested", "next_round_requested", "save_requested", "continue_requested", "home_requested", "settings_changed"]:
        var present: bool = hud.has_signal(key)
        expect(present, "HUD exposes " + key + " for the real controller")
        complete_api = complete_api and present
    if not complete_api:
        hud.queue_free()
        await process_frame
        finish()
        return

    var events: Array = []
    hud.starter_selected.connect(func(key: String): events.append(["starter", key]))
    hud.start_requested.connect(func(trial: bool): events.append(["start", trial]))
    hud.trial_requested.connect(func(): events.append(["trial"]))
    hud.new_trial_requested.connect(func(): events.append(["new_trial"]))
    hud.continue_requested.connect(func(): events.append(["continue"]))
    hud.save_requested.connect(func(): events.append(["save"]))
    hud.home_requested.connect(func(): events.append(["home"]))
    hud.pause_requested.connect(func(): events.append(["resume"]))
    hud.stats_requested.connect(func(): events.append(["stats"]))
    hud.settings_changed.connect(func(value: bool): events.append(["autosave", value]))
    hud.buy_requested.connect(func(index: int): events.append(["buy", index]))
    hud.replace_requested.connect(func(key: String): events.append(["replace", key]))
    hud.replace_cancelled.connect(func(): events.append(["replace_cancel"]))
    hud.next_round_requested.connect(func(): events.append(["next"]))
    hud.choice_selected.connect(func(key: String): events.append(["choice", key]))
    hud.restart_requested.connect(func(): events.append(["restart"]))

    var caveman: Dictionary = Catalog.character("caveman")
    expect(str(caveman.get("id", "")) == "caveman" and str(caveman.get("starting_weapon", "")) == "sling", "the default hunter starts with the sling and is catalogued for later characters")
    expect(caveman.get("skills", []) is Array and caveman["skills"].size() >= 1, "character skills are an extensible list")
    var chief: Dictionary = Catalog.character("chief")
    var barbarian: Dictionary = Catalog.character("barbarian")
    expect(str(chief.get("starting_weapon", "")) == "spear" and str(barbarian.get("starting_weapon", "")) == "club", "chieftain and barbarian use distinct starting weapons")
    expect(Catalog.CHARACTER_ORDER == ["caveman", "chief", "barbarian"], "exactly three playable hunters are catalogued")

    expect(hud.screen == "title", "setup opens the title page")
    expect(named_button(hud, "EnterCamp") != null, "home has an enter-camp control")
    expect(not label_text(hud).contains("营地日报"), "approved handdrawn home replaces the newspaper masthead")
    await check_layout(hud, "title page")
    hud.configure_save(false, true)
    var continue_button: BaseButton = named_button(hud, "ContinueSave")
    expect(continue_button != null and continue_button.disabled, "absent save is visibly unavailable")
    await click(continue_button)
    expect(events.is_empty(), "clicking absent-save control never requests a restore")
    await click(named_button(hud, "EnterCamp"))
    expect(hud.screen == "cast", "enter camp directly opens character select")
    var roster: String = label_text(hud)
    expect(roster.contains("原始人") and roster.contains("弹弓") and roster.contains("技能") and roster.contains("1 / 3"), "character select shows the hunter, starter, skills and page count")
    expect(not roster.contains("酋长") and not roster.contains("野蛮人"), "the arrow page shows one hunter at a time")
    for key in ["PrevCharacter", "NextCharacter"]:
        var arrow: BaseButton = named_button(hud, key)
        expect(arrow != null and not arrow.disabled, "class arrows stay available once multiple hunters exist: " + key)
    expect(named_button(hud, "StartSling") != null and named_button(hud, "StartClub") != null and named_button(hud, "StartSpear") != null, "each hunter has a clearly named confirm button")
    expect(named_button(hud, "StartSling").visible and not named_button(hud, "StartClub").visible and not named_button(hud, "StartSpear").visible, "only the selected hunter confirm button is shown")
    await check_layout(hud, "character select")
    await click(named_button(hud, "NextCharacter"))
    expect(hud.screen == "cast" and hud.preview_character == "chief" and hud.selected_character == "caveman", "arrows cycle from the default hunter to the chieftain")
    roster = label_text(hud)
    expect(roster.contains("酋长") and roster.contains("骨矛") and roster.contains("2 / 3"), "the chieftain page previews the spear and its skills")
    expect(named_button(hud, "StartSpear").visible and not named_button(hud, "StartSling").visible, "confirm updates to the chieftain start button")
    await check_layout(hud, "character select")
    await click(named_button(hud, "NextCharacter"))
    expect(hud.preview_character == "barbarian" and hud.selected_character == "caveman", "arrows continue from the chieftain to the barbarian")
    roster = label_text(hud)
    expect(roster.contains("野蛮人") and roster.contains("木棒") and roster.contains("3 / 3"), "the barbarian page previews the club and its skills")
    await check_layout(hud, "character select")
    await click(named_button(hud, "PrevCharacter"))
    expect(hud.preview_character == "chief" and hud.selected_character == "caveman", "the left arrow returns to the chieftain")
    await click(named_button(hud, "Settings"))
    await click(named_button(hud, "Back"))
    expect(hud.screen == "cast", "settings remember selection as their origin")
    await click(named_button(hud, "Back"))
    expect(hud.screen == "title", "selection back returns to the title")
    await click(named_button(hud, "EnterCamp"))
    hud.selected_character = "caveman"
    hud.show_cast()
    await click(named_button(hud, "StartSling"))
    expect(events == [["starter", "sling"], ["start", false]], "confirmed selection routes sling before normal UI departure")
    events.clear()
    hud.selected_character = "barbarian"
    hud.show_cast()
    await click(named_button(hud, "StartClub"))
    expect(events == [["starter", "club"], ["start", false]], "barbarian confirmation starts with the club")
    events.clear()
    hud.selected_character = "chief"
    hud.show_cast()
    await click(named_button(hud, "StartSpear"))
    expect(events == [["starter", "spear"], ["start", false]], "chieftain confirmation starts with the spear")
    events.clear()
    hud.show_title()
    hud.configure_save(true, false, "已保存 · 第 3 关", {"wave":3,"coins":28,"player_hp":6.0,"player_level":4})
    continue_button = named_button(hud, "ContinueSave")
    expect(continue_button != null and not continue_button.disabled, "availability refreshes the open home")
    await click(continue_button)
    expect(hud.screen == "continue" and events.is_empty(), "continue first opens a preview without emitting restoration")
    expect(label_text(hud).contains("28"), "continue preview displays live save summary values")
    await click(named_button(hud, "ConfirmContinue"))
    expect(events == [["continue"]], "explicit continue restores without requesting a new game")
    events.clear()
    await check_layout(hud, "continue dialog")
    await click(named_button(hud, "Back"))
    await click(named_button(hud, "HelpGameplay"))
    expect(hud.screen == "help" and label_text(hud).contains("金币") and label_text(hud).contains("不限时"), "help retains coins and untimed Boss guidance")
    await click(named_button(hud, "TrialBasic"))
    expect(events.is_empty() and hud.screen == "help_confirm" and label_text(hud).contains("不会覆盖正式存档"), "help trial explains that it does not overwrite the official save and waits for confirm")
    await check_layout(hud, "help trial confirm")
    await click(named_button(hud, "HelpTrialCancel"))
    expect(events.is_empty() and hud.screen == "help", "cancelling help trial returns to help without starting")
    await click(named_button(hud, "TrialBasic"))
    await click(named_button(hud, "HelpTrialConfirm"))
    expect(events == [["trial"]], "confirming the basic trial emits only after the warning")
    events.clear()
    hud.show_help("gameplay", false)
    await click(named_button(hud, "TrialNew"))
    await click(named_button(hud, "HelpTrialConfirm"))
    expect(events == [["new_trial"]], "confirming the new-weapon trial emits only after the warning")
    events.clear()
    hud.show_help("gameplay", false)
    await click(named_button(hud, "HelpKeys"))
    expect(hud.screen == "help" and label_text(hud).contains("F5") and label_text(hud).contains("1 / 2 / 3") and label_text(hud).contains("V") and not label_text(hud).contains("F2") and not label_text(hud).contains("F3"), "keys expose save, HUD-hide and choice shortcuts, not official debug trial keys")
    await click(named_button(hud, "HelpLinks"))
    expect(hud.screen == "help" and label_text(hud).contains("火药筒") and label_text(hud).contains("炮口") and label_text(hud).contains("按 Q"), "weapon-link help teaches the Q toggle and cannon-muzzle chain")
    await click(named_button(hud, "Stats"))
    expect(events == [["stats"]], "attributes preserve the B controller route")
    events.clear()
    await click(named_button(hud, "Back"))
    expect(hud.screen == "title", "help returns to its home origin")
    await click(named_button(hud, "Settings"))
    expect(hud.screen == "settings", "settings are reachable from home")
    var music_value: Label = hud.overlay.find_child("MusicVolumeValue", true, false) as Label
    var sfx_value: Label = hud.overlay.find_child("SfxVolumeValue", true, false) as Label
    expect(music_value != null and sfx_value != null and music_value.text.contains("%") and sfx_value.text.contains("%"), "volume sliders show numeric percentages")
    expect(named_button(hud, "DamageNumbers") != null and named_button(hud, "FullscreenMode") != null, "settings expose damage-number and window mode toggles")
    var autosave: CheckButton = named_button(hud, "Autosave") as CheckButton
    expect(autosave != null and not autosave.button_pressed, "settings reflect persisted autosave")
    var save_button: BaseButton = named_button(hud, "SaveNow")
    expect(save_button != null and save_button.disabled, "home settings cannot save an absent run")
    await click(autosave)
    expect(events == [["autosave", true]], "autosave emits the new value once")
    events.clear()
    hud.configure_save(true, true, "保存失败：测试提示")
    expect(label_text(hud).contains("保存失败：测试提示"), "save failures refresh the visible settings")
    await check_layout(hud, "settings page")
    await click(named_button(hud, "Back"))
    expect(hud.screen == "title", "settings return to their home origin")

    hud.show_menu("pause", 17)
    await click(named_button(hud, "SaveNow"))
    await click(named_button(hud, "Resume"))
    await click(named_button(hud, "Home"))
    expect(events == [["save"], ["resume"], ["home"]], "pause actions route save, resume and home separately")
    events.clear()
    await click(named_button(hud, "RestartRun"))
    expect(events.is_empty() and hud.screen == "restart_confirm", "restarting the official run asks for confirmation first")
    await check_layout(hud, "restart confirm")
    await click(named_button(hud, "RestartCancel"))
    expect(events.is_empty() and hud.screen == "pause", "cancelling restart returns to pause with the current run intact")
    await click(named_button(hud, "RestartRun"))
    await click(named_button(hud, "RestartConfirm"))
    expect(events == [["restart"]], "confirming restart emits after the warning")
    events.clear()
    hud.show_menu("pause", 17)
    await click(named_button(hud, "HelpGameplay"))
    await click(named_button(hud, "Back"))
    expect(hud.screen == "pause", "in-run help returns to pause without resuming simulation")
    await click(named_button(hud, "Settings"))
    save_button = named_button(hud, "SaveNow")
    expect(save_button != null and not save_button.disabled, "paused-run settings allow explicit manual save")
    await click(save_button)
    expect(events == [["save"]], "manual save in settings reaches the controller")
    events.clear()
    await click(named_button(hud, "Back"))
    expect(hud.screen == "pause", "in-run settings preserve pause origin")
    await check_layout(hud, "pause page")

    var stock: Array = [{"id": "sling", "price": 5, "sold": false}, {"id": "power", "price": 20, "sold": false}, {"id": "pet", "price": 4, "sold": true}, {"id": "heal", "price": 6, "sold": false}]
    hud.entered_screen = "combat"
    hud.show_shop(stock, 6, 4, [{"id": "sling", "level": 1}], {}, 4.0, 8.0)
    expect(hud.screen == "shop" and hud.choice_ids.is_empty(), "shop cannot be mistaken for a free growth choice")
    expect(hud.entered_screen == "combat", "shop parchment unrolls without a full-screen page transition")
    expect(not named_button(hud, "ShopOffer0").disabled, "affordable weapon offer is actionable")
    expect(named_button(hud, "ShopOffer1").disabled, "unaffordable Buff cannot be clicked")
    expect(named_button(hud, "ShopOffer2").disabled, "sold support cannot be purchased twice")
    expect(not named_button(hud, "ShopOffer3").disabled, "exact-price healing remains available")
    await click(named_button(hud, "ShopOffer0"))
    expect(events.is_empty() and hud.screen == "shop_confirm", "buying opens a confirmation instead of charging immediately")
    expect(named_button(hud, "ShopOffer0") != null and named_button(hud, "ShopOffer0").is_visible_in_tree(), "the confirmation popup leaves the shop page visible underneath")
    expect(hud.overlay.find_child("ShopConfirmSheet", true, false) != null, "confirmation is a named popup sheet over the shop")
    var shop_sheet: Control = hud.overlay.find_child("ShopConfirmSheet", true, false) as Control
    expect(shop_sheet.get_global_rect().position.y >= 160.0 and shop_sheet.get_global_rect().end.y <= 680.0, "the shop confirm dialog is a compact centered popup")
    await check_layout(hud, "shop confirm")
    await click(named_button(hud, "ShopBuyCancel"))
    expect(events.is_empty() and hud.screen == "shop" and stock[0]["sold"] == false, "cancel returns to shop with no purchase")
    expect(hud.overlay.find_child("ShopConfirmSheet", true, false) == null, "cancel removes the popup and does not replace the shop")
    await click(named_button(hud, "ShopOffer0"))
    await click(named_button(hud, "ShopBuyConfirm"))
    await click(named_button(hud, "ShopOffer1"))
    await click(named_button(hud, "ShopOffer2"))
    await click(named_button(hud, "ShopOffer3"))
    await click(named_button(hud, "ShopBuyConfirm"))
    expect(events == [["buy", 0], ["buy", 3]], "real shop buttons emit only the confirmed available stock indices")
    expect(stock[0]["sold"] == false, "HUD never mutates controller-owned stock or grants free purchases")
    events.clear()
    await click(named_button(hud, "NextRound"))
    expect(events == [["next"]], "next round is an explicit action independent of purchase")
    events.clear()
    expect(label_text(hud).contains("恢复 3") and label_text(hud).contains("4.0 / 8"), "healing displays its actual amount and current health")
    await check_layout(hud, "shop page")
    hud.show_shop([{"id":"sling","price":5,"sold":true}],6,4,[{"id":"sling","level":2}],{},4.0,8.0)
    expect(label_text(hud).contains("Lv.1 → 2"),"sold weapon card describes the upgrade just purchased instead of a new unbought tier")
    expect(not label_text(hud).contains("购买并更换"), "a sold owned-weapon upgrade is not labeled as replace")

    var full_loadout: Array = [{"id":"club","level":1},{"id":"axe","level":1},{"id":"blade","level":3},{"id":"sling","level":1},{"id":"powder","level":5},{"id":"staff","level":1}]
    hud.show_shop([{"id":"spear","price":22,"sold":false,"level":1},{"id":"club","price":22,"sold":false}], 80, 4, full_loadout, {}, 4.0, 8.0)
    expect(card_text(named_button(hud, "ShopOffer0")).contains("购买并更换"), "a full-loadout shop card for a new weapon reads 购买并更换 on the card itself")
    expect(card_text(named_button(hud, "ShopOffer0")).contains("Lv.1"), "even a basic shop weapon shows Lv.1 on the card")
    expect(card_text(named_button(hud, "ShopOffer0")).contains("武器") and card_text(named_button(hud, "ShopOffer1")).contains("武器"), "shop weapon cards are labeled 武器")
    expect(not card_text(named_button(hud, "ShopOffer1")).contains("购买并更换"), "an owned-weapon upgrade stays a normal purchase, not 更换")
    expect(card_text(named_button(hud, "ShopOffer1")).contains("Lv.1 → 2"), "owned upgrade cards still show the level path")
    await click(named_button(hud, "ShopOffer0"))
    expect(hud.screen == "shop_confirm" and label_text(hud).contains("售回") and label_text(hud).contains("伤害") and label_text(hud).contains("木棒"), "replace confirmation compares incoming and current weapons by damage, level and gold")
    await click(named_button(hud, "ShopBuyCancel"))
    await check_layout(hud, "shop page")
    hud.show_shop([{"id":"spear","price":30,"sold":false,"level":5}], 80, 4, full_loadout, {}, 4.0, 8.0)
    expect(card_text(named_button(hud, "ShopOffer0")).contains("购买并更换") and card_text(named_button(hud, "ShopOffer0")).contains("Lv.5") and card_text(named_button(hud, "ShopOffer0")).contains("觉醒"), "a high-tier shop offer shows its actual awakened level and the replace action")
    await check_layout(hud, "shop page")

    hud.show_choices(["hammer", "power", "pet"], full_loadout, {}, "chest", 4, {"hammer": 3})
    expect(card_text(named_button(hud, "GrowthOffer0")).contains("更换") and card_text(named_button(hud, "GrowthOffer0")).contains("Lv.3"), "a full-loadout chest card for a new weapon is labeled 更换 and shows its level")
    expect(not card_text(named_button(hud, "GrowthOffer1")).contains("更换"), "a buff card is not labeled 更换")
    await click(named_button(hud, "GrowthOffer0"))
    expect(events.is_empty() and hud.screen == "choice_confirm", "taking a chest weapon opens a safety confirm instead of granting immediately")
    expect(named_button(hud, "GrowthOffer0") != null and named_button(hud, "GrowthOffer0").is_visible_in_tree(), "the chest confirm popup leaves the chest offers visible underneath")
    expect(hud.overlay.find_child("ShopConfirmSheet", true, false) != null, "chest confirmation uses the compact centered popup")
    var confirm_rect: Rect2 = (hud.overlay.find_child("ShopConfirmSheet", true, false) as Control).get_global_rect()
    expect(confirm_rect.position.x >= 0.0 and confirm_rect.position.y >= 0.0 and confirm_rect.end.x <= 1280.1 and confirm_rect.end.y <= 800.1, "the compact confirm dialog stays fully inside 1280×800")
    expect(confirm_rect.position.y >= 160.0 and confirm_rect.end.y <= 680.0, "the confirm dialog is centered rather than a bottom sheet")
    expect(label_text(hud).contains("售回") and label_text(hud).contains("伤害") and label_text(hud).contains("木棒"), "chest replace confirmation compares incoming and current weapons by damage, level and gold")
    await check_layout(hud, "choice confirm")
    await click(named_button(hud, "ShopBuyCancel"))
    expect(events.is_empty() and hud.screen == "growth" and hud.overlay.find_child("ShopConfirmSheet", true, false) == null, "cancel closes the chest confirm and leaves the reward available")
    await click(named_button(hud, "GrowthOffer0"))
    await click(named_button(hud, "ShopBuyConfirm"))
    expect(events == [["choice", "hammer"]], "confirming a chest weapon emits the offer only after the safety popup")
    events.clear()
    hud.show_choices(["hammer", "power", "pet"], [{"id":"club","level":1}], {}, "chest", 4, {"hammer": 1})
    await click(named_button(hud, "GrowthOffer0"))
    expect(hud.screen == "choice_confirm" and named_button(hud, "GrowthOffer0").is_visible_in_tree(), "taking a chest weapon still asks for confirm when the loadout is not full")
    expect(label_text(hud).contains(str(Catalog.WEAPONS["hammer"]["name"])), "non-replace chest confirm still names the incoming weapon")
    await click(named_button(hud, "ShopBuyCancel"))
    expect(hud.screen == "growth" and events.is_empty(), "canceling a non-replace chest confirm does not take the weapon")
    await check_layout(hud, "growth page")
    hud.show_choices(["hammer", "power", "pet"], [{"id":"club","level":1}], {}, "xp", 1, {"hammer": 1})
    expect(card_text(named_button(hud, "GrowthOffer0")).contains("Lv.1") and not card_text(named_button(hud, "GrowthOffer0")).contains(" · 更换"), "when the loadout is not full, a new weapon is not a replace action but still shows Lv.1")
    await check_layout(hud, "growth page")

    hud.entered_screen = "combat"
    hud.show_choices(["club", "power", "pet"], [], {}, "xp", 2)
    expect(hud.screen == "growth", "experience choices retain their own screen state")
    expect(hud.entered_screen == "combat", "choice parchment unrolls without a full-screen page transition")
    hud.choose_index(1)
    expect(events == [["choice", "power"]], "number selection still emits the offered Buff id")
    events.clear()
    await check_layout(hud, "growth page")
    expect(hud.has_method("show_replace") and hud.has_signal("replace_requested") and hud.has_signal("replace_cancelled"), "replace-when-full has a dedicated parchment API")
    var loadout: Array = [{"id":"club","level":2},{"id":"axe","level":1},{"id":"blade","level":3},{"id":"sling","level":1},{"id":"powder","level":5},{"id":"staff","level":1}]
    events.clear()
    hud.show_replace({"id":"spear","level":3,"source":"shop"}, loadout)
    expect(hud.screen == "replace", "replace parchment uses its own screen state")
    for index in range(6):
        expect(named_button(hud, "ReplaceSlot%d" % index) != null, "replace slot %d is a named button" % index)
    expect(named_button(hud, "ReplaceCancel") != null, "replace can be cancelled by a named button")
    expect(label_text(hud).contains("将获得") and label_text(hud).contains("骨矛") and label_text(hud).contains("Lv.3"), "replace parchment names the incoming high-tier weapon")
    expect(label_text(hud).contains("Lv.1") and label_text(hud).contains("Lv.5"), "replace slots label every current level, including Lv.1")
    expect(label_text(hud).contains("出售") and label_text(hud).contains(str(Economy.sell_price("club", 1, 2))) and label_text(hud).contains(str(Economy.sell_price("axe", 1, 1))), "replace slots preview sell-back at the documented fraction of each weapon's level price")
    await check_layout(hud, "replace page")
    await click(named_button(hud, "ReplaceCancel"))
    expect(events == [["replace_cancel"]], "cancel emits without swapping a slot")
    events.clear()
    hud.show_replace({"id":"spear","level":3,"source":"shop"}, loadout)
    await click(named_button(hud, "ReplaceSlot0"))
    expect(events == [["replace", "club"]], "choosing a slot emits that weapon id for the controller to swap")
    events.clear()
    hud.show_stats({"power": 1}, Growth.stats({"power": 1}))
    await click(named_button(hud, "Back"))
    expect(hud.screen == "stats" and events == [["stats"]], "stats close through the controller so its previous-screen state remains authoritative")
    events.clear()
    await check_layout(hud, "stats page")

    hud.hide_menu() # Battle bindings are audited in battle; offer screens now hide the background HUD.
    hud.update_state(4.0, 0.0, 17, 2.0, 6, [{"id": "sling", "level": 1}], false, Catalog.LINKS["none"], false, false)
    hud.update_round(7, 14.2, false, 23)
    var hide_btn: BaseButton = hud.root.find_child("HideUI", true, false) as BaseButton
    expect(hide_btn != null and hide_btn.visible and hide_btn.get_global_rect().size.y >= 34.0, "combat exposes a named HideUI toggle that stays a usable target")
    expect(hud.root.find_child("Formation", true, false) == null and hud.root.find_child("LinkMode", true, false) == null and hud.root.find_child("TargetMode", true, false) == null, "sweep, Q-link and nearest-target buttons are no longer always-on combat chrome")
    hud.toggle_hud_hidden()
    expect(hud.hud_hidden and hud.status_strip.visible and hud.timer_label.is_visible_in_tree() and hide_btn.visible and hide_btn.text.contains("显示"), "hiding the UI keeps health, XP, the wave timer and the toggle visible")
    expect(hud.timer_label.get_parent() != null and hud.status_strip.is_ancestor_of(hud.timer_label), "the wave timer is fused into the HP and XP vitals strip")
    expect(not hud.coin_label.is_visible_in_tree(), "the rest of the combat chrome is hidden with the UI toggle")
    hud.toggle_hud_hidden()
    expect(not hud.hud_hidden and hud.timer_label.is_visible_in_tree() and hide_btn.text.contains("隐藏"), "pressing the toggle again restores the combat UI")
    expect(hud.timer_label.text.contains("7") and hud.timer_label.text.contains("00:16"), "ordinary timer follows stage-local time after the legacy HUD update")
    expect(hud.coin_label.text.contains("23") and not hud.boss_bar.visible, "coin total updates while normal rounds hide Boss health")
    hud.update_round(10, 142.0, true, 30, 40.0, 100.0)
    expect(hud.timer_label.text.contains("不限时") and not hud.timer_label.text.contains("00:"), "Boss UI has no false thirty-second deadline")
    expect(hud.boss_bar.visible and is_equal_approx(hud.boss_bar.value, 40.0) and is_equal_approx(hud.boss_bar.max_value, 100.0), "Boss bar tracks actual remaining health")
    hud.hide_menu()
    expect(not hud.overlay.visible and hud.choice_ids.is_empty(), "returning to combat clears selection shortcuts")
    hud.show_menu("lose", 17)
    expect(label_text(hud).contains("再来一局"), "defeat retains the required retry heading")
    await check_layout(hud, "defeat page")
    hud.queue_free()
    await process_frame
    finish()

func finish() -> void:
    print("HUD NAVIGATION RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
