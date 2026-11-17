extends RefCounted
const Evolution = preload("res://src/weapon_evolution.gd")
const Growth = preload("res://src/growth.gd")
const Catalog = preload("res://src/catalog.gd")
const Economy = preload("res://src/economy.gd")
const SupportArt = preload("res://src/support_art.gd")
const Details = preload("res://src/ui_weapon_details.gd")
const BuffDetails = preload("res://src/ui_buff_details.gd")

static func text(h, parent: Node, value: String, rect: Rect2, size: int, color: Color = Color("#263546"),bold: bool=false) -> Label:
    var node: Label = h.make_display(value,size,color) if bold else h.make_label(value,size,color)
    node.position = rect.position
    node.size = rect.size
    node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(node)
    return node

static func art(h,parent: Node,key: String,rect: Rect2,level: int=1) -> void:
    if Catalog.WEAPONS.has(key) or key in ["pet","drone"]:
        var node := TextureRect.new()
        node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        node.texture = SupportArt.texture(key) if key in ["pet","drone"] else h.library.weapon_texture(key,level)
        node.material = h.library.weapon_material if Catalog.WEAPONS.has(key) else null
        node.position = rect.position
        node.size = rect.size
        node.mouse_filter = Control.MOUSE_FILTER_IGNORE
        parent.add_child(node)
    else:
        var glyph: String = str(Growth.BUFFS[key].glyph) if Growth.BUFFS.has(key) else "心"
        text(h,parent,glyph,rect,43,Growth.BUFFS[key].color if Growth.BUFFS.has(key) else Color("#ac6e58"))

static func card(h,parent: Node,key: String,size: Vector2) -> Button:
    var node: Button = h.make_button("")
    node.custom_minimum_size = size
    node.size = size
    h.paint_offer_card(node,h.offer_kind(key))
    node.set_meta("ink_weapon",Catalog.WEAPONS.has(key))
    node.tooltip_text = ""
    parent.add_child(node)
    return node

