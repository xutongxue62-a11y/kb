extends "res://tests/capture_ui_v29_controls.gd"
func check_cards(prefix: String,count: int) -> void:
    var paper: Control=world.hud.overlay.find_child("HanddrawnPaper",true,false)
    var safe: Rect2=paper.visible_content_rect()
    safe.position+=paper.global_position
    expect(Rect2(0,0,1280,800).encloses(paper.get_global_rect()),"whole parchment stays on screen: "+prefix)
    for i in range(count):
        var node: Button=button(prefix+str(i))
        expect(node!=null and safe.encloses(node.get_global_rect()),"whole card stays inside the scroll: "+prefix+str(i))
        for label in node.find_children("*","Label",true,false):
            expect(node.get_global_rect().encloses(label.get_global_rect()),"label stays inside its card: "+prefix+str(i)+" "+label.text)
func text_of(node: Node) -> String:
    var values: PackedStringArray=[]
    for label in node.find_children("*","Label",true,false): values.append(label.text)
    return "\n".join(values)
func record() -> void:
    folder="D:/Codex/场景建模/独立游戏/原始人大作战_Godot_v0.1/previews/ui_v31_installed_readability"
    DirAccess.make_dir_recursive_absolute(folder)
    root.size=Vector2i(1280,800);root.gui_disable_input=true;Engine.max_fps=60
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/readability_preview_"+str(Time.get_ticks_usec()))
    root.add_child(world);world.settings.autosave=false;world.set_physics_process(false);world.music.set_enabled(false)
    world.start_run(false);world.set_physics_process(false);world.clear_weapons()
    for item in [{"id":"totem","level":2},{"id":"powder","level":1},{"id":"spear","level":2},{"id":"crystal","level":1},{"id":"axe","level":2},{"id":"staff","level":2}]:
        world.grant_weapon(item.id,item.level)
    world.apply_buff("crit_chance");world.apply_buff("crit_chance");world.apply_buff("pet");world.apply_buff("vitality")
    world.wave=1;world.coins=62;world.player_hp=9
    world.upgrade_pending=true;world.upgrade_reason="chest"
    world.upgrade_choices=["crit_chance","power","pet"];world.upgrade_offer_levels={}
    world.hud.show_choices(world.upgrade_choices,world.inventory,world.buff_levels,"chest",1,{})
    await frames(55);rest();check_cards("GrowthOffer",3)
    expect(text_of(button("GrowthOffer0")).contains("最多 15 层") and text_of(button("GrowthOffer0")).contains("6%"),"critical buff has a direct numeric effect and real stack limit")
    await shot("buff_rewards")
    var held: Array=world.inventory.duplicate(true)
    var buffs: Dictionary=world.buff_levels.duplicate(true)
    await click(button("GrowthRewardSell0"));await frames(40)
    expect(world.coins==73 and world.inventory==held and world.buff_levels==buffs,"native buff-sale click credits only 11 coins and keeps all equipment and existing buff stacks")
    world.upgrade_pending=false;world.coins=62
    var economy=load("res://src/economy.gd")
    var stock: Array=[]
    for key in ["axe","boomerang","pet","crit_chance","totem","dodge"]:
        var owned: int=load("res://src/growth.gd").item_level(key,world.inventory,world.buff_levels)
        var level: int=1 if key=="boomerang" else owned
        var offer: Dictionary={"id":key,"price":economy.price(key,1,level),"sold":false}
        if key=="boomerang": offer.level=1
        stock.append(offer)
    world.shop_open=true;world.shop_stock=stock
    world.hud.show_shop(stock,62,1,world.inventory,world.buff_levels,9,10,false)
    await frames(20);rest();check_cards("ShopOffer",6)
    for i in range(6): expect(text_of(button("ShopOffer%d" % i)).contains("购买"),"every available offer explicitly says purchase")
    await shot("shop_readability")
    world.replace_pending={"id":"boomerang","level":1,"source":"shop","price":22,"shop_index":1}
    world.hud.show_replace(world.replace_pending,world.inventory,1)
    await frames(55);rest();check_cards("ReplaceSlot",6)
    for i in range(6):
        var copy: String=text_of(button("ReplaceSlot%d" % i))
        expect(copy.contains("Lv.") and copy.contains("出售") and not copy.contains("「武器」"),"replacement has a visible level and sale action without a category box")
    await shot("replace_readability")
    var fresh: Array=[{"id":"boomerang","level":1,"price":22,"sold":false}]
    world.hud.show_shop(fresh,62,1,[],{},8,8,false)
    await frames(4);rest()
    expect(text_of(button("ShopOffer0")).contains("购买新武器"),"first acquisition into a free slot explicitly says purchase new weapon")
    var file:=FileAccess.open(folder.path_join("preview.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":marks,"applied_to_formal_game":true,"real_player_storage_used":false},"  "))
    file.close()
    print("UI V30 READABILITY PREVIEW RESULT: %d checks, %d failures" % [checks,failures])
    world.queue_free();world=null;await frames(2);quit(1 if failures else 0)
