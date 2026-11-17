extends SceneTree
const Growth=preload("res://src/growth.gd")
const Economy=preload("res://src/economy.gd")
const Catalog=preload("res://src/catalog.gd")

var checks:=0
var failures:=0

func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)

func _initialize() -> void: call_deferred("run")

func shown(world,key: String,offer_levels: Dictionary) -> int:
    var owned: int=Growth.item_level(key,world.inventory,world.buff_levels)
    if Catalog.WEAPONS.has(key) and owned==0:
        return clampi(int(offer_levels.get(key,1)),1,Growth.MAX_WEAPON_LEVEL)
    return owned+1
func refund(world,key: String,offer_levels: Dictionary) -> int:
    return Economy.reward_sell_price(key,world.wave,shown(world,key,offer_levels))
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

    var first_levels: Dictionary={"spear":3,"hammer":4}
    offer(world,["spear","hammer","power"],first_levels)
    expect(not world.sell_reward("totem"),"an unoffered weapon cannot be sold")
    expect(not world.sell_reward("heal"),"non-reward healing cannot enter reward resale")
    expect(world.coins==40 and world.upgrade_pending,"invalid sale keeps wallet and reward choice intact")
    var sale: Button=world.hud.overlay.find_child("GrowthRewardSell0",true,false)
    var spear_refund: int=refund(world,"spear",first_levels)
    expect(sale!=null and sale.text=="出售此奖励 +%d 金币" % spear_refund,"sale quotes stage 13 Lv.3 refund, not a purchase price")
    var buff_sale: Button=world.hud.overlay.find_child("GrowthRewardSell2",true,false)
    var power_refund: int=refund(world,"power",first_levels)
    expect(buff_sale!=null and buff_sale.text=="出售此奖励 +%d 金币" % power_refund,"stage 13 first 蛮力 reward refunds half its shop price, not a weapon price")
    var old_xp: float=world.xp
    var old_level: int=world.player_level
    if sale!=null: sale.pressed.emit()
    var wallet: int=40+spear_refund
    expect(world.coins==wallet,"click credits only this selected reward")
    expect(world.inventory==held and world.weapon_views.keys()==views,"sale preserves every held weapon level and bound view")
    expect(not world.upgrade_pending and world.upgrade_choices.is_empty(),"sale consumes exactly the current reward choice")
    expect(world.xp==old_xp and world.player_level==old_level,"chest reward sale does not consume an XP level")
    expect(not world.sell_reward("hammer") and world.coins==wallet,"unselected reward is discarded without credit; repeated sale is rejected")

    var six: Array=["spear","hammer","boomerang","totem","bonebow","club"]
    var six_levels: Dictionary={"spear":3,"hammer":5,"boomerang":1,"totem":3,"bonebow":4}
    offer(world,six,six_levels)
    expect(world.hud.overlay.find_children("GrowthOffer*","Button",true,false).size()==6,"six reward choices all remain available")
    var fifth: Button=world.hud.overlay.find_child("GrowthRewardSell4",true,false)
    var fifth_refund: int=refund(world,"bonebow",six_levels)
    expect(fifth!=null and fifth.text=="出售此奖励 +%d 金币" % fifth_refund,"fifth reward has its own actual stage/level quote")
    if fifth!=null: fifth.pressed.emit()
    wallet+=fifth_refund
    expect(world.coins==wallet and world.inventory==held,"selling the fifth of six rewards credits only that reward and keeps equipment")
    expect(not world.sell_reward("spear") and world.coins==wallet,"other five rewards are never auto-sold")

    var xp_levels: Dictionary={"hammer":1,"spear":1}
    offer(world,["club","hammer","spear"],xp_levels,"xp")
    world.player_level=3;world.xp=20;world.xp_needed=17
    var club_refund: int=refund(world,"club",xp_levels)
    expect(world.sell_reward("club"),"owned-weapon upgrade reward can be declined for its own refund")
    wallet+=club_refund
    expect(world.inventory==held and world.coins==wallet,"selling a Lv.2 to Lv.3 upgrade leaves the held Lv.2 club untouched")
    expect(world.player_level==4 and is_equal_approx(world.xp,3) and world.xp_needed==Growth.xp_needed_for(4),"XP sale completes the same single level as claiming a reward")

    var replace_levels: Dictionary={"spear":3,"hammer":4,"totem":5}
    offer(world,["spear","hammer","totem"],replace_levels)
    world.on_choice("spear")
    expect(not world.replace_pending.is_empty(),"fixture opens the existing full-slot replacement choice")
    expect(not world.sell_reward("spear") and world.coins==wallet and world.inventory==held,"stale sale cannot bypass an active replacement decision")
    world.cancel_replace()
    var hammer_refund: int=refund(world,"hammer",replace_levels)
    expect(world.sell_reward("hammer") and world.coins==wallet+hammer_refund and world.inventory==held,"after cancelling replacement a different reward can be sold normally")
    wallet+=hammer_refund

    offer(world,["spear","hammer","totem"],replace_levels)
    world.shop_open=true
    expect(not world.sell_reward("spear") and world.coins==wallet,"shop context cannot cash a stale free-reward action")
    world.shop_open=false;world.chest_queue=1
    var chest_refund: int=refund(world,"spear",replace_levels)
    expect(world.sell_reward("spear") and world.coins==wallet+chest_refund,"selling current chest gives only its own refund")
    expect(world.upgrade_pending and world.upgrade_reason=="chest" and world.chest_queue==0,"a queued chest still opens its own unsold reward choice")
    expect(world.inventory==held,"even with a queued chest every equipped weapon stays unchanged")
    world.queue_free();world=null;await process_frame
    print("REWARD SALE V23 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