static func growth(h,ids: Array,inventory: Array,levels: Dictionary,reason: String, offer_levels: Dictionary = {},stage: int=1) -> void:
    var compact: bool=ids.size()>3
    var column: VBoxContainer = h.parchment_column(1068,22 if compact else 82)
    column.get_meta("scroll_frame").reward_style=true
    column.add_theme_constant_override("separation",8)
    var heading: Label = h.make_display("精英宝箱 · 选择奖励" if reason == "chest" else "选择成长",30)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    var shortcut: String="1–6" if compact else "1 / 2 / 3"
    var hint: Label = h.make_label("选择 1 份 · 点击纸卡领取 / %s · 或出售该份奖励，保留现有装备" % shortcut,16,Color("#65704f"))
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(hint)
    var grid := GridContainer.new()
    grid.columns=maxi(1,mini(3,ids.size()))
    grid.add_theme_constant_override("h_separation",18)
    grid.add_theme_constant_override("v_separation",12)
    grid.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
    column.add_child(grid)
    for i in range(ids.size()):
        var key: String = ids[i]
        var data: Dictionary = Growth.BUFFS[key] if Growth.BUFFS.has(key) else Catalog.WEAPONS[key]
        var cell:=VBoxContainer.new()
        cell.add_theme_constant_override("separation",7)
        grid.add_child(cell)
        var item: Button = card(h,cell,key,Vector2(300,250 if compact else 344))
        item.name = "GrowthOffer%d" % i
        item.set_meta("ink_reward",true)
        # Reward cards share neutral paper; identity comes from the original icon and text.
        var face: StyleBoxFlat=h.style(Color("#f0e3c9"),Color("#8e714a"))
        for state in ["normal","hover","pressed"]: item.add_theme_stylebox_override(state,face.duplicate())
        item.pressed.connect(func(): h._choose(key))
        var level: int = Growth.item_level(key,inventory,levels)
        var weapon: bool=Catalog.WEAPONS.has(key)
        var shown: int = clampi(int(offer_levels.get(key, 1)),1,Growth.MAX_WEAPON_LEVEL) if level==0 and weapon else level+1
        var title: Label=text(h,item,"%d · %s" % [i+1,data.name],Rect2(12,10,276,36),24 if compact else 27)
        if h.display_font!=null: title.add_theme_font_override("font",h.display_font)
        var top_level: String=("Lv.%d → Lv.%d" % [level,shown] if level>0 else Growth.weapon_level_text(shown)) if weapon else "层数 %d → %d" % [level,shown]
        text(h,item,top_level,Rect2(12,47,276,27),21,Color("#7d432c"),true)
        art(h,item,key,Rect2(16,79,64,58) if compact else Rect2(106,79,88,72),maxi(1,shown))
        var attack_type: String=Details.attack_type(key) if weapon else BuffDetails.headline(key)
        text(h,item,attack_type,Rect2(90,73,198,23) if compact else Rect2(12,158,276,27),15 if compact else 19,Color("#704127"),true)
        var replace_offer: bool = weapon and level==0 and inventory.size() >= 6
        var status: String
        if weapon and level>0:
            status = "直接升级 · 不占新槽"
        elif replace_offer:
            status = "槽位已满 · 需更换一件"
        elif weapon:
            status = "新武器 · 装入空槽"
        else:
            status = "直接叠加 · 不占武器槽" if level>0 else "新获得 · 不占武器槽"
        text(h,item,status,Rect2(12,214 if compact else 303,276,28),16 if compact else 18,Color("#923f29") if replace_offer else Color("#3e5439"),true)
        var body: String = BuffDetails.detail(key) if not weapon else data.description
        if weapon:
            body = Details.attack(key,shown)
        var desc_rect: Rect2=(Rect2(90,99,198,62) if compact else Rect2(19,184,262,48)) if weapon else (Rect2(90,99,198,66) if compact else Rect2(19,190,262,62))
        var desc: Label = text(h,item,body,desc_rect,16 if compact else 18)
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        if compact: desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
        if weapon:
            if compact:
                var abilities: Label=text(h,item,Details.stats_line(key,shown)+"\n"+Details.abilities(key,shown,level),Rect2(14,162,272,50),13,Color("#69533b"))
                abilities.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
            else:
                text(h,item,Details.stats_line(key,shown),Rect2(15,233,270,24),16,Color("#75442c"),true)
                var abilities: Label=text(h,item,Details.abilities(key,shown,level),Rect2(15,258,270,40),15,Color("#69533b"))
                abilities.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        else:
            text(h,item,BuffDetails.limit(key),Rect2(14,176,272,28) if compact else Rect2(14,249,272,29),18,Color("#704127"),true)
        var refund: int=Economy.reward_sell_price(key,stage,shown)
        var sell: Button=h.make_button("出售此奖励 +%d 金币" % refund,Color("#edca82"))
        sell.name="GrowthRewardSell%d" % i
        sell.set_meta("ink_reward_sale",true)
        sell.custom_minimum_size=Vector2(300,42)
        sell.add_theme_font_size_override("font_size",20)
        if h.display_font!=null: sell.add_theme_font_override("font",h.display_font)
        sell.pressed.connect(func(): h._sell_reward(key))
        cell.add_child(sell)
    h.open_parchment(column,true)

