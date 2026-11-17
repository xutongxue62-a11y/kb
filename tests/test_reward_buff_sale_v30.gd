extends SceneTree
const Growth=preload("res://src/growth.gd")
const Economy=preload("res://src/economy.gd")
var checks:=0
var failures:=0
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func refund(world,key: String) -> int:
    var owned: int=Growth.item_level(key,world.inventory,world.buff_levels)
    return Economy.reward_sell_price(key,world.wave,owned+1)
func offer(world,ids: Array,reason: String="chest") -> void:
    world.shop_open=false;world.running=true;world.wave_closing=false
    world.replace_pending.clear();world.chest_queue=0
    world.upgrade_pending=true;world.upgrade_reason=reason
    world.upgrade_choices=ids.duplicate();world.upgrade_offer_levels={}
    world.hud.show_choices(ids,world.inventory,world.buff_levels,reason,world.wave,{})
func run() -> void:
    var world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/buff_sale_v30_"+str(Time.get_ticks_usec()))
    root.add_child(world);world.settings.autosave=false;world.set_physics_process(false)
    world.music.set_enabled(false);world.start_run(false)
    world.apply_buff("crit_chance");world.apply_buff("crit_chance");world.apply_buff("pet")
    var held: Array=world.inventory.duplicate(true)
    var buffs: Dictionary=world.buff_levels.duplicate(true)
    var stats: Dictionary=world.stats.duplicate(true)
    world.wave=13;world.coins=40
    offer(world,["crit_chance","power","pet"])
    var sale: Button=world.hud.overlay.find_child("GrowthRewardSell0",true,false)
    var crit_refund: int=refund(world,"crit_chance")
    expect(sale!=null and sale.text=="出售此奖励 +%d 金币" % crit_refund,"stage 13 next crit stack refunds half its shop price")
    expect(world.sell_reward("crit_chance"),"an offered passive buff reward can be sold")
    var wallet: int=40+crit_refund
    expect(world.coins==wallet and not world.upgrade_pending,"only the selected buff refund is consumed")
    expect(world.inventory==held and world.buff_levels==buffs and world.stats==stats,"sale leaves existing weapons, buff stacks and effects unchanged")
    expect(not world.sell_reward("pet") and world.coins==wallet,"unselected support is never auto-sold and stale sale cannot repeat")
    world.wave=1
    offer(world,["power","pet","armor"])
    var power_refund: int=refund(world,"power")
    expect(world.sell_reward("power") and world.coins==wallet+power_refund,"first 蛮力 reward sells for half its shop cost")
    wallet+=power_refund
    offer(world,["pet","power","armor"])
    var pet_refund: int=refund(world,"pet")
    expect(world.sell_reward("pet") and world.coins==wallet+pet_refund,"a next-stack support reward sells for half its shop cost")
    wallet+=pet_refund
    expect(world.buff_levels==buffs and world.inventory==held,"selling support does not remove the existing companion or its stack")
    offer(world,["power","armor","speed"],"xp")
    world.player_level=3;world.xp=28;world.xp_needed=25
    var xp_refund: int=refund(world,"power")
    expect(world.sell_reward("power") and world.coins==wallet+xp_refund,"an XP buff reward also uses the normal single-reward refund")
    wallet+=xp_refund
    expect(world.player_level==4 and is_equal_approx(world.xp,3),"XP sale resolves exactly one level-up")
    expect(world.buff_levels==buffs,"XP sale does not apply the rejected buff")
    offer(world,["power","pet","armor","speed","vitality","regen"])
    expect(world.hud.overlay.find_children("GrowthRewardSell*","Button",true,false).size()==6,"all six buff rewards have their own sale action")
    expect(not world.sell_reward("heal") and world.coins==wallet,"non-reward healing cannot be converted to gold")
    world.replace_pending={"id":"hammer","source":"choice","level":1}
    expect(not world.sell_reward("power") and world.coins==wallet,"a stale buff sale cannot bypass a pending weapon replacement")
    world.replace_pending.clear();world.shop_open=true
    expect(not world.sell_reward("power") and world.coins==wallet,"shop context cannot cash a stale reward sale")
    world.shop_open=false;world.chest_queue=1
    var chest_refund: int=refund(world,"power")
    expect(world.sell_reward("power") and world.coins==wallet+chest_refund,"queued chests do not add any extra resale credit")
    expect(world.upgrade_pending and world.chest_queue==0,"the next queued chest still opens its own unconsumed choice")
    world.queue_free();world=null;await process_frame
    print("REWARD BUFF SALE V30 RESULT: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
