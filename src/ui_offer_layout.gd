extends RefCounted
const Evolution = preload("res://src/weapon_evolution.gd")
const Growth = preload("res://src/growth.gd")
const Catalog = preload("res://src/catalog.gd")
const Economy = preload("res://src/economy.gd")
const SupportArt = preload("res://src/support_art.gd")
const OfferIcons = preload("res://src/ui_offer_icons.gd")
const Details = preload("res://src/ui_weapon_details.gd")
const BuffDetails = preload("res://src/ui_buff_details.gd")
const KeyBindings = preload("res://src/key_bindings.gd")
static var trimmed_art: Dictionary = {}

static func text(h, parent: Node, value: String, rect: Rect2, size: int, color: Color = Color("#263546"),bold: bool=false, wrap: bool=false) -> Label:
    var node: Label = h.make_display(value,size,color) if bold else h.make_label(value,size,color)
    if wrap:
        node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        node.add_theme_constant_override("line_spacing", 3)
    node.position = rect.position
    node.size = rect.size
    node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(node)
    return node

static func art(h,parent: Node,key: String,rect: Rect2,level: int=1) -> void:
    var weapon: bool = Catalog.WEAPONS.has(key)
    var art_key: String = "%s:%d" % [key, level] if weapon else key
    if not trimmed_art.has(art_key):
        var source: Texture2D
        if weapon:
            source = h.library.weapon_texture(key,level)
        elif key in ["pet","drone"]:
            source = SupportArt.texture(key)
        else:
            source = OfferIcons.texture(key)
        var image: Image = source.get_image()
        var visible_bounds: Rect2i = image.get_used_rect()
        trimmed_art[art_key] = ImageTexture.create_from_image(image.get_region(visible_bounds)) if visible_bounds.has_area() else source
    var node := TextureRect.new()
    node.name = "OfferIcon"
    node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    node.texture = trimmed_art[art_key]
    node.material = h.library.weapon_material if weapon else null
    node.position = rect.position
    node.size = rect.size
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(node)

static func centered_title(h, parent: Control, width: float, top: float, caption: String, category: String, level: String, size: int) -> void:
    var row := HBoxContainer.new()
    row.name = "OfferTitle"
    row.position = Vector2(0, top)
    row.size = Vector2(width, 27)
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation", 0)
    parent.add_child(row)
    text(h,row,caption,Rect2(0,0,0,27),size,Color("#263546"),true)
    if not category.is_empty():
        text(h,row,"（%s）" % category,Rect2(0,0,0,27),size,Color("#983f2b"),true)
    if not level.is_empty():
        text(h,row,"  ·  " + level,Rect2(0,0,0,27),size - 4,Color("#75442c"),true)

static func description(h, parent: Control, copy: String, rect: Rect2, size: int) -> void:
    var label: Label = text(h,parent,copy,rect,size,Color("#263546"),false,true)
    label.name = "OfferDescription"
    label.clip_text = true
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.add_theme_constant_override("line_spacing", 0)
    label.size = rect.size

static func milestones(key: String, shown: int, owned: int) -> String:
    return Details.abilities(key,shown,owned).replace(" · ","·").replace("\n","｜")

static func fit_row(node: Label, rect: Rect2) -> void:
    node.autowrap_mode = TextServer.AUTOWRAP_OFF
    node.clip_text = true
    node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    node.clip_contents = true
    node.custom_minimum_size = rect.size
    node.size = rect.size

# Shop/growth link notes need the full benefit and cost, so wrap on the
# official "｜" breaks instead of trimming with an ellipsis.
static func wrap_link_copy(copy: String) -> String:
    return copy.replace("｜", "\n")

static func link_note(h, item: Control, copy: String, rect: Rect2, size: int) -> Label:
    var fit_size: int = mini(size, 9) if copy.length() > 70 else size
    var node: Label = text(h, item, wrap_link_copy(copy), rect, fit_size, Color("#59351f"), true, true)
    node.name = "OfferLink"
    node.clip_text = false
    node.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    node.clip_contents = true
    node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    node.add_theme_constant_override("line_spacing", 0)
    # Keep the reserved row box; do not let the font's minimum size shove later rows.
    node.custom_minimum_size = Vector2(rect.size.x, 0)
    node.size = rect.size
    return node

static func link_badge(h, item: Control, key: String, inventory: Array, rect: Rect2) -> void:
    var copy: String = Catalog.offer_link_text(key, Catalog.inventory_ids(inventory))
    if copy.is_empty():
        return
    link_note(h, item, copy, rect, 11)

