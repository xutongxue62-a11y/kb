extends "res://tests/capture_ui_v29_controls.gd"
var target_regions: Dictionary={}

func mark_region(key: String,node: Button) -> void:
    var rect: Rect2=node.get_global_rect()
    target_regions[key]=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func capture_mask_pair(key: String,node: Button) -> void:
    var marks: Control=node.find_child("PaperCaveMarks",true,false)
    expect(marks!=null,"button has an independently masked cave-paint layer: "+key)
    if marks==null: return
    state(node,1.0);marks.show();mark_region(key,node)
    await shot(key+"_full")
    marks.hide();await shot(key+"_full_without_marks");marks.show()

func record() -> void:
    folder="D:/Codex/场景建模/独立游戏/原始人大作战_Godot_v0.1/previews/ui_v29_installed"
    DirAccess.make_dir_recursive_absolute(folder)
    root.size=Vector2i(1280,800);root.gui_disable_input=true;Engine.max_fps=60
    world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/cave_preview_"+str(Time.get_ticks_usec()))
    root.add_child(world);world.settings.autosave=false;world.set_physics_process(false)
    world.music.set_enabled(false);await frames(15)
    world.start_run(false);world.set_physics_process(false);world.clear_weapons()
    for key in ["club","axe","blade","sling","powder","staff"]: world.grant_weapon(key)
    world.grant_weapon("club");world.wave=5
    world.hud.show_choices(["club","hammer","totem"],world.inventory,{},"chest",5,{"hammer":3,"totem":4})
    await frames(55);rest()
    var card: Button=button("GrowthOffer1")
    var marks: Control=card.find_child("PaperCaveMarks",true,false)
    mark_region("weapon",card)
    await shot("weapon_rest")
    marks.hide();await shot("weapon_rest_without_marks");marks.show()
    state(card,0.5)
    await shot("reward_cave_mid",{"brush_progress":0.5,"one_pointer_state":true})
    marks.hide();await shot("weapon_mid_without_marks");marks.show()
    await capture_mask_pair("weapon",card)
    state(card,0.0)
    await capture_mask_pair("sale",button("GrowthRewardSell1"))
    world.hud.show_title();await frames(55);rest()
    await capture_mask_pair("home",button("EnterCamp"))
    world.hud.show_settings(false);await frames(55);rest()
    await capture_mask_pair("music_switch",button("MusicEnabled"))
    await capture_mask_pair("autosave_switch",button("Autosave"))
    var file:=FileAccess.open(folder.path_join("preview.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":marks_for_report(),"target_regions":target_regions,
        "main_image":"reward_cave_mid.png","applied_to_formal_game":true,"real_player_storage_used":false,"actual_chest_choice_count":3},"  "))
    file.close()
    print("CAVE MARKS PREVIEW RESULT: %d checks, %d failures" % [checks,failures])
    world.queue_free();world=null;await frames(2);quit(1 if failures else 0)

func marks_for_report() -> Array: return marks
