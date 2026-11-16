extends "res://tests/capture_ui_v30.gd"
func record() -> void:
    folder="D:/Codex/场景建模/独立游戏/原始人大作战_Godot_v0.1/previews/ui_v31_installed_incoming"
    DirAccess.make_dir_recursive_absolute(folder)
    root.size=Vector2i(1280,800);root.gui_disable_input=true;Engine.max_fps=60
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/incoming_preview_"+str(Time.get_ticks_usec()))
    root.add_child(world);world.settings.autosave=false;world.set_physics_process(false);world.music.set_enabled(false)
    world.start_run(false);world.set_physics_process(false);world.clear_weapons()
    for item in [{"id":"totem","level":2},{"id":"powder","level":1},{"id":"spear","level":2},{"id":"crystal","level":1},{"id":"axe","level":2},{"id":"staff","level":2}]: world.grant_weapon(item.id,item.level)
    world.hud.show_replace({"id":"boomerang","level":1,"source":"shop","price":22,"shop_index":0},world.inventory,1)
    await frames(55);rest();check_cards("ReplaceSlot",6)
    var title: Label=world.hud.overlay.find_child("IncomingWeaponTitle",true,false)
    var group: Control=title.get_parent()
    var icons: Array=group.find_children("*","TextureRect",false,false)
    expect(icons.size()==1,"incoming weapon has one original icon inside its summary group")
    if icons.size()==1:
        var icon: Rect2=icons[0].get_global_rect()
        var label: Rect2=title.get_global_rect()
        expect(absf(label.position.x-icon.end.x-18)<1,"incoming icon is adjacent to its name with an 18-pixel gap")
        expect(absf((icon.position.x+label.end.x)*0.5-640)<1,"icon and title form a centered group")
    var copy: String=text_of(group)
    expect(copy.contains("往返命中") and copy.contains("飞回角色") and copy.contains("双轮回旋") and copy.contains("三轮回旋"),"incoming summary includes attack type, method and both level abilities")
    await shot("incoming_weapon_group")
    var file:=FileAccess.open(folder.path_join("preview.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":marks,"applied_to_formal_game":true,"real_player_storage_used":false},"  "))
    file.close()
    print("UI V31 INCOMING PREVIEW RESULT: %d checks, %d failures" % [checks,failures])
    world.queue_free();world=null;await frames(2);quit(1 if failures else 0)
