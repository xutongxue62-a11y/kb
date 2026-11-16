extends "res://tests/capture_ui_v29_controls.gd"

func record() -> void:
    folder="D:/Codex/场景建模/独立游戏/原始人大作战_Godot_v0.1/previews/ui_v29_installed_details"
    DirAccess.make_dir_recursive_absolute(folder)
    root.size=Vector2i(1280,800);root.gui_disable_input=true;Engine.max_fps=60
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/pattern_preview_"+str(Time.get_ticks_usec()))
    root.add_child(world);world.settings.autosave=false;world.set_physics_process(false)
    world.music.set_enabled(false);await frames(15)
    world.start_run(false);world.set_physics_process(false);world.clear_weapons()
    for key in ["club","axe","blade","sling","powder","staff"]: world.grant_weapon(key)
    world.grant_weapon("club");world.wave=5
    world.hud.show_choices(["club","hammer","totem"],world.inventory,{},"chest",5,{"hammer":3,"totem":4})
    await frames(55);rest()
    state(button("GrowthOffer1"),0.5)
    await shot("reward_pattern_mid",{"brush_progress":0.5,"hover_role":"weapon card, yellow","one_pointer_state":true})
    var weapon_skin=button("GrowthOffer1").find_child("InkFeedback",true,false)
    var sale_skin=button("GrowthRewardSell1").find_child("InkFeedback",true,false)
    expect(weapon_skin.fill_color(1)!=sale_skin.fill_color(1),"weapon and sale hover use different colors")
    expect(weapon_skin.fill_color(1).g>sale_skin.fill_color(1).g,"weapon hover is yellow while sale hover is red")
    state(button("GrowthOffer1"),0.0);state(button("GrowthRewardSell1"),1.0)
    await shot("sale_red_hover")
    var economy=load("res://src/economy.gd")
    var stock: Array=[]
    for entry in [{"id":"hammer","level":3},{"id":"spear","level":1},{"id":"totem","level":4},{"id":"firepot","level":1},{"id":"bonebow","level":5},{"id":"crystal","level":3}]:
        var item: Dictionary=entry.duplicate()
        item.price=economy.price(item.id,5,item.level);item.sold=false;stock.append(item)
    world.hud.show_shop(stock,200,5,world.inventory,{},8,8,false)
    await frames(12);rest()
    for i in range(6):
        var item: Button=button("ShopOffer%d" % i)
        expect(item!=null,"shop offer exists")
        var copy: String=""
        for label in item.find_children("*","Label",true,false):
            copy+=label.text+"\n"
            expect(item.get_global_rect().encloses(label.get_global_rect()),"shop information stays inside its card")
        expect(copy.contains("Lv.") and (copy.contains("伤害") or copy.contains("震击") or copy.contains("雷击") or copy.contains("贯刺") or copy.contains("贯穿")),"shop card shows its weapon level and attack mechanism: "+str(stock[i].id))
    await shot("shop_details")
    var file:=FileAccess.open(folder.path_join("preview.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":marks,"main_image":"reward_pattern_mid.png","applied_to_formal_game":true,"real_player_storage_used":false,"actual_chest_choice_count":3},"  "))
    file.close()
    print("PATTERN PREVIEW RESULT: %d checks, %d failures; %d native screenshots" % [checks,failures,marks.size()])
    world.queue_free();world=null;await frames(2);quit(1 if failures else 0)