static func card(h,parent: Node,key: String,size: Vector2) -> Button:
    var node: Button = h.make_button("")
    node.custom_minimum_size = size
    node.size = size
    node.clip_contents = true
    h.paint_offer_card(node,h.offer_kind(key))
    node.set_meta("ink_weapon",Catalog.WEAPONS.has(key))
    node.tooltip_text = ""
    parent.add_child(node)
    return node

static func growth(h,ids: Array,inventory: Array,levels: Dictionary,reason: String, offer_levels: Dictionary = {},stage: int=1) -> void:
    var compact: bool=ids.size()>3
    var column: VBoxContainer = h.parchment_column(1068,22 if compact else 86)
    column.get_meta("scroll_frame").reward_style=true
    column.add_theme_constant_override("separation",8)
    var headings := {"chest":"精英宝箱 · 选择奖励", "xp_bonus":"举一反三 · 选择第一份成长", "talent":"举一反三 · 选择第二份成长"}
    var heading: Label = h.make_display(headings.get(reason, "选择成长"),30)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    var shortcut: String="1–6" if compact else "1 / 2 / 3"
    var hint_text: String = "选择 1 份 · 点击选择立即生效 · 也可出售该份奖励，保留现有装备" if KeyBindings.is_touch_platform() else ("选择 1 份 · 数字键 %s 或点击选择 · 点选立即生效 · 也可出售该份奖励，保留现有装备" % [shortcut])
    var hint: Label = h.make_label(hint_text,16,Color("#65704f"))
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
        var item: Button = card(h,cell,key,Vector2(300,282 if compact else 347))
        item.name = "GrowthOffer%d" % i
        item.set_meta("ink_reward",true)
        # Reward cards share neutral paper; identity comes from the original icon and text.
        var face: StyleBoxFlat=h.style(Color("#f0e3c9"),Color("#8e714a"))
        for state in ["normal","hover","pressed"]: item.add_theme_stylebox_override(state,face.duplicate())
        item.pressed.connect(func(): h._choose(key))
        var level: int = Growth.item_level(key,inventory,levels)
        var weapon: bool=Catalog.WEAPONS.has(key)
        var shown: int = clampi(int(offer_levels.get(key, 1)),1,Growth.MAX_WEAPON_LEVEL) if level==0 and weapon else level+1
        var top_level: String = ("Lv.%d → Lv.%d" % [level,shown] if level>0 else Growth.weapon_level_text(shown)) if weapon else "层数 %d → %d" % [level,shown]
        centered_title(h,item,300,8 if compact else 14,"%d · %s" % [i+1,data.name],"武器" if weapon else "属性","",17 if compact else 20)
        text(h,item,top_level,Rect2(12,35,276,24) if compact else Rect2(12,45,276,26),14 if compact else 17,Color("#75442c"),true)
        var icon_rect: Rect2
        var effect_rect: Rect2
        var body_rect: Rect2
        if compact:
            icon_rect = Rect2(94,60,112,36) if weapon else Rect2(90,65,120,68)
            effect_rect = Rect2(12,98,276,24) if weapon else Rect2(12,141,276,26)
            body_rect = Rect2(12,123,276,40) if weapon else Rect2(12,172,276,47)
        else:
            icon_rect = Rect2(85,76,130,56) if weapon else Rect2(81,84,138,95)
            effect_rect = Rect2(12,134,276,26) if weapon else Rect2(12,191,276,28)
            body_rect = Rect2(12,161,276,56) if weapon else Rect2(12,228,276,49)
        art(h,item,key,icon_rect,maxi(1,shown))
        var effect: String = Details.attack_type(key) if weapon else BuffDetails.headline(key)
        text(h,item,effect,effect_rect,15 if compact else 16,Color("#704127"),true,true).name = "OfferEffect"
        description(h,item,Details.attack(key,shown) if weapon else BuffDetails.detail(key),body_rect,13)
        if weapon:
            var stats_rect: Rect2 = Rect2(12,164,276,24) if compact else Rect2(12,218,276,24)
            var g_stats_lbl: Label = text(h,item,Details.stats_line(key,shown),stats_rect,13 if compact else 14,Color("#75442c"),true)
            g_stats_lbl.name = "OfferStats"
            fit_row(g_stats_lbl, stats_rect)
            var link_copy: String = Catalog.offer_link_text(key, Catalog.inventory_ids(inventory))
            if compact:
                if not link_copy.is_empty():
                    link_note(h,item,link_copy,Rect2(8,189,284,62),10)
                else:
                    var ab_compact: Label = text(h, item, wrap_link_copy(milestones(key, shown, level)), Rect2(8, 189, 284, 62), 10, Color("#59462f"), false, true)
                    ab_compact.clip_text = true
                    ab_compact.add_theme_constant_override("line_spacing", 1)
            else:
                if not link_copy.is_empty():
                    link_note(h,item,link_copy,Rect2(12,243,276,72),10)
                else:
                    var tiers: PackedStringArray = Details.abilities(key,shown,level).split("\n")
                    for tier in range(tiers.size()):
                        var tier_lbl: Label = text(h, item, tiers[tier], Rect2(12, 243 + tier * 24, 276, 24), 11, Color("#59462f"), false, true)
                        tier_lbl.clip_text = true
            var replace_offer: bool = level==0 and inventory.size() >= 6
            var status: String = "直接升级 · 不占新槽" if level>0 else ("槽位已满 · 需更换一件" if replace_offer else "新武器 · 装入空槽")
            text(h,item,status,Rect2(12,252,276,24) if compact else Rect2(12,316,276,24),15 if compact else 17,Color("#923f29") if replace_offer else Color("#3e5439"),true)
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
    var column: VBoxContainer=h.parchment_column(1172,6)
    column.add_theme_constant_override("separation",5)
    var heading: Label=h.make_display("营地商店 · 第 %d 关结束" % stage,26)
    heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    var wallet_text: String = ("金币 %d · 生命 %.1f / %.0f · 点击直接购买" if KeyBindings.is_touch_platform() else "金币 %d · 生命 %.1f / %.0f · 数字键 1–6 或点击直接购买") % [coins,hp,max_hp]
    var wallet: Label=h.make_display(wallet_text,18,Color("#704127"))
    wallet.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(wallet)
    var grid:=GridContainer.new()
    grid.columns=3
    grid.add_theme_constant_override("h_separation",14)
    grid.add_theme_constant_override("v_separation",8)
    column.add_child(grid)
    for i in range(stock.size()):
        var offer: Dictionary=stock[i]
        var key: String=offer.id
        var weapon: bool=Catalog.WEAPONS.has(key)
        var buff: bool=Growth.BUFFS.has(key)
        var data: Dictionary=Catalog.WEAPONS[key] if weapon else (Growth.BUFFS[key] if buff else {"name":"篝火治疗","description":"恢复 3 点生命\n不超过生命上限"})
        var item: Button=card(h,grid,key,Vector2(348,286))
        item.name="ShopOffer%d" % i
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
        var top: String=(Growth.weapon_level_text(shown) if new_weapon or owned==0 else "Lv.%d → %d" % [owned,shown]) if weapon else ("层数 %d → %d" % [owned,shown] if buff else "")
        centered_title(h,item,348,8,"%d · %s" % [i+1,str(data.name)],kind_label,"",17)
        if not top.is_empty():
            text(h,item,top,Rect2(12,35,324,21),13,Color("#75442c"),true)
        art(h,item,key,Rect2(115,58,118,35) if weapon else Rect2(111,59,126,57),maxi(1,shown))
        var effect: String=Details.attack_type(key) if weapon else (BuffDetails.headline(key) if buff else "生命 +3")
        text(h,item,effect,Rect2(14,94 if weapon else 122,320,22),15,Color("#704127"),true,true).name = "OfferEffect"
        var body: String=Details.attack(key,shown) if weapon else (BuffDetails.detail(key) if buff else data.description)
        description(h,item,body,Rect2(14,117 if weapon else 148,320,40),13)
        if weapon:
            var shop_stats_rect := Rect2(12,158,324,21)
            var shop_stats_lbl: Label = text(h,item,Details.stats_line(key,shown),shop_stats_rect,13,Color("#75442c"),true)
            shop_stats_lbl.name = "OfferStats"
            fit_row(shop_stats_lbl, shop_stats_rect)
            var shop_link: String = Catalog.offer_link_text(key, Catalog.inventory_ids(inventory))
            if not shop_link.is_empty():
                link_note(h,item,shop_link,Rect2(12,181,324,51),10)
            else:
                var extra: Label = text(h, item, wrap_link_copy(milestones(key, shown, owned)), Rect2(12, 181, 324, 51), 10, Color("#59462f"), false, true)
                extra.name = "OfferAbilities"
                extra.clip_text = true
                extra.add_theme_constant_override("line_spacing", 1)
        var action_text: String
        var action_hint: String
        if sold:
            action_text="已购入 · 已售罄"
            action_hint=""
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
                action_hint=""
            else:
                verb="购买治疗"
                action_hint="立即恢复 3 点生命"
            action_text="%s · %d 金币" % [verb,int(offer.price)]
        var act_lbl: Label = text(h,item,action_text,Rect2(12,233 if weapon else 212,324,23),16,Color("#983f2b"),true)
        fit_row(act_lbl, Rect2(12,233 if weapon else 212,324,23))
        if not action_hint.is_empty():
            var hint_lbl: Label = text(h,item,action_hint,Rect2(12,257 if weapon else 236,324,20),12,Color("#59462f"))
            fit_row(hint_lbl, Rect2(12,257 if weapon else 236,324,20))
    var footer:=HBoxContainer.new()
    footer.add_theme_constant_override("separation",14)
    column.add_child(footer)
    var save_btn: Button=h.action(footer,"SaveNow","保存",func():h.save_requested.emit())
    KeyBindings.attach_to_button(save_btn, "save")
    if reroll_cost >= 0:
        var reroll: Button=h.action(footer,"RerollShop","刷新货物 · %d 金币" % reroll_cost,func():h.reroll_requested.emit())
        if coins < reroll_cost:
            reroll.disabled=true
            reroll.modulate=Color(1,1,1,0.65)
    var home_btn: Button=h.action(footer,"Home","返回首页",func():h.home_requested.emit())
    var next_btn: Button=h.action(footer,"NextRound","下一关",func():h.next_round_requested.emit(),Color("#b4583e"))
    KeyBindings.attach_to_button(next_btn, "confirm")
    h.open_parchment(column,animate)
    if highlight>=0 and highlight<grid.get_child_count() and h.can_animate(): h.play_ui("choice_confirm")


