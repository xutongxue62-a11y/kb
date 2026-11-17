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
        var item: Button=card(h,grid,key,Vector2(348,292))
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
        text(h,item,data.name,Rect2(12,7,324,34),24,Color("#263546"),true)
        var top: String=(Growth.weapon_level_text(shown) if new_weapon or owned==0 else "Lv.%d → %d" % [owned,shown]) if weapon else ("层数 %d → %d" % [owned,shown] if buff else "恢复生命")
        text(h,item,top,Rect2(12,42,324,30),21,Color("#75442c"),true)
        var effect: String=Details.attack_type(key) if weapon else (BuffDetails.headline(key) if buff else "生命 +3")
        text(h,item,effect,Rect2(12,74,324,27),19,Color("#704127"),true)
        art(h,item,key,Rect2(14,106,72,66),maxi(1,shown))
        var body: String=Details.attack(key,shown) if weapon else (BuffDetails.detail(key) if buff else data.description)
        var desc: Label=text(h,item,body,Rect2(96,100,238,52) if weapon else Rect2(96,106,238,72),17)
        desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        if weapon:
            text(h,item,Details.stats_line(key,shown),Rect2(96,156,238,22),16,Color("#75442c"),true)
        if weapon:
            var ability: Label=text(h,item,Details.abilities(key,shown,owned),Rect2(14,181,320,43),16,Color("#59462f"))
            ability.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        elif buff:
            text(h,item,BuffDetails.limit(key),Rect2(14,186,320,29),19,Color("#704127"),true)
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
        text(h,item,action_text,Rect2(12,230,324,30),20,Color("#983f2b"),true)
        text(h,item,action_hint,Rect2(12,262,324,24),16,Color("#59462f"))
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
    var column: VBoxContainer = h.parchment_column(760, 140)
    column.get_meta("scroll_frame").opening_mode = "fold"
    column.add_theme_constant_override("separation", 12)
    var heading: Label = h.make_display("确认" + verb, 30)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    var detail: String = "确定花费 %d 金币%s「%s」吗？\n取消将返回商店，不会扣费。" % [int(offer.get("price", 0)), "购买并更换" if replace_offer else "购买", str(data.get("name", key))]
    if replace_offer:
        detail += "\n换下的武器按原价 50% 折价售回。"
    var body: Label = h.make_label(detail, 18, Color("#66705e"))
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.custom_minimum_size = Vector2(640, 90)
    column.add_child(body)
    var wallet: Label = h.make_label("当前金币 %d · 生命 %.1f / %.0f" % [coins, hp, max_hp], 17, Color("#704127"))
    wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(wallet)
    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 16)
    column.add_child(footer)
    h.action(footer, "ShopBuyCancel", "取消", func():
        if not h.ui_busy(): h.cancel_shop_buy())
    h.action(footer, "ShopBuyConfirm", "确定" + verb, func():
        if not h.ui_busy():
            h.confirm_shop_buy())
    h.open_parchment(column, true)

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