static func shop(h,stock: Array,coins: int,stage: int,inventory: Array,levels: Dictionary,hp: float,max_hp: float,animate: bool,highlight: int,reroll_cost: int = -1) -> void:
    var column: VBoxContainer=h.parchment_column(1172,8)
    column.add_theme_constant_override("separation",7)
    var heading: Label=h.make_display("营地 · 第 %d 关结束" % stage,29)
    heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    var wallet: Label=h.make_display("金币 %d · 生命 %.1f / %.0f · 选择补给，购买后准备下一关" % [coins,hp,max_hp],19,Color("#704127"))
    wallet.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(wallet)
    var grid:=GridContainer.new()
    grid.columns=3
    grid.add_theme_constant_override("h_separation",14)
    grid.add_theme_constant_override("v_separation",12)
    column.add_child(grid)
    for i in range(stock.size()):
        var offer: Dictionary=stock[i]
        var key: String=offer.id
        var weapon: bool=Catalog.WEAPONS.has(key)
        var buff: bool=Growth.BUFFS.has(key)
        var data: Dictionary=Catalog.WEAPONS[key] if weapon else (Growth.BUFFS[key] if buff else {"name":"篝火治疗","description":"恢复 3 点生命\n不超过生命上限"})
        var item: Button=card(h,grid,key,Vector2(348,268))
        item.name="ShopOffer%d" % i
        item.set_meta("ink_layout","side_icon")
        var full: bool=key=="heal" and hp>=max_hp
        var sold: bool=offer.get("sold",false)
        item.disabled=sold or coins<int(offer.price) or full
        item.modulate=Color(1,1,1,0.65) if item.disabled else Color.WHITE
        item.pressed.connect(func():
            if not h.ui_busy(): h.request_shop_buy(i))
        var new_weapon: bool=weapon and offer.has("level")
        var owned: int=Growth.item_level(key,inventory,levels)
        if sold and not new_weapon: owned=maxi(0,owned-1)
        var shown: int=clampi(int(offer.get("level",1)),1,Growth.MAX_WEAPON_LEVEL) if new_weapon else (mini(Growth.MAX_WEAPON_LEVEL,owned+1) if weapon else owned+1)
        var replace_offer: bool=new_weapon and inventory.size()>=6 and not sold
        var kind_label: String="武器" if weapon else ("属性" if buff else "补给")
        var kind_tag: Label=text(h,item,kind_label,Rect2(12,6,70,22),14,Color("#983f2b"),true)
        kind_tag.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        var title: String="%s（%s）" % [str(data.name), kind_label]
        text(h,item,title,Rect2(86,4,250,26),20,Color("#263546"),true)
        var top: String=(Growth.weapon_level_text(shown) if new_weapon or owned==0 else "Lv.%d → %d" % [owned,shown]) if weapon else ("层数 %d → %d" % [owned,shown] if buff else "恢复生命")
        text(h,item,top,Rect2(12,32,324,24),18,Color("#75442c"),true)
        var effect: String=Details.attack_type(key) if weapon else (BuffDetails.headline(key) if buff else "生命 +3")
        text(h,item,effect,Rect2(12,56,324,22),16,Color("#704127"),true)
        art(h,item,key,Rect2(16,82,64,56),maxi(1,shown))
        var body: String=Details.attack(key,shown) if weapon else (BuffDetails.detail(key) if buff else data.description)
        var desc: Label=text(h,item,body,Rect2(88,80,246,46) if weapon else Rect2(88,80,246,58),15)
        desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        desc.vertical_alignment=VERTICAL_ALIGNMENT_TOP
        if weapon:
            text(h,item,Details.stats_line(key,shown),Rect2(88,126,246,20),14,Color("#75442c"),true)
        if weapon:
            var ability: Label=text(h,item,Details.abilities(key,shown,owned),Rect2(14,148,320,36),14,Color("#59462f"))
            ability.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
            ability.vertical_alignment=VERTICAL_ALIGNMENT_TOP
        elif buff:
            text(h,item,BuffDetails.limit(key),Rect2(14,150,320,24),16,Color("#704127"),true)
        var action_text: String
        var action_hint: String
        if sold:
            action_text="已购入 · 已售罄"
            action_hint="这份补给已经结算"
        elif full:
            action_text="生命已满 · 无需购买"
            action_hint="受伤后再购买治疗"
        elif coins<int(offer.price):
            action_text="购买需 %d 金币 · 金币不足" % int(offer.price)
            action_hint="当前金币不足以购买"
        else:
            var verb: String
            if replace_offer:
                verb="购买并更换"
                action_hint="换下旧武器，可折价售回金币"
            elif weapon and owned>0:
                verb="购买升级"
                action_hint="直接升级，不占新武器槽"
            elif weapon:
                verb="购买新武器"
                action_hint="装入空槽，保留已有武器"
            elif buff:
                verb="购买并强化"
                action_hint="增加 1 层，不占武器槽"
            else:
                verb="购买治疗"
                action_hint="立即恢复 3 点生命"
            action_text="%s · %d 金币" % [verb,int(offer.price)]
        text(h,item,action_text,Rect2(12,204,324,28),18,Color("#983f2b"),true)
        text(h,item,action_hint,Rect2(12,234,324,22),14,Color("#59462f"))
    var footer:=HBoxContainer.new()
    footer.add_theme_constant_override("separation",14)
    column.add_child(footer)
    h.action(footer,"SaveNow","保存 [F5]",func():h.save_requested.emit())
    if reroll_cost >= 0:
        var reroll: Button=h.action(footer,"RerollShop","刷新货物 · %d 金币" % reroll_cost,func():h.reroll_requested.emit())
        if coins < reroll_cost:
            reroll.disabled=true
            reroll.modulate=Color(1,1,1,0.65)
    h.action(footer,"Home","返回首页",func():h.home_requested.emit())
    h.action(footer,"NextRound","准备好了 · 下一关",func():h.next_round_requested.emit(),Color("#b4583e"))
    h.open_parchment(column,animate)
    if highlight>=0 and highlight<grid.get_child_count() and h.can_animate(): h.play_ui("choice_confirm")

