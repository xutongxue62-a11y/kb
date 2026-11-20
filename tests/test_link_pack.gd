extends SceneTree

const Catalog = preload("res://src/catalog.gd")
const KeyBindings = preload("res://src/key_bindings.gd")

var checks: int = 0
var failures: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func overlay_text(node: Node) -> String:
    var value: String = ""
    if node is Label or node is Button or node is LinkButton:
        value += str(node.text) + "\n"
    if node is RichTextLabel:
        value += str(node.get_parsed_text()) + "\n"
    for child in node.get_children():
        value += overlay_text(child)
    return value

func make_world(suffix: String):
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/link_pack_%s_%s" % [suffix, str(Time.get_ticks_usec())])
    root.add_child(world)
    world.set_physics_process(false)
    world.demo = false
    world.animation_demo = false
    return world

func press_key(world, code: int) -> void:
    var event := InputEventKey.new()
    event.pressed = true
    event.echo = false
    event.physical_keycode = code
    event.keycode = code
    world._unhandled_key_input(event)

func pack(world):
    return world.hud.link_pack if world.hud != null else null

func _initialize() -> void:
    call_deferred("run_checks")

func run_checks() -> void:
    root.size = Vector2i(1280, 800)
    await check_open_close_and_no_cycle()
    await check_drop_unlink_error_and_swap()
    await check_multiple_links()
    await check_attributes_and_freeze()
    await check_copy_not_clipped()
    await check_discovery_still_works()
    await check_help_and_hints()
    await check_blocked_screens()
    await check_save_multi_links()
    await check_upgraded_appearance()
    await check_reorder_and_persist()
    await check_drop_face_vs_edge()
    await check_restack_cancel_and_host_enchant()
    print("LINK PACK RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)

func check_open_close_and_no_cycle() -> void:
    var world = make_world("toggle")
    world.start_run(true)
    expect(world.active_link["id"] == "none", "trial still starts without a forced link")
    expect(not world.link_pack_open, "pack starts closed")
    var first_id: String = str(world.active_link["id"])
    press_key(world, KeyBindings.code_of("link"))
    expect(world.link_pack_open and world.hud.screen == "link_pack", "Q / link opens the weapon pack")
    expect(world.active_link["id"] == first_id, "opening the pack does not cycle recipes")
    expect(pack(world) != null and pack(world).is_open(), "pack UI is present after Q")
    press_key(world, KeyBindings.code_of("link"))
    expect(not world.link_pack_open and world.hud.screen == "combat", "Q closes the pack")
    expect(world.active_link["id"] == first_id, "closing the pack still does not cycle recipes")
    expect(world.open_link_pack(), "open_link_pack can open again")
    press_key(world, KeyBindings.code_of("cancel"))
    expect(not world.link_pack_open and not world.paused, "Esc closes the pack and does not pause")
    world.open_link_pack()
    expect(world.hud.overlay.find_child("CloseLinkPack", true, false) != null, "pack has a close button")
    world.hud.request_close_link_pack()
    expect(not world.link_pack_open, "the close button path dismisses the pack")
    world.switch_combo_mode()
    expect(world.link_pack_open and world.active_link["id"] == "none", "old cycle entry now toggles the pack instead")
    world.close_link_pack()
    world.queue_free()
    await process_frame

func check_drop_unlink_error_and_swap() -> void:
    var world = make_world("drop")
    world.start_run(true)
    expect(world.open_link_pack(), "pack opens over a six-weapon trial")
    var ui = pack(world)
    var ids: Array = ui.weapon_ids()
    expect(ids.has("powder") and ids.has("staff") and ids.has("axe") and ids.has("club"), "pack lists owned weapons as nodes")
    var before: String = str(world.active_link["id"])
    var bad: Dictionary = ui.try_drop("club", "staff")
    expect(not bad.get("ok", true) and str(bad.get("error", "")).contains("这两件武器不能联动"), "incompatible drop returns a clear error")
    expect(ui.error_text().contains("这两件武器不能联动"), "incompatible drop is shown in the pack")
    expect(world.active_link["id"] == before, "incompatible drop leaves the current link unchanged")
    var good: Dictionary = ui.try_drop("powder", "staff")
    expect(good.get("ok", false) and str(good.get("link_id", "")) == "rune_shell", "compatible drop enables the catalog recipe")
    expect(world.active_link["id"] == "rune_shell", "select_link applied 魔法炮")
    var copy: String = ui.displayed_text()
    expect(copy.contains("魔法炮"), "linked pair hangs a result node named 魔法炮")
    expect(ui.result_control("rune_shell") != null, "魔法炮 has a compact result node above the row")
    expect(not copy.contains(Catalog.benefit_text(Catalog.LINKS["rune_shell"])) and not copy.contains(Catalog.cost_text(Catalog.LINKS["rune_shell"])), "official benefit and cost are not resident on the pack")
    ui.hover_result("rune_shell")
    await process_frame
    var tip: String = ui.tooltip_text()
    expect(tip.contains("优点") and tip.contains("缺点"), "hovering the result node shows benefit and cost labels")
    expect(tip.contains(Catalog.benefit_text(Catalog.LINKS["rune_shell"])) and tip.contains(Catalog.cost_text(Catalog.LINKS["rune_shell"])), "tooltip uses the official benefit and cost copy")
    ui.hide_result_tooltip()
    var still_bad: Dictionary = ui.try_drop("club", "rune_shell")
    expect(not still_bad.get("ok", true) and world.active_link["id"] == "rune_shell", "dropping a nonsense id does not break an existing link")
    var invalid_on_linked: Dictionary = ui.try_drop("sling", "powder")
    expect(not invalid_on_linked.get("ok", true) and world.active_link["id"] == "rune_shell", "incompatible drop onto a linked weapon keeps the old link")
    expect(ui.error_text().contains("这两件武器不能联动"), "invalid drop onto a linked card still reports the error")
    var swapped: Dictionary = ui.try_drop("powder", "axe")
    expect(swapped.get("ok", false) and world.active_link["id"] == "chain_axe", "dragging a linked weapon onto another compatible partner swaps the link")
    expect(str(swapped.get("toast", "")).contains("魔法炮") and str(swapped.get("toast", "")).contains("锁链石斧"), "swap toast names the old and new recipes")
    var unlinked: Dictionary = ui.try_unlink("axe")
    expect(unlinked.get("ok", false) and world.active_link["id"] == "none", "drag-apart / try_unlink returns to 不联动")
    expect(str(unlinked.get("toast", "")).contains("断开") or ui.toast_text().contains("断开"), "unlinking explains that the pair was disconnected")
    var again: Dictionary = ui.try_drop("staff", "powder")
    expect(again.get("ok", false) and world.active_link["id"] == "rune_shell", "pair order does not matter when forming a recipe")
    world.close_link_pack()
    world.queue_free()
    await process_frame

func check_attributes_and_freeze() -> void:
    var world = make_world("attrs")
    world.start_run(true)
    var started: float = world.elapsed
    var origin: Vector2 = world.player_position
    world.simulate(0.25, Vector2.RIGHT)
    expect(world.elapsed > started and world.player_position.x > origin.x, "combat still advances when the pack is closed")
    expect(world.open_link_pack(), "pack can open during combat")
    expect(world.player_frozen and world.link_pack_open, "opening the pack freezes the run")
    var frozen_time: float = world.elapsed
    var frozen_pos: Vector2 = world.player_position
    world.simulate(0.5, Vector2.LEFT)
    expect(is_equal_approx(world.elapsed, frozen_time) and world.player_position == frozen_pos, "the pack freezes battle time and movement")
    expect(not world.request_dodge(Vector2.RIGHT), "dodge is blocked while the pack is open")
    var ui = pack(world)
    var info: Dictionary = ui.node_info("powder")
    expect(str(info.get("name", "")).contains("火药") or str(info.get("name", "")).contains("筒"), "each node shows the weapon name")
    expect(str(info.get("stats", "")).contains("伤害") and str(info.get("stats", "")).contains("间隔"), "each node shows key combat stats")
    var text: String = ui.displayed_text()
    expect(text.contains("武器背包") and text.contains("拖"), "pack chrome explains drag-to-link")
    expect(ui.valid_drop_targets("powder").has("staff") and not ui.valid_drop_targets("powder").has("sling"), "only catalog-compatible weapons are valid drop targets")
    world.close_link_pack()
    expect(not world.link_pack_open and not world.player_frozen, "closing the pack unfreezes combat")
    var resumed: float = world.elapsed
    world.simulate(0.2, Vector2.ZERO)
    expect(world.elapsed > resumed, "combat resumes after the pack closes")
    world.queue_free()
    await process_frame

func find_labels(node: Node, label_name: String) -> Array:
    var found: Array = []
    if node is Label and str(node.name) == label_name:
        found.append(node)
    for child in node.get_children():
        found.append_array(find_labels(child, label_name))
    return found

func wrap_flags(mode: int) -> int:
    if mode == TextServer.AUTOWRAP_ARBITRARY:
        return TextServer.BREAK_MANDATORY | TextServer.BREAK_GRAPHEME_BOUND
    if mode == TextServer.AUTOWRAP_WORD:
        return TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
    if mode == TextServer.AUTOWRAP_WORD_SMART:
        return TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
    return TextServer.BREAK_MANDATORY

func label_fits(label: Label) -> bool:
    if label == null or str(label.text).is_empty():
        return true
    if label.get_line_count() > label.get_visible_line_count():
        return false
    var font: Font = label.get_theme_font("font")
    var font_size: int = label.get_theme_font_size("font_size")
    if font == null:
        return false
    var needed: Vector2 = font.get_multiline_string_size(label.text, label.horizontal_alignment, maxf(1.0, label.size.x), font_size, -1, wrap_flags(label.autowrap_mode))
    return needed.x <= label.size.x + 1.5 and needed.y <= label.size.y + 1.5

func expect_label_visible(label: Label, expected: String, context: String) -> void:
    expect(label != null, context + " exists")
    if label == null:
        return
    expect(label.text.contains(expected), context + " shows the full copy: " + expected)
    expect(not label.clip_text, context + " does not enable clip_text")
    if expected.length() > 4:
        expect(label.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY, context + " wraps Chinese with AUTOWRAP_ARBITRARY")
    expect(label.get_line_count() == label.get_visible_line_count(), context + " shows every laid-out line (%d/%d): %s" % [label.get_visible_line_count(), label.get_line_count(), label.text])
    expect(label_fits(label), context + " box fits the laid-out text (%s in %s): %s" % [str(label.size), context, label.text])

func expect_inside(inner: Control, outer: Control, context: String, pad: float = 2.0) -> void:
    expect(inner != null and outer != null, context + " has both rects")
    if inner == null or outer == null:
        return
    var box: Rect2 = Rect2(Vector2(pad, pad), outer.size - Vector2(pad * 2.0, pad * 2.0))
    var child: Rect2 = Rect2(inner.position, inner.size)
    expect(box.encloses(child) or (inner.position.x >= 0.0 and inner.position.y >= 0.0 and inner.position.x + inner.size.x <= outer.size.x + 1.5 and inner.position.y + inner.size.y <= outer.size.y + 1.5), context + " stays inside its panel")

func expect_global_inside(inner: Control, outer: Control, context: String, pad: float = 1.0) -> void:
    expect(inner != null and outer != null, context + " has both rects")
    if inner == null or outer == null:
        return
    var outer_rect: Rect2 = outer.get_global_rect().grow(-pad)
    var inner_rect: Rect2 = inner.get_global_rect()
    var slack := Vector2(1.5, 1.5)
    var fits: bool = outer_rect.encloses(inner_rect) or (inner_rect.position.x >= outer_rect.position.x - slack.x and inner_rect.position.y >= outer_rect.position.y - slack.y and inner_rect.end.x <= outer_rect.end.x + slack.x and inner_rect.end.y <= outer_rect.end.y + slack.y)
    expect(fits, context + " stays fully visible inside the pack (card %s in %s)" % [str(inner_rect), str(outer.get_global_rect())])

func _has_connection(pairs: Array, left_id: String, right_id: String) -> bool:
    var wanted: Array = [left_id, right_id] if left_id < right_id else [right_id, left_id]
    return pairs.has(wanted)

func assert_cards_fit_pack(ui, context: String) -> void:
    var board: Control = ui.board
    expect(board != null, context + " has a board")
    var parchment: Control = null
    if ui.sheet != null:
        parchment = ui.sheet.find_child("PaperClip", true, false)
        if parchment == null:
            parchment = ui.sheet
    for weapon_id in ui.weapon_ids():
        var card: Control = ui.cards.get(weapon_id, null)
        expect(card != null, context + " has a fully visible card for " + weapon_id)
        if card == null:
            continue
        expect(card.size.x >= 160.0 and card.size.y >= 180.0, context + " " + weapon_id + " keeps a full card, not a clipped strip")
        expect_global_inside(card, board, context + " " + weapon_id + " card in board")
        if parchment != null:
            expect_global_inside(card, parchment, context + " " + weapon_id + " card in parchment")
        var hint: Label = card.find_child("CardHint", true, false)
        var stats: Label = card.find_child("CardStats", true, false)
        if hint != null and not str(hint.text).is_empty():
            expect_inside(hint, card, context + " " + weapon_id + " hint stays in card", 6.0)
        if stats != null and not str(stats.text).is_empty():
            expect_inside(stats, card, context + " " + weapon_id + " stats stay in card", 6.0)
    var row_y: float = -1.0
    var row_h: float = -1.0
    for weapon_id in ui.weapon_ids():
        var card: Control = ui.cards.get(weapon_id, null)
        if card == null:
            continue
        if row_y < 0.0:
            row_y = card.position.y
            row_h = card.size.y
        expect(is_equal_approx(card.position.y, row_y), context + " " + weapon_id + " stays in the same bottom row")
        expect(is_equal_approx(card.size.y, row_h) and is_equal_approx(card.size.x, ui.cards[ui.weapon_ids()[0]].size.x), context + " " + weapon_id + " keeps a uniform card size")
        expect(card.position.y + card.size.y <= board.size.y + 1.5, context + " " + weapon_id + " sits on the bottom row")
    if ui.has_method("result_control"):
        for recipe in (ui._active_recipes() if ui.has_method("_active_recipes") else []):
            var node: Control = ui.result_control(str(recipe.get("id", "")))
            if node == null:
                continue
            expect_global_inside(node, board, context + " result " + str(recipe.get("id", "")) + " in board")
            if parchment != null:
                expect_global_inside(node, parchment, context + " result " + str(recipe.get("id", "")) + " in parchment")
    var mids: Array = []
    _collect_named(ui, "LinkDetails", mids)
    _collect_named(ui, "LinkTooltip", mids)
    for mid in mids:
        if mid is Control and mid.visible:
            expect_global_inside(mid, board, context + " tooltip in board")
            if parchment != null:
                expect_global_inside(mid, parchment, context + " tooltip in parchment")

func _collect_named(node: Node, wanted: String, result: Array) -> void:
    if node.name == wanted:
        result.append(node)
    for child in node.get_children():
        _collect_named(child, wanted, result)

func _label_with_text(root: Node, wanted: String) -> Label:
    if root is Label and str(root.text).contains(wanted):
        return root
    for child in root.get_children():
        var found: Label = _label_with_text(child, wanted)
        if found != null:
            return found
    return null

func _mid_for_recipe(mids: Array, recipe: Dictionary) -> Control:
    var name: String = str(recipe.get("name", ""))
    var benefit: String = Catalog.benefit_text(recipe)
    for mid in mids:
        if mid == null or not (mid is Control):
            continue
        if _label_with_text(mid, name) != null and _label_with_text(mid, benefit) != null:
            return mid
    return null

func assert_pack_copy_visible(ui, context: String) -> void:
    var copy: String = ui.displayed_text()
    for weapon_id in ui.weapon_ids():
        var info: Dictionary = ui.node_info(weapon_id)
        var card: Control = ui.cards.get(weapon_id, null)
        expect(card != null, context + " has a card for " + weapon_id)
        if card == null:
            continue
        var hint: Label = card.find_child("CardHint", true, false)
        var expected_hint: String = "已联动" if bool(info.get("linked", false)) else str(info.get("hint", ""))
        if not expected_hint.is_empty():
            expect(copy.contains(expected_hint), context + " displayed_text includes the hint for " + weapon_id)
            expect_label_visible(hint, expected_hint, context + " " + weapon_id + " hint")
            expect_inside(hint, card, context + " " + weapon_id + " hint in card", 6.0)
        var stats: Label = card.find_child("CardStats", true, false)
        if stats != null and not str(stats.text).is_empty():
            expect_label_visible(stats, str(info.get("stats", "")), context + " " + weapon_id + " stats")
            expect_inside(stats, card, context + " " + weapon_id + " stats in card", 6.0)
    var recipes: Array = ui._active_recipes() if ui.has_method("_active_recipes") else []
    if recipes.is_empty() and ui.has_method("_active_recipe"):
        var recipe: Dictionary = ui._active_recipe()
        if not recipe.is_empty() and str(recipe.get("id", "none")) != "none":
            recipes = [recipe]
    if recipes.is_empty():
        assert_cards_fit_pack(ui, context)
        return
    for recipe in recipes:
        var link_id: String = str(recipe.get("id", ""))
        var name: String = str(recipe.get("name", ""))
        expect(copy.contains(name), context + " displayed_text includes the result name " + name)
        expect(not copy.contains(Catalog.benefit_text(recipe)) and not copy.contains(Catalog.cost_text(recipe)), context + " official benefit and cost stay off the resident pack for " + link_id)
        var node: Control = ui.result_control(link_id) if ui.has_method("result_control") else null
        expect(node != null, context + " hangs a result node for " + link_id)
        if node != null:
            var name_label: Label = _label_with_text(node, name)
            expect(name_label != null and name_label.text.contains(name), context + " result node shows " + name)
        ui.hover_result(link_id)
        await process_frame
        var tip: String = ui.tooltip_text()
        var mid: Control = ui.tooltip
        expect(tip.contains(name) and tip.contains("优点") and tip.contains("缺点"), context + " hover tooltip for " + link_id + " shows title, 优点, and 缺点")
        expect(tip.contains(Catalog.benefit_text(recipe)) and tip.contains(Catalog.cost_text(recipe)), context + " hover tooltip uses official " + link_id + " benefit and cost")
        if mid != null and is_instance_valid(mid):
            var benefit_label: Label = mid.find_child("ClusterBenefit", true, false)
            var cost_label: Label = mid.find_child("ClusterCost", true, false)
            var benefit_title: Label = _label_with_text(mid, "优点")
            var cost_title: Label = _label_with_text(mid, "缺点")
            expect_label_visible(benefit_label, Catalog.benefit_text(recipe), context + " tooltip benefit " + link_id)
            expect_label_visible(cost_label, Catalog.cost_text(recipe), context + " tooltip cost " + link_id)
            for label in [benefit_label, cost_label, benefit_title, cost_title]:
                if label != null:
                    expect_inside(label, mid, context + " " + str(label.name) + " in tooltip", 4.0)
        ui.hide_result_tooltip()
        await process_frame
    assert_cards_fit_pack(ui, context)

func check_copy_not_clipped() -> void:
    var world = make_world("layout")
    world.start_run(true)
    expect(world.open_link_pack(), "pack opens for a six-weapon layout check")
    var ui = pack(world)
    await process_frame
    await process_frame
    await assert_pack_copy_visible(ui, "six-weapon trial unlinked")
    var rune: Dictionary = ui.try_drop("powder", "staff")
    expect(rune.get("ok", false) and world.active_link["id"] == "rune_shell", "layout check can form 魔法炮")
    await process_frame
    await process_frame
    await assert_pack_copy_visible(ui, "after linking rune_shell")
    ui.hover_result("rune_shell")
    await process_frame
    expect(ui.tooltip_text().contains("魔法杖停止独立发射，火药筒装填间隔增加50%"), "魔法炮 cost is complete, not cut at 火")
    ui.hide_result_tooltip()
    var second: Dictionary = ui.try_drop("staff", "sling")
    expect(second.get("ok", false) and world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "layout check can add 符能弹 beside 魔法炮")
    await process_frame
    await process_frame
    await assert_pack_copy_visible(ui, "after linking rune_shell and rune_sling")
    ui.hover_result("rune_sling")
    await process_frame
    expect(ui.tooltip_text().contains("石弹附上符能，命中时额外爆发魔力"), "符能弹 benefit stays complete in the hover tooltip")
    ui.hide_result_tooltip()
    var spokes: Array = ui.connection_pairs()
    expect(_has_connection(spokes, "staff", "powder") and _has_connection(spokes, "staff", "sling"), "shared catalyst keeps a separate rope to each host")
    expect(not _has_connection(spokes, "powder", "sling"), "no connection bar is drawn between powder and sling, which are not a recipe pair")
    for leftover_id in ["club", "axe", "blade"]:
        var leftover: Control = ui.cards.get(leftover_id, null)
        expect(leftover != null and leftover.size.y >= 180.0, leftover_id + " remains a full leftover card after 魔法炮 and 符能弹")
    var chain: Dictionary = ui.try_drop("powder", "axe")
    expect(chain.get("ok", false) and world.has_active_link("chain_axe") and not world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "layout check replaces only the conflicting powder recipe and keeps 符能弹")
    await process_frame
    await process_frame
    await assert_pack_copy_visible(ui, "after linking chain_axe")
    ui.hover_result("chain_axe")
    await process_frame
    expect(ui.tooltip_text().contains("石斧从火药筒炮口弹出并弹射往返"), "锁链石斧 benefit is complete")
    expect(ui.tooltip_text().contains("石斧不再环绕护身，火药筒不发普通炮弹；射程缩至210"), "锁链石斧 cost is complete, not cut at 火药筒")
    ui.hide_result_tooltip()
    for key in Catalog.LINK_ORDER:
        if key == "none":
            continue
        var recipe: Dictionary = Catalog.LINKS[key]
        var mid: Panel = ui.make_link_details(recipe)
        mid.position = Vector2(-2400, 0)
        ui.add_child(mid)
        await process_frame
        var benefit: String = Catalog.benefit_text(recipe)
        var cost: String = Catalog.cost_text(recipe)
        var name_label: Label = mid.find_child("ClusterName", true, false)
        var benefit_label: Label = mid.find_child("ClusterBenefit", true, false)
        var cost_label: Label = mid.find_child("ClusterCost", true, false)
        expect_label_visible(name_label, str(recipe.get("name", "")), "official " + key + " name")
        expect_label_visible(benefit_label, benefit, "official " + key + " benefit")
        expect_label_visible(cost_label, cost, "official " + key + " cost")
        expect_inside(benefit_label, mid, "official " + key + " benefit in mid", 4.0)
        expect_inside(cost_label, mid, "official " + key + " cost in mid", 4.0)
        mid.queue_free()
        await process_frame
    world.close_link_pack()
    world.queue_free()
    await process_frame

func check_multiple_links() -> void:
    var world = make_world("multi")
    world.start_run(true)
    expect(world.open_link_pack(), "pack opens for a multi-link trial")
    var ui = pack(world)
    var first: Dictionary = ui.try_drop("powder", "staff")
    expect(first.get("ok", false) and world.has_active_link("rune_shell"), "first compatible drop still enables 魔法炮")
    var added: Dictionary = ui.try_drop("staff", "sling")
    expect(added.get("ok", false) and bool(added.get("added", false)), "a second compatible catalyst drop is added, not swapped")
    expect(world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "staff can enchant both powder and sling at once")
    expect(str(added.get("toast", "")).contains("符能弹") and not str(added.get("toast", "")).contains("改为"), "adding a coexisting recipe does not use the old replace toast")
    expect(world.is_weapon_suppressed("staff"), "staff stays suppressed while attached to several hosts")
    var keep: Dictionary = ui.try_unlink("sling")
    expect(keep.get("ok", false) and world.has_active_link("rune_shell") and not world.has_active_link("rune_sling"), "unlinking one pair keeps the other active links")
    expect(str(keep.get("toast", "")).contains("符能弹"), "unlinking names only the disconnected recipe")
    var restored: Dictionary = ui.try_drop("staff", "sling")
    expect(restored.get("ok", false) and world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "the unlinked pair can be attached again beside the first")
    var blocked: Dictionary = ui.try_drop("club", "blade")
    expect(not blocked.get("ok", true) and world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "an incompatible drop still leaves every active link unchanged")
    var swapped: Dictionary = ui.try_drop("powder", "axe")
    expect(swapped.get("ok", false) and bool(swapped.get("swapped", false)), "powder chain conflicts with 魔法炮 and replaces only that recipe")
    expect(world.has_active_link("chain_axe") and not world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "锁链石斧 can run beside 符能弹 after replacing 魔法炮")
    expect(str(swapped.get("toast", "")).contains("魔法炮") and str(swapped.get("toast", "")).contains("锁链石斧"), "conflict toast still names the replaced powder recipes")
    world.close_link_pack()
    world.queue_free()
    await process_frame

func check_save_multi_links() -> void:
    var world = make_world("save_multi")
    world.start_run(true)
    expect(world.open_link_pack(), "pack opens before saving several links")
    var ui = pack(world)
    ui.try_drop("powder", "staff")
    ui.try_drop("staff", "sling")
    world.close_link_pack()
    var captured: Dictionary = world.SessionState.capture(world)
    expect(captured.get("link_id", "") in ["rune_shell", "rune_sling"], "old single link_id remains valid in a multi-link save")
    expect(captured.get("link_ids", []).has("rune_shell") and captured.get("link_ids", []).has("rune_sling"), "saves store every active link id")
    world.start_run(true)
    expect(world.active_link_ids().is_empty(), "a new trial starts with no links")
    expect(world.SessionState.apply(world, captured), "a multi-link save can be restored")
    expect(world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "restoring a multi-link save keeps both recipes")
    var legacy: Dictionary = captured.duplicate(true)
    legacy.erase("link_ids")
    legacy["link_id"] = "rune_shell"
    world.start_run(true)
    expect(world.SessionState.apply(world, legacy), "an old single-link save still loads")
    expect(world.has_active_link("rune_shell") and world.active_link_ids().size() == 1, "legacy link_id becomes one active link, ready for more")
    world.queue_free()
    await process_frame

func check_discovery_still_works() -> void:

    var world = make_world("discover")
    world.start_run(false)
    expect(world.active_link["id"] == "none", "a normal run still defaults to 不联动")
    expect(world.pending_link_notice.size() > 0, "starter weapon still queues unseen recipes")
    expect(world.open_link_pack() and world.link_pack_open, "the pack can open in combat before a discovery parchment")
    world.close_link_pack()
    expect(not world.link_pack_open, "the pack closes before the discovery parchment is shown")
    var shown: bool = world.try_present_link_discovery()
    expect(shown and world.link_notice_open and world.hud.screen == "link_discover", "first-acquire parchment still appears")
    expect(world.active_link["id"] == "none", "discovery still does not auto-enable a link")
    expect(not world.open_link_pack() and not world.link_pack_open, "Q does not open the pack over the discovery parchment")
    var body: String = overlay_text(world.hud.overlay)
    expect(body.contains("优点") and body.contains("缺点"), "discovery still lists benefit and cost")
    world.hud.cancel_link_discovery()
    expect(not world.link_notice_open and world.active_link["id"] == "none", "declining discovery still leaves 不联动")
    world.queue_free()
    await process_frame

func check_help_and_hints() -> void:
    var world = make_world("help")
    world.start_run(true)
    var hint: String = world.link_hint_text()
    expect(hint.contains("背包") and hint.contains("拖"), "bottom hint teaches the backpack drag")
    expect(not hint.contains("按 Q 切换") and not hint.contains("按 %s 切换" % KeyBindings.caption_for("link")) and not hint.contains("切换（当前"), "bottom hint no longer talks about Q cycling")
    world.hud.show_help("gameplay", true)
    var gameplay: String = overlay_text(world.hud.overlay)
    expect(gameplay.contains("武器背包") and gameplay.contains("拖到一起"), "gameplay help opens the pack and explains dragging")
    expect(not gameplay.contains("切换联动"), "gameplay help no longer says Q cycles recipes")
    world.hud.show_help("keys", true)
    var keys: String = overlay_text(world.hud.overlay)
    expect(keys.contains("打开武器背包"), "keys help says the link key opens the pack")
    expect(not keys.contains("切换武器联动"), "keys help no longer says the link key cycles recipes")
    world.hud.show_help("links", true)
    var links: String = overlay_text(world.hud.overlay)
    expect(links.contains("火药筒") and links.contains("炮口") and links.contains("武器背包"), "link help still teaches cannon-muzzle chains and now the pack")
    expect(links.contains("拖到一起") and links.contains("拖开") and links.contains("这两件武器不能联动"), "link help explains drag-to-link, drag-apart, and the error")
    expect(not links.contains("在「不联动」和联动之间切换") and not links.contains("可用 %s 切换或关闭" % KeyBindings.caption_for("link")), "link help no longer describes Q cycling")
    world.hud.hide_menu()
    world.close_link_pack()
    world.queue_free()
    await process_frame

func check_blocked_screens() -> void:
    var world = make_world("blocked")
    expect(not world.open_link_pack() and not world.link_pack_open, "the pack does not open on the title screen")
    world.start_run(true)
    world.toggle_pause()
    expect(world.paused and world.hud.screen == "pause", "pause menu is available")
    expect(not world.open_link_pack() and not world.link_pack_open, "the pack does not open over the pause menu")
    world.toggle_pause()
    world.shop_open = true
    world.player_frozen = true
    world.hud.show_shop([{"id": "heal", "price": 1, "level": 1}], 10, 1, world.inventory, {}, world.player_hp, world.stats["max_hp"], false)
    expect(not world.open_link_pack() and world.hud.screen == "shop", "the pack does not open over the shop")
    world.shop_open = false
    world.hud.hide_menu()
    world.player_frozen = false
    expect(world.open_link_pack(), "pack opens again in combat")
    world.open_round_shop()
    expect(not world.link_pack_open and world.shop_open, "opening the shop dismisses the pack first")
    world.queue_free()
    await process_frame

func textures_match(a: Texture2D, b: Texture2D) -> bool:
    if a == b and a != null:
        return true
    if a == null or b == null:
        return false
    var ia: Image = a.get_image()
    var ib: Image = b.get_image()
    if ia == null or ib == null:
        return false
    return ia.get_width() == ib.get_width() and ia.get_height() == ib.get_height() and ia.get_data() == ib.get_data()

func set_owned_level(world, weapon_id: String, level: int) -> void:
    for item in world.inventory:
        if str(item.get("id", "")) == weapon_id:
            item["level"] = level
            return

func check_upgraded_appearance() -> void:
    var world = make_world("looks")
    world.start_run(true)
    set_owned_level(world, "staff", 5)
    set_owned_level(world, "powder", 3)
    set_owned_level(world, "club", 1)
    expect(world.open_link_pack(), "pack opens to inspect upgraded weapon art")
    var ui = pack(world)
    await process_frame
    await process_frame
    expect(ui.appearance_level("staff") == 5 and ui.appearance_level("powder") == 3 and ui.appearance_level("club") == 1, "pack reads each weapon's current upgrade level")
    var staff_icon: TextureRect = ui.card_icon("staff")
    var powder_icon: TextureRect = ui.card_icon("powder")
    var club_icon: TextureRect = ui.card_icon("club")
    expect(staff_icon != null and powder_icon != null and club_icon != null, "each pack card has a weapon icon")
    var staff_now: Texture2D = world.library.weapon_texture("staff", 5)
    var staff_base: Texture2D = world.library.weapon_texture("staff", 1)
    var powder_now: Texture2D = world.library.weapon_texture("powder", 3)
    var powder_base: Texture2D = world.library.weapon_texture("powder", 1)
    var club_now: Texture2D = world.library.weapon_texture("club", 1)
    expect(textures_match(staff_icon.texture, staff_now), "staff card uses the current level-5 evolved appearance")
    expect(not textures_match(staff_icon.texture, staff_base), "staff card does not keep the basic appearance after it has evolved")
    expect(textures_match(powder_icon.texture, powder_now), "powder card uses the current level-3 evolved appearance")
    expect(not textures_match(powder_icon.texture, powder_base), "powder card does not stay on the basic icon at level 3")
    expect(textures_match(club_icon.texture, club_now), "unevolved club still uses the basic appearance")
    if staff_icon.texture != null:
        var sample: Image = staff_icon.texture.get_image()
        if sample != null:
            var corner: Color = sample.get_pixel(0, 0)
            expect(corner.a < 0.08, "pack weapon icons keep transparent corners, without a baked black matte")
    world.close_link_pack()
    world.queue_free()
    await process_frame

func check_reorder_and_persist() -> void:
    var world = make_world("order")
    world.start_run(true)
    expect(world.open_link_pack(), "pack opens for reorder checks")
    var ui = pack(world)
    var before: Array = ui.weapon_ids().duplicate()
    expect(before.size() >= 6, "trial pack still has six weapons to rearrange")
    var first: String = str(before[0])
    var last: String = str(before[before.size() - 1])
    var mid: String = str(before[2])
    ui.try_drop("powder", "staff")
    ui.try_drop("staff", "sling")
    expect(world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "links are in place before reordering")
    var moved: Dictionary = ui.try_reorder_after(first, last)
    expect(moved.get("ok", false) and not moved.get("unchanged", true), "dragging to the far edge moves a weapon to the end")
    var after_move: Array = ui.weapon_ids()
    expect(str(after_move.back()) == first and after_move.find(first) == after_move.size() - 1, "the moved weapon is now last in the pack")
    expect(world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "reordering does not break existing links")
    var inserted: Dictionary = ui.try_reorder_before(last, mid)
    expect(inserted.get("ok", false), "a weapon can be inserted before another card")
    var ordered: Array = ui.weapon_ids()
    expect(ordered.find(last) == ordered.find(mid) - 1, "insertion lands immediately before the target card")
    expect(world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "insertion still leaves both links intact")
    world.close_link_pack()
    expect(world.open_link_pack(), "pack can close and reopen after a reorder")
    ui = pack(world)
    expect(ui.weapon_ids() == ordered, "closing and reopening the pack keeps the new order")
    var captured: Dictionary = world.SessionState.capture(world)
    var saved_ids: Array = []
    for item in captured.get("inventory", []):
        saved_ids.append(str(item.get("id", "")))
    expect(saved_ids == ordered, "the run save stores the rearranged inventory order")
    world.start_run(true)
    expect(world.SessionState.apply(world, captured), "the rearranged save can be restored")
    expect(world.open_link_pack(), "restored run can open the pack")
    ui = pack(world)
    expect(ui.weapon_ids() == ordered, "restoring a save keeps the rearranged weapon order")
    expect(world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "restored links survive the order change")
    world.close_link_pack()
    world.queue_free()
    await process_frame

func check_drop_face_vs_edge() -> void:
    var world = make_world("intent")
    world.start_run(true)
    expect(world.open_link_pack(), "pack opens for drop-intent checks")
    var ui = pack(world)
    await process_frame
    await process_frame
    var before: Array = ui.weapon_ids().duplicate()
    var face: Dictionary = ui.drop_at("club", ui.card_face_point("staff"))
    expect(not face.get("ok", true) and str(face.get("kind", "")) == "link", "dropping onto a card face tries to link, even when the pair is incompatible")
    expect(ui.error_text().contains("这两件武器不能联动"), "an incompatible face drop still shows the toast")
    expect(ui.weapon_ids() == before, "an incompatible face drop does not reorder the row")
    var linked: Dictionary = ui.drop_at("powder", ui.card_face_point("staff"))
    expect(linked.get("ok", false) and str(linked.get("kind", "")) == "link" and world.has_active_link("rune_shell"), "dropping onto a compatible card face forms the recipe")
    var order_before: Array = ui.weapon_ids().duplicate()
    var edge: Dictionary = ui.drop_at("club", ui.card_edge_point("axe", "after"))
    expect(str(edge.get("kind", "")) == "reorder" and edge.get("ok", false), "dropping onto a card edge reorders instead of linking")
    expect(world.has_active_link("rune_shell"), "an edge reorder leaves the existing link in place")
    expect(ui.weapon_ids() != order_before, "the edge drop actually changes the stored order")
    var second: Dictionary = ui.drop_at("staff", ui.card_face_point("sling"))
    expect(second.get("ok", false) and world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "a later face drop can still add a second catalyst link")
    var sling_card = ui.cards.get("sling", null)
    expect(sling_card != null, "sling card is present before a drag-apart")
    if sling_card != null:
        var away: Vector2 = sling_card.get_global_rect().get_center() + Vector2(0, -180)
        var unlinked: Dictionary = ui.drop_at("sling", away)
        expect(str(unlinked.get("kind", "")) == "unlink" and unlinked.get("ok", false), "dragging a linked weapon off the rope unlinks that branch")
        expect(world.has_active_link("rune_shell") and not world.has_active_link("rune_sling"), "drag-apart disconnects only the moved branch")
    world.close_link_pack()
    world.queue_free()
    await process_frame

func check_restack_cancel_and_host_enchant() -> void:
    var world = make_world("restack")
    world.start_run(true)
    expect(world.open_link_pack(), "pack opens for restack-cancel checks")
    var ui = pack(world)
    await process_frame
    var formed: Dictionary = ui.try_drop("powder", "staff")
    expect(formed.get("ok", false) and world.has_active_link("rune_shell"), "first drop still forms 魔法炮")
    var cancelled: Dictionary = ui.try_drop("staff", "powder")
    expect(cancelled.get("ok", false) and bool(cancelled.get("cancelled", false)), "dropping an already-linked pair onto each other cancels that recipe")
    expect(not world.has_active_link("rune_shell") and world.active_link_ids().is_empty(), "restacking disconnects 魔法炮")
    expect(str(cancelled.get("toast", "")).contains("断开") or ui.toast_text().contains("断开"), "the cancel toast says the recipe was disconnected")
    expect(ui.try_drop("powder", "staff").get("ok", false) and world.has_active_link("rune_shell"), "the same pair can be linked again after a cancel")
    ui.try_drop("staff", "sling")
    expect(world.has_active_link("rune_shell") and world.has_active_link("rune_sling"), "staff can still enchant two hosts at once")
    var only_one: Dictionary = ui.try_drop("staff", "sling")
    expect(only_one.get("ok", false) and bool(only_one.get("cancelled", false)), "restacking a catalyst onto one of its hosts cancels only that branch")
    expect(world.has_active_link("rune_shell") and not world.has_active_link("rune_sling"), "cancelling 符能弹 leaves 魔法炮 in place")
    ui.try_drop("staff", "sling")
    var sling_card = ui.cards.get("sling", null)
    expect(sling_card != null, "sling card is present for a drag-apart after the restack")
    if sling_card != null:
        var away: Vector2 = sling_card.get_global_rect().get_center() + Vector2(0, -180)
        var unlinked: Dictionary = ui.drop_at("sling", away)
        expect(str(unlinked.get("kind", "")) == "unlink" and unlinked.get("ok", false), "dragging a linked host off the row still unlinks that branch")
        expect(world.has_active_link("rune_shell") and not world.has_active_link("rune_sling"), "drag-apart still disconnects only the moved branch")
    world.close_link_pack()
    world.start_run(false)
    expect(world.grant_weapon("powder") and world.grant_weapon("staff") and world.grant_weapon("firepot") and world.grant_weapon("sling"), "a regular run can own powder, staff, firepot, and sling")
    expect(world.open_link_pack(), "pack opens with a mixed enchant loadout")
    ui = pack(world)
    await process_frame
    expect(ui.try_drop("powder", "staff").get("ok", false) and world.has_active_link("rune_shell"), "staff first enchants the cannon")
    var swapped: Dictionary = ui.try_drop("firepot", "powder")
    expect(swapped.get("ok", false) and world.has_active_link("fire_cannon") and not world.has_active_link("rune_shell"), "giving the same cannon a fire enchantment drops the staff link")
    expect(str(swapped.get("toast", "")).contains("魔法炮") and str(swapped.get("toast", "")).contains("烈焰火炮"), "the replace toast names the old and new enchantments")
    var moved: Dictionary = ui.try_drop("staff", "sling")
    expect(moved.get("ok", false) and world.has_active_link("fire_cannon") and world.has_active_link("rune_sling"), "the displaced staff can enchant another weapon")
    expect(not world.has_active_link("rune_shell"), "the cannon keeps only the new fire enchantment")
    world.close_link_pack()
    world.queue_free()
    await process_frame
