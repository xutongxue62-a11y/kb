extends SceneTree
const Growth=preload("res://src/growth.gd")

var checks:=0
var failures:=0

func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)

func _initialize() -> void: call_deferred("run")

func offer(world,ids: Array,levels: Dictionary,reason: String="chest") -> void:
    world.shop_open=false;world.running=true;world.wave_closing=false
    world.replace_pending.clear();world.chest_queue=0
    world.upgrade_pending=true;world.upgrade_reason=reason
    world.upgrade_choices=ids.duplicate();world.upgrade_offer_levels=levels.duplicate()
    world.hud.show_choices(ids,world.inventory,world.buff_levels,reason,world.wave,levels)

func run() -> void:
    var world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/reward_sale_v23_"+str(Time.get_ticks_usec()))
    root.add_child(world);world.settings.autosave=false;world.set_physics_process(false)
    world.music.set_enabled(false)
    expect(world.has_method("sell_reward"),"one selected reward can be sold independently of equipped weapons")
    if not world.has_method("sell_reward"):
        world.queue_free();await process_frame
        print("REWARD SALE V23 RESULT: %d checks, %d failures" % [checks,failures]);quit(1);return
    world.start_run(false)
    world.clear_weapons()
    for key in ["club","axe","blade","sling","powder","staff"]: world.grant_weapon(key)
    world.grant_weapon("club")
    var held: Array=world.inventory.duplicate(true)
    var views: Array=world.weapon_views.keys()
    world.wave=13;world.coins=40
    world.upgrade_pending=false
    expect(not world.sell_reward("spear") and world.coins==40,"no pending reward cannot produce gold")

    offer(world,["spear","hammer","power"],{"spear":3,"hammer":4})
    expect(not world.sell_reward("totem"),"an unoffered weapon cannot be sold")
    expect(not world.sell_reward("heal"),"non-reward healing cannot enter reward resale")
    expect(world.coins==40 and world.upgrade_pending,"invalid sale keeps wallet and reward choice intact")
    var sale: Button=world.hud.overlay.find_child("GrowthRewardSell0",true,false)
    expect(sale!=null and sale.text=="出售此奖励 +16 金币","sale quotes stage 13 Lv.3 refund, not a purchase price")
    var buff_sale: Button=world.hud.overlay.find_child("GrowthRewardSell2",true,false)
    expect(buff_sale!=null and buff_sale.text=="出售此奖励 +15 金币","stage 13 first 蛮力 reward refunds floor((28 + 3) / 2), not a weapon price")
    var old_xp: float=world.xp
    var old_level: int=world.player_level
    if sale!=null: sale.pressed.emit()
    expect(world.coins==56,"click credits only this selected 16-coin reward")
    expect(world.inventory==held and world.weapon_views.keys()==views,"sale preserves every held weapon level and bound view")
    expect(not world.upgrade_pending and world.upgrade_choices.is_empty(),"sale consumes exactly the current reward choice")
    expect(world.xp==old_xp and world.player_level==old_level,"chest reward sale does not consume an XP level")
    expect(not world.sell_reward("hammer") and world.coins==56,"unselected reward is discarded without credit; repeated sale is rejected")

    var six: Array=["spear","hammer","boomerang","totem","bonebow","club"]
    offer(world,six,{"spear":3,"hammer":5,"boomerang":1,"totem":3,"bonebow":4})
    expect(world.hud.overlay.find_children("GrowthOffer*","Button",true,false).size()==6,"six reward choices all remain available")
    var fifth: Button=world.hud.overlay.find_child("GrowthRewardSell4",true,false)
    expect(fifth!=null and fifth.text=="出售此奖励 +18 金币","fifth reward has its own actual stage/level quote")
    if fifth!=null: fifth.pressed.emit()
    expect(world.coins==74 and world.inventory==held,"selling the fifth of six rewards credits only 18 coins and keeps equipment")
    expect(not world.sell_reward("spear") and world.coins==74,"other five rewards are never auto-sold")

    offer(world,["club","hammer","spear"],{"hammer":1,"spear":1},"xp")
    world.player_level=3;world.xp=20;world.xp_needed=17
    expect(world.sell_reward("club"),"owned-weapon upgrade reward can be declined for its own refund")
    expect(world.inventory==held and world.coins==90,"selling a Lv.2 to Lv.3 upgrade leaves the held Lv.2 club untouched")
    expect(world.player_level==4 and is_equal_approx(world.xp,3) and world.xp_needed==Growth.xp_needed_for(4),"XP sale completes the same single level as claiming a reward")

    offer(world,["spear","hammer","totem"],{"spear":3,"hammer":4,"totem":5})
    world.on_choice("spear")
    expect(not world.replace_pending.is_empty(),"fixture opens the existing full-slot replacement choice")
    expect(not world.sell_reward("spear") and world.coins==90 and world.inventory==held,"stale sale cannot bypass an active replacement decision")
    world.cancel_replace()
    expect(world.sell_reward("hammer") and world.coins==108 and world.inventory==held,"after cancelling replacement a different reward can be sold normally")

    offer(world,["spear","hammer","totem"],{"spear":3,"hammer":4,"totem":5})
    world.shop_open=true
    expect(not world.sell_reward("spear") and world.coins==108,"shop context cannot cash a stale free-reward action")
    world.shop_open=false;world.chest_queue=1
    expect(world.sell_reward("spear") and world.coins==124,"selling current chest gives only its own refund")
    expect(world.upgrade_pending and world.upgrade_reason=="chest" and world.chest_queue==0,"a queued chest still opens its own unsold reward choice")
    expect(world.inventory==held,"even with a queued chest every equipped weapon stays unchanged")
    world.queue_free();world=null;await process_frame
    print("REWARD SALE V23 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