static func shop_confirm(h, state: Dictionary, index: int) -> void:
    var stock: Array = state.get("stock", [])
    if index < 0 or index >= stock.size():
        return
    var offer: Dictionary = stock[index]
    var key: String = str(offer.get("id", ""))
    var coins: int = int(state.get("coins", 0))
    var hp: float = float(state.get("hp", 0.0))
    var max_hp: float = float(state.get("max_hp", 8.0))
    var inventory: Array = state.get("inventory", [])
    var levels: Dictionary = state.get("levels", {})
    var stage: int = int(state.get("wave", 1))
    var weapon: bool = Catalog.WEAPONS.has(key)
    var buff: bool = Growth.BUFFS.has(key)
    var data: Dictionary = Catalog.WEAPONS[key] if weapon else (Growth.BUFFS[key] if buff else {"name": "篝火治疗"})
    var owned: int = Growth.item_level(key, inventory, levels)
    var replace_offer: bool = weapon and offer.has("level") and inventory.size() >= 6
    var verb: String = "购买治疗"
    if replace_offer:
        verb = "购买并更换"
    elif weapon and owned > 0:
        verb = "购买升级"
    elif weapon:
        verb = "购买新武器"
    elif buff:
        verb = "购买并强化"
    var kind_label: String = "武器" if weapon else ("属性" if buff else "补给")
    var shown: int = clampi(int(offer.get("level", 1)), 1, Growth.MAX_WEAPON_LEVEL) if weapon and offer.has("level") else (mini(Growth.MAX_WEAPON_LEVEL, owned + 1) if weapon else owned + 1)
    var level_text: String = ""
    if weapon:
        level_text = Growth.weapon_level_text(shown) if owned <= 0 else "Lv.%d → %s" % [owned, Growth.weapon_level_text(shown)]
    elif buff:
        level_text = "层数 %d → %d" % [owned, shown]
    var price: int = int(offer.get("price", 0))
    var facts: Array = [
        {"text": str(data.get("name", key)), "kind": "name"},
        {"text": kind_label, "kind": "type"},
    ]
    if not level_text.is_empty():
        facts.append({"text": level_text, "kind": "level"})
    facts.append({"text": "花费 %d 金币" % price, "kind": "gold"})
    var incoming_facts: Array = []
    var row_items: Array = []
    if replace_offer:
        incoming_facts = [
            {"text": "获得", "kind": "lead"},
            {"text": str(data.get("name", key)), "kind": "name"},
            {"text": Growth.weapon_level_text(shown), "kind": "level"},
            {"text": Details.stats_line(key, shown), "kind": "damage"},
            {"text": "花费 %d 金币" % price, "kind": "gold"},
        ]
        for held in inventory:
            var hid: String = str(held.get("id", ""))
            if not Catalog.WEAPONS.has(hid):
                continue
            var lv: int = int(held.get("level", 1))
            row_items.append({
                "name": Catalog.WEAPONS[hid]["name"],
                "level": Growth.weapon_level_text(lv),
                "damage": Details.stats_line(hid, lv),
                "gold": "售回 %d 金币" % Economy.sell_price(hid, stage, lv),
            })
    centered_confirm(h, {
        "heading": "确认" + verb,
        "facts": facts,
        "support": "确定要%s这个东西吗？取消返回商店，不扣费。" % verb,
        "replace": replace_offer,
        "incoming_facts": incoming_facts,
        "hint": "将与现有武器对比后更换；换下的按原价 50% 折价售回。" if replace_offer else "",
        "row_items": row_items,
        "wallet": "当前金币 %d · 生命 %.1f / %.0f" % [coins, hp, max_hp],
        "confirm": "确定" + verb,
        "on_cancel": func():
            if not h.ui_busy(): h.cancel_shop_buy(),
        "on_confirm": func():
            if not h.ui_busy(): h.confirm_shop_buy(),
    })