static func replace(h,pending: Dictionary,inventory: Array,stage: int=1) -> void:
    var column: VBoxContainer=h.parchment_column(1172,12)
    column.get_meta("scroll_frame").reward_style=true
    column.add_theme_constant_override("separation",4)
    var from_shop: bool=str(pending.get("source",""))=="shop"
    var heading: Label=h.make_display("购买并更换武器" if from_shop else "选择要更换的武器",28)
    heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    var new_id: String=str(pending.get("id",""))
    var offered: int=clampi(int(pending.get("level",1)),1,Growth.MAX_WEAPON_LEVEL)
    var incoming_name: String=str(Catalog.WEAPONS[new_id].name) if Catalog.WEAPONS.has(new_id) else new_id
    var incoming:=Control.new()
    incoming.custom_minimum_size=Vector2(1080,122)
    column.add_child(incoming)
    var cost: String=" · 支付 %d 金币" % int(pending.get("price",0)) if from_shop and pending.has("price") else ""
    var incoming_title: String="将获得  %s · %s%s" % [incoming_name,Growth.weapon_level_text(offered),cost]
    text(h,incoming,incoming_title,Rect2(120,4,840,28),20,Color("#75442c"),true).name = "IncomingWeaponTitle"
    art(h,incoming,new_id,Rect2(496,33,88,42),offered)
    var incoming_type: String = Details.attack_type(new_id) + "    ｜    " + Details.stats_line(new_id,offered)
    text(h,incoming,incoming_type,Rect2(120,76,840,23),14,Color("#704127"),true).name = "IncomingWeaponType"
    var attack_text: String=Details.attack(new_id,offered).replace("\n","")
    var incoming_link: String = Catalog.offer_link_text(new_id, Catalog.inventory_ids(inventory))
    if not incoming_link.is_empty():
        attack_text = attack_text + "  " + incoming_link
    var incoming_attack: Label = text(h,incoming,attack_text,Rect2(120,99,840,22),14)
    incoming_attack.name = "IncomingWeaponAttack" if incoming_link.is_empty() else "IncomingWeaponLink"
    incoming_attack.clip_text = true
    incoming_attack.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
        var slot: Button=card(h,grid,key,Vector2(348,242))
        slot.name="ReplaceSlot%d" % i
        slot.pressed.connect(func():
            if not h.ui_busy(): h.choose_replace_slot(key))
        centered_title(h,slot,348,8,"%d · %s" % [i+1,data.name],"",Growth.weapon_level_text(owned),18)
        art(h,slot,key,Rect2(122,37,104,54),owned)
        text(h,slot,Details.attack_type(key),Rect2(12,94,324,24),15,Color("#704127"),true,true).name = "OfferEffect"
        description(h,slot,Details.attack(key,owned),Rect2(12,119,324,41),13)
        var r_stats := text(h,slot,Details.stats_line(key,owned),Rect2(12,161,324,24),13,Color("#75442c"),true)
        fit_row(r_stats, Rect2(12,161,324,24))
        var r_milestones := text(h,slot,milestones(key,owned,owned),Rect2(12,186,324,24),10,Color("#59462f"))
        fit_row(r_milestones, Rect2(12,186,324,24))
        var r_sell := text(h,slot,"换下并出售 · +%d 金币" % refund,Rect2(12,211,324,24),16,Color("#983f2b"),true)
        fit_row(r_sell, Rect2(12,211,324,24))
    var footer:=HBoxContainer.new()
    column.add_child(footer)
    var cancel: Button=h.action(footer,"ReplaceCancel","取消 · 保留现有六件",func():
        if not h.ui_busy(): h.replace_cancelled.emit())
    cancel.add_theme_font_size_override("font_size",21)
    KeyBindings.attach_to_button(cancel, "cancel")
    h.open_parchment(column,true)


