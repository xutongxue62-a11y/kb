extends SceneTree

const Growth = preload("res://src/growth.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("run")

func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)

func verify_cards(hud, prefix: String, ids: Array, min_height: float, hide_buff_notes: bool = false) -> void:
    for i in range(ids.size()):
        var card: Button = hud.find_child("%s%d" % [prefix, i], true, false)
        var rows: Array[Control] = []
        var copy := ""
        for node in card.get_children():
            if node is Label or node is TextureRect or node is HBoxContainer:
                rows.append(node)
                expect(absf(node.get_rect().get_center().x - card.size.x * 0.5) <= 1.0,
                    "%s %s %s copies the card center: %s" % [prefix, ids[i], node.text if node is Label else node.name,node.get_rect()])
                expect(card.get_rect().size.x >= node.size.x, "%s %s row fits width" % [prefix, ids[i]])
                if node is Label:
                    copy += node.text + "\n"
                if node is HBoxContainer:
                    var contents: Rect2 = Rect2(node.get_child(0).position, node.get_child(0).size)
                    for part in node.get_children():
                        contents = contents.merge(part.get_rect())
                    expect(absf(contents.get_center().x - card.size.x * 0.5) <= 1.5, "%s %s title text is centered" % [prefix, ids[i]])
        rows.sort_custom(func(a, b): return a.position.y < b.position.y)
        for j in range(1, rows.size()):
            expect(rows[j - 1].get_rect().end.y <= rows[j].position.y + 0.5,
                "%s %s rows touch: %s / %s" % [prefix, ids[i], rows[j - 1].get_rect(), rows[j].get_rect()])
        expect(rows[0].position.y >= 8.0, "%s %s title clears the top edge" % [prefix, ids[i]])
        expect(rows[-1].get_rect().end.y <= card.size.y - min_height,
            "%s %s final row clears the paper edge" % [prefix, ids[i]])
        var icon: TextureRect = card.get_node_or_null("OfferIcon")
        expect(icon != null and icon.texture != null, "%s %s has an illustrated icon" % [prefix, ids[i]])
        if hide_buff_notes and Growth.BUFFS.has(ids[i]):
            expect(not copy.contains("无限叠加") and not copy.contains("不占武器槽"), "%s %s omits generic attribute copy" % [prefix, ids[i]])

func settle() -> void:
    await process_frame
    await process_frame
    await process_frame

func run() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("user://tests/offer_centering")
    root.add_child(world)
    world.set_physics_process(false)
    root.size = Vector2i(1280, 720)
    var ids: Array = world.Catalog.WEAPONS.keys() + world.Growth.BUFFS.keys() + ["heal"]
    for start in range(0, ids.size(), 6):
        var stock: Array = []
        var keys: Array = ids.slice(start, start + 6)
        for id in keys:
            stock.append({"id":id,"price":20,"level":3} if world.Catalog.WEAPONS.has(id) else {"id":id,"price":20})
        world.hud.show_shop(stock, 100, 2, [], {}, 6.9, 8.0, false)
        await settle()
        verify_cards(world.hud, "ShopOffer", keys, 5.0, true)
    var chest := ["staff","explorer","vitality","area","drone","pet"]
    world.hud.show_choices(chest, [], {}, "chest", 4, {"staff":3})
    await settle()
    verify_cards(world.hud, "GrowthOffer", chest, 2.0, true)
    var growth := ["staff","regen","armor"]
    world.hud.show_choices(growth, [{"id":"staff","level":2}], {}, "xp", 4)
    await settle()
    verify_cards(world.hud, "GrowthOffer", growth, 5.0, true)
    var keys := ["totem","powder","spear","crystal","axe","staff"]
    var inventory := keys.map(func(key): return {"id":key,"level":3})
    world.hud.show_replace({"id":"boomerang","level":1,"price":22,"source":"shop"},inventory,4)
    await settle()
    verify_cards(world.hud, "ReplaceSlot", keys, 5.0)
    var sheet: Control = world.hud.overlay.get_node("HanddrawnPaper")
    expect(sheet.position.y + sheet.size.y <= 792.0, "replacement scroll fits the logical viewport")
    world.hud.choose_replace_slot("totem")
    await settle()
    for name in ["IncomingCompare","OutgoingCompare"]:
        var panel: Button = world.hud.find_child(name, true, false)
        expect(panel != null and panel.get_node_or_null("InkFeedback") != null, name + " uses the parchment skin")
    world.queue_free()
    await process_frame
    print("OFFER CENTERING RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