static func choice_confirm(h, key: String, inventory: Array, levels: Dictionary, offer_levels: Dictionary, stage: int, reason: String = "xp") -> void:
    var weapon: bool = Catalog.WEAPONS.has(key)
    var buff: bool = Growth.BUFFS.has(key)
    if not weapon and not buff:
        return
    var data: Dictionary = Catalog.WEAPONS[key] if weapon else Growth.BUFFS[key]
    var owned: int = Growth.item_level(key, inventory, levels)
    var shown: int = clampi(int(offer_levels.get(key, 1)), 1, Growth.MAX_WEAPON_LEVEL) if weapon and owned <= 0 else (mini(Growth.MAX_WEAPON_LEVEL, owned + 1) if weapon else owned + 1)
    var replace_offer: bool = weapon and owned <= 0 and inventory.size() >= 6
    var from_chest: bool = reason == "chest"
    var take: String = "领取" if from_chest else "选择"
    var verb: String = take + "属性"
    if replace_offer:
        verb = take + "并更换"
    elif weapon and owned > 0:
        verb = take + "并升级"
    elif weapon:
        verb = take + "武器"
    elif owned > 0:
        verb = take + "并强化"
    var kind_label: String = "武器" if weapon else "属性"
    var level_text: String = Growth.weapon_level_text(shown) if weapon and owned <= 0 else ("Lv.%d → %s" % [owned, Growth.weapon_level_text(shown)] if weapon else "层数 %d → %d" % [owned, shown])
    var facts: Array = [
        {"text": str(data.get("name", key)), "kind": "name"},
        {"text": kind_label, "kind": "type"},
        {"text": level_text, "kind": "level"},
    ]
    var incoming_facts: Array = []
    var row_items: Array = []
    if replace_offer:
        incoming_facts = [
            {"text": "获得", "kind": "lead"},
            {"text": str(data.get("name", key)), "kind": "name"},
            {"text": Growth.weapon_level_text(shown), "kind": "level"},
            {"text": Details.stats_line(key, shown), "kind": "damage"},
        ]
        for held in inventory:
            var hid: String = str(held.get("id", ""))
            if not Catalog.WEAPONS.has(hid):
                continue
            var lv: int = int(held.get("level", 1))
            row_items.append({
                "name": Catalog.WEAPONS[hid]["name"],
                "level": Growth.weapon_level_text(lv),
                "damage": Details.stats_line(hid, lv),
                "gold": "售回 %d 金币" % Economy.sell_price(hid, stage, lv),
            })
    var leave: String = "宝箱选择" if from_chest else "升级选择"
    var cost: String = "奖励" if from_chest else "这次升级"
    centered_confirm(h, {
        "heading": "确认" + verb,
        "facts": facts,
        "support": "确定要%s这个东西吗？取消返回%s，不会消耗%s。" % [verb, leave, cost],
        "replace": replace_offer,
        "incoming_facts": incoming_facts,
        "hint": "将与现有武器对比后更换；换下的按原价 50% 折价售回。" if replace_offer else "",
        "row_items": row_items,
        "wallet": "",
        "confirm": "确定" + verb,
        "on_cancel": func():
            if not h.ui_busy(): h.cancel_choice_confirm(),
        "on_confirm": func():
            if not h.ui_busy(): h.confirm_choice_take(),
    })