static func replace_confirm(h,pending: Dictionary,outgoing: Dictionary,stage: int=1) -> VBoxContainer:
    var column: VBoxContainer=h.parchment_column(650,160)
    column.get_meta("scroll_frame").opening_mode="fold"
    column.add_theme_constant_override("separation",10)
    var from_shop: bool=str(pending.get("source",""))=="shop"
    var heading: Label=h.make_display("确认出售并更换",30)
    heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    var new_id: String=str(pending.get("id",""))
    var new_level: int=clampi(int(pending.get("level",1)),1,Growth.MAX_WEAPON_LEVEL)
    var old_id: String=str(outgoing.get("id",""))
    var old_level: int=clampi(int(outgoing.get("level",1)),1,Growth.MAX_WEAPON_LEVEL)
    var comparison := HBoxContainer.new()
    comparison.alignment = BoxContainer.ALIGNMENT_CENTER
    comparison.add_theme_constant_override("separation", 18)
    column.add_child(comparison)
    _replace_confirm_card(h,comparison,"将获得",new_id,new_level,Color("#3f6b35"))
    _replace_confirm_card(h,comparison,"换下",old_id,old_level,Color("#983f2b"))
    var refund: int=Economy.sell_price(old_id,stage,old_level)
    var fact: String
    if from_shop and pending.has("price"):
        fact="支付 %d 金币 · 出售 +%d 金币" % [int(pending.get("price",0)),refund]
    else:
        fact="出售 +%d 金币" % refund
    var fact_label: Label=h.make_label(fact,18,Color("#59462f"))
    fact_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(fact_label)
    KeyBindings.attach_to_button(h.action(column,"ConfirmReplace","确定出售并更换",func():
        if not h.ui_busy(): h.confirm_replace_choice(),Color("#b4583e")), "confirm")
    KeyBindings.attach_to_button(h.action(column,"CancelReplaceConfirm","取消",func():
        if not h.ui_busy(): h.cancel_replace_confirm()), "cancel")
    h.open_parchment(column,true)
    return column


static func _replace_confirm_card(h,parent: HBoxContainer,tag: String,weapon_id: String,level: int,tag_color: Color) -> void:
    if not Catalog.WEAPONS.has(weapon_id):
        return
    var data: Dictionary=Catalog.WEAPONS[weapon_id]
    var panel: Button = card(h,parent,weapon_id,Vector2(264,239))
    panel.name = "IncomingCompare" if tag == "将获得" else "OutgoingCompare"
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.focus_mode = Control.FOCUS_NONE
    panel.set_meta("ink_reward",true)
    text(h,panel,tag,Rect2(12,9,240,23),16,tag_color,true)
    centered_title(h,panel,264,34,str(data.name),"",Growth.weapon_level_text(level),17)
    art(h,panel,weapon_id,Rect2(82,64,100,60),level)
    text(h,panel,Details.attack_type(weapon_id),Rect2(12,129,240,24),14,Color("#704127"),true,true)
    description(h,panel,Details.attack(weapon_id,level),Rect2(12,154,240,42),13)
    text(h,panel,Details.stats_line(weapon_id,level),Rect2(12,199,240,25),13,Color("#75442c"),true)