static func _confirm_fact_style(kind: String) -> Dictionary:
    match kind:
        "name":
            return {"size": 24, "color": Color("#1e2a38")}
        "type":
            return {"size": 20, "color": Color("#8a3420")}
        "level":
            return {"size": 22, "color": Color("#b03d2a")}
        "gold":
            return {"size": 22, "color": Color("#c46a14")}
        "damage":
            return {"size": 17, "color": Color("#2f5a38")}
        _:
            return {"size": 16, "color": Color("#3e5439")}

static func _confirm_fact_label(h, fact: Dictionary, named: bool = false) -> Label:
    var kind: String = str(fact.get("kind", "name"))
    var style: Dictionary = _confirm_fact_style(kind)
    var node: Label = h.make_display(str(fact.get("text", "")), int(style["size"]), style["color"])
    node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    if named:
        var names := {"name": "ConfirmFactName", "type": "ConfirmFactType", "level": "ConfirmFactLevel", "gold": "ConfirmFactGold"}
        if names.has(kind):
            node.name = str(names[kind])
    return node

static func _confirm_fact_row(h, parent: Node, facts: Array, named: bool = false) -> void:
    if facts.is_empty():
        return
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 12)
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(row)
    for fact in facts:
        if str(fact.get("text", "")).is_empty():
            continue
        row.add_child(_confirm_fact_label(h, fact, named))

static func _confirm_compare_cell(h, parent: Node, item: Dictionary, width: float) -> void:
    var cell := VBoxContainer.new()
    cell.add_theme_constant_override("separation", 0)
    cell.custom_minimum_size = Vector2(width, 0)
    cell.size_flags_horizontal = Control.SIZE_FILL
    parent.add_child(cell)
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 6)
    cell.add_child(top)
    var name_label: Label = h.make_label(str(item.get("name", "")), 14, Color("#1e2a38"))
    if h.display_font != null:
        name_label.add_theme_font_override("font", h.display_font)
    top.add_child(name_label)
    var level_label: Label = h.make_label(str(item.get("level", "")), 14, Color("#b03d2a"))
    if h.display_font != null:
        level_label.add_theme_font_override("font", h.display_font)
    top.add_child(level_label)
    var gold_text: String = str(item.get("gold", ""))
    if not gold_text.is_empty():
        var gold_label: Label = h.make_label(gold_text, 14, Color("#c46a14"))
        if h.display_font != null:
            gold_label.add_theme_font_override("font", h.display_font)
        top.add_child(gold_label)
    var damage_text: String = str(item.get("damage", ""))
    if not damage_text.is_empty():
        var damage_label: Label = h.make_label(damage_text, 13, Color("#2f5a38"))
        damage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        damage_label.custom_minimum_size = Vector2(width, 0)
        cell.add_child(damage_label)

static func _place_confirm_sheet(sheet: Control, width: float, min_height: float) -> void:
    var fitted: Vector2 = sheet.get_combined_minimum_size()
    var height: float = maxf(min_height, fitted.y)
    sheet.custom_minimum_size = Vector2(width, height)
    sheet.size = Vector2(width, height)
    sheet.position = Vector2((1280.0 - width) * 0.5, (800.0 - height) * 0.5)

static func _slim_confirm_button(button: Button, min_width: float) -> void:
    button.custom_minimum_size = Vector2(min_width, 40)
    for state in ["normal", "hover", "pressed", "disabled"]:
        var box: StyleBox = button.get_theme_stylebox(state)
        if box is StyleBoxFlat:
            var slim: StyleBoxFlat = (box as StyleBoxFlat).duplicate()
            slim.content_margin_top = 6
            slim.content_margin_bottom = 6
            button.add_theme_stylebox_override(state, slim)

static func centered_confirm(h, config: Dictionary) -> void:
    var replace_offer: bool = bool(config.get("replace", false))
    var dim := ColorRect.new()
    dim.name = "ShopConfirmDim"
    dim.position = Vector2.ZERO
    dim.size = Vector2(1280, 800)
    dim.color = Color(0.06, 0.04, 0.03, 0.46)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    h.overlay.add_child(dim)
    var sheet_w: float = 580.0 if replace_offer else 540.0
    var sheet_h: float = 268.0 if replace_offer else 188.0
    var sheet := PanelContainer.new()
    sheet.name = "ShopConfirmSheet"
    sheet.custom_minimum_size = Vector2(sheet_w, 0)
    var panel: StyleBoxFlat = h.style(Color("#f3e6cc"), Color("#8e714a"))
    panel.set_corner_radius_all(8)
    panel.content_margin_left = 12
    panel.content_margin_right = 12
    panel.content_margin_top = 6
    panel.content_margin_bottom = 6
    sheet.add_theme_stylebox_override("panel", panel)
    h.overlay.add_child(sheet)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 3)
    sheet.add_child(column)
    var heading: Label = h.make_display(str(config.get("heading", "确认")), 18)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    var inner_w: float = sheet_w - 24.0
    _confirm_fact_row(h, column, config.get("facts", []), true)
    var support_text: String = str(config.get("support", config.get("body", "")))
    if not support_text.is_empty() and not replace_offer:
        var support: Label = h.make_label(support_text, 13, Color("#6a7360"))
        support.name = "ConfirmSupport"
        support.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        support.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        support.custom_minimum_size = Vector2(inner_w, 16)
        column.add_child(support)
    if replace_offer:
        var hint_text: String = str(config.get("hint", ""))
        if not hint_text.is_empty():
            var hint: Label = h.make_label(hint_text, 12, Color("#7a5a3a"))
            hint.name = "ConfirmSupport"
            hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            hint.custom_minimum_size = Vector2(inner_w, 14)
            column.add_child(hint)
        var incoming_facts: Array = config.get("incoming_facts", [])
        if incoming_facts.is_empty() and not str(config.get("incoming", "")).is_empty():
            incoming_facts = [{"text": str(config.get("incoming", "")), "kind": "name"}]
        var incoming_stats: Array = []
        for fact in incoming_facts:
            if str(fact.get("kind", "")) == "damage":
                incoming_stats.append(fact)
        _confirm_fact_row(h, column, incoming_stats)
        var grid := GridContainer.new()
        grid.columns = 2
        grid.add_theme_constant_override("h_separation", 8)
        grid.add_theme_constant_override("v_separation", 2)
        grid.size_flags_horizontal = Control.SIZE_FILL
        column.add_child(grid)
        var cell_w: float = floor((inner_w - 8.0) * 0.5)
        var row_items: Array = config.get("row_items", [])
        if row_items.is_empty():
            for row_text in config.get("rows", []):
                row_items.append({"name": str(row_text), "level": "", "damage": "", "gold": ""})
        for item in row_items:
            _confirm_compare_cell(h, grid, item, cell_w)
    var wallet_text: String = str(config.get("wallet", ""))
    if not wallet_text.is_empty():
        var wallet: Label = h.make_label(wallet_text, 13, Color("#704127"))
        wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        column.add_child(wallet)
    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 12)
    column.add_child(footer)
    var cancel: Button = h.action(footer, "ShopBuyCancel", "取消", config.get("on_cancel") as Callable)
    _slim_confirm_button(cancel, 150)
    var confirm: Button = h.action(footer, "ShopBuyConfirm", str(config.get("confirm", "确定")), config.get("on_confirm") as Callable)
    _slim_confirm_button(confirm, 210)
    _place_confirm_sheet(sheet, sheet_w, sheet_h)

static func replace(h,pending: Dictionary,inventory: Array,stage: int=1) -> void:
    var column: VBoxContainer=h.parchment_column(1172,16)
    column.get_meta("scroll_frame").reward_style=true
    column.add_theme_constant_override("separation",5)
    var from_shop: bool=str(pending.get("source",""))=="shop"
    var heading: Label=h.make_display("购买并更换武器" if from_shop else "选择要更换的武器",30)
    heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    var new_id: String=str(pending.get("id",""))
    var offered: int=clampi(int(pending.get("level",1)),1,Growth.MAX_WEAPON_LEVEL)
    var incoming_name: String=str(Catalog.WEAPONS[new_id].name) if Catalog.WEAPONS.has(new_id) else new_id
    var incoming:=Control.new()
    incoming.custom_minimum_size=Vector2(1080,120)
    column.add_child(incoming)
    var cost: String=" · 支付 %d 金币" % int(pending.get("price",0)) if from_shop and pending.has("price") else ""
    var incoming_title: String="将获得  %s · %s%s" % [incoming_name,Growth.weapon_level_text(offered),cost]
    var title_width: float=minf(890,h.text_width(incoming_title,22,true)+4)
    var pair_left: float=(1080-(72+18+title_width))*0.5
    art(h,incoming,new_id,Rect2(pair_left,0,72,64),offered)
    var title: Label=text(h,incoming,incoming_title,Rect2(pair_left+90,0,title_width,31),22,Color("#75442c"),true)
    title.name="IncomingWeaponTitle"
    title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
    var attack_type: Label=text(h,incoming,Details.attack_type(new_id),Rect2(pair_left+90,35,title_width,26),18,Color("#704127"),true)
    attack_type.name="IncomingWeaponType"
    attack_type.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
    var attack: Label=text(h,incoming,Details.attack(new_id,offered),Rect2(82,68,528,50),17)
    attack.name="IncomingWeaponAttack"
    attack.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    var abilities: Label=text(h,incoming,Details.abilities(new_id,offered,0),Rect2(646,68,352,50),17,Color("#59462f"))
    abilities.name="IncomingWeaponAbilities"
    abilities.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    var grid:=GridContainer.new()
    grid.columns=3
    grid.add_theme_constant_override("h_separation",14)
    grid.add_theme_constant_override("v_separation",10)
    column.add_child(grid)
    for i in range(mini(6,inventory.size())):
        var held: Dictionary=inventory[i]
        var key: String=str(held.get("id",""))
        var data: Dictionary=Catalog.WEAPONS[key]
        var owned: int=int(held.get("level",1))
        var refund: int=Economy.sell_price(key,stage,owned)
        var slot: Button=card(h,grid,key,Vector2(348,238))
        slot.name="ReplaceSlot%d" % i
        slot.set_meta("ink_layout","side_icon")
        slot.pressed.connect(func():
            if not h.ui_busy(): h.replace_requested.emit(key))
        text(h,slot,"%d · %s" % [i+1,data.name],Rect2(12,7,324,31),23,Color("#263546"),true)
        text(h,slot,Growth.weapon_level_text(owned),Rect2(12,40,324,28),21,Color("#75442c"),true)
        text(h,slot,Details.attack_type(key),Rect2(12,70,324,25),18,Color("#704127"),true)
        art(h,slot,key,Rect2(14,99,72,62),owned)
        var desc: Label=text(h,slot,Details.attack(key,owned),Rect2(96,99,238,57),17)
        desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        var ability: Label=text(h,slot,Details.abilities(key,owned,owned),Rect2(14,158,320,40),15,Color("#59462f"))
        ability.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        text(h,slot,"换下并出售 · +%d 金币" % refund,Rect2(12,203,324,29),19,Color("#983f2b"),true)
    var footer:=HBoxContainer.new()
    column.add_child(footer)
    var cancel: Button=h.action(footer,"ReplaceCancel","取消 [Esc] · 保留现有六件",func():
        if not h.ui_busy(): h.replace_cancelled.emit())
    cancel.add_theme_font_size_override("font_size",21)
    h.open_parchment(column,true)
