extends RefCounted
const Evolution=preload("res://src/weapon_evolution.gd")
const Catalog=preload("res://src/catalog.gd")
const Growth=preload("res://src/growth.gd")
# Describes the implemented attack mechanisms, without inventing an elemental-resistance system.
const COPY={
    "club":["近战 · 钝击伤害","环绕身体击打近处敌人，\n命中时造成较强击退。"],
    "axe":["近战 · 劈砍伤害","重斧环绕身体挥砍，\n攻击靠近角色的敌人。"],
    "blade":["近战 · 切割伤害","骨刃快速环绕身体，\n连续切割近处敌人。"],
    "sling":["远程 · 石弹伤害","自动瞄准并发射石弹，\n石弹沿飞行路径命中敌人。"],
    "powder":["远程 · 范围爆炸","发射炮弹，命中后爆炸，\n对爆点周围敌人造成伤害。"],
    "staff":["远程 · 符能弹伤害","向目标同时发射多枚符弹，\n只有伤害，没有控制；5级可展开符阵轰击。"],
    "spear":["近战 · 贯刺伤害","朝目标直线刺出骨矛，\n贯穿同一直线上的敌人。"],
    "hammer":["近战 · 跃砸震击","高抛跃起砸向目标敌群，\n落地引发大范围重砸与击退。"],
    "boomerang":["投掷 · 往返命中","掷出骨镖后飞回角色，\n去程、回程各可命中一次。"],
    "totem":["远程 · 连锁雷击","雷击在附近敌人间跳跃，\n3级起可短暂麻痹，同敌一生仅一次。"],
    "bonebow":["远程 · 贯穿骨箭","向目标发射直线骨箭，\n沿飞行路径贯穿多个敌人。"],
    "firepot":["投掷 · 持续灼伤","抛出火壶，落地形成火场，\n5级可召炎柱砸向敌群。"],
    "wardrum":["范围 · 波纹震击","击鼓向外扩散多道震波，\n波纹扫过敌人时造成伤害。"],
    "crystal":["布置 · 碎晶伤害","布下晶簇，敌人靠近触发，\n向四周发射可命中的碎晶。"]
}
static func attack_type(key: String) -> String: return str(COPY[key][0]) if COPY.has(key) else ""
# The weapon's own numbers at the level on the card, computed with the same
# formulas combat uses: damage grows +35% of base per level; the interval
# divisor differs per weapon family (basic 0.12, expanded 0.08, armory none).
# Buff multipliers are not included — this is the figure cards are compared by.
# Keep "0.48秒" as one typographic unit so AUTOWRAP_WORD_SMART cannot
# break the interval at the decimal point ("0." / "48 秒").
const WORD_JOINER := "⁠"
const NBSP := " "

static func interval_phrase(interval: float) -> String:
    var amount: String = ("%.2f" % interval).replace(".", "." + WORD_JOINER)
    return "间隔%s%s秒" % [NBSP, amount]

static func stats_line(key: String, level: int) -> String:
    if not Catalog.WEAPONS.has(key): return ""
    var data: Dictionary = Catalog.WEAPONS[key]
    var lvl: int = clampi(level, 1, Growth.MAX_WEAPON_LEVEL)
    var damage: float = float(data["damage"]) * (1.0 + float(lvl - 1) * 0.35)
    var divisor: float = 1.0
    if Catalog.EXPANDED_IDS.has(key):
        divisor = 1.0 + float(lvl - 1) * 0.08
    elif not Catalog.NEW_IDS.has(key):
        divisor = 1.0 + float(lvl - 1) * 0.12
    var interval: float = float(data["cooldown"]) / divisor
    if key == "staff":
        return "每弹伤害 %.1f × %d 弹｜%s" % [damage, Evolution.shot_count(key, lvl), interval_phrase(interval)]
    return "伤害 %.1f · %s" % [damage, interval_phrase(interval)]
static func links(key: String) -> String:
    return Catalog.link_details_text(key)

static func attack(key: String,level: int) -> String:
    if key=="spear" and level>=3: return "朝目标扇面刺出骨矛，\n贯穿扇面内的沿途敌人。"
    if key=="totem" and level>=5: return "四跃连锁并向旁侧分叉，\n可短暂麻痹且同敌一生仅一次，冷却完毕后召唤天雷。"
    if key=="totem" and level>=3: return "雷击跳跃，最多连锁 4 敌，\n命中时可短暂麻痹，同敌一生仅一次。"
    if key=="totem": return "雷击跳跃，最多连锁 %d 敌，\n每次跳跃伤害逐步递减。" % (4 if level>=3 else 3)
    if key=="staff" and level>=5: return "向目标同时发射多枚符弹，\n只有伤害；冷却完毕后在身旁展开符阵轰击。"
    if key=="firepot" and level>=5: return "抛出火壶形成火场，\n冷却完毕后召炎柱砸向敌群。"
    if key=="boomerang" and level>=3: return "连续 %d 轮掷出并飞回，\n每轮去程、回程各命中一次。" % (3 if level>=5 else 2)
    return str(COPY[key][1]) if COPY.has(key) else ""
const MILESTONE_DESC := {
    "club": ["每3击触发震荡冲击波", "每2击触发大范围震荡冲击波"],
    "axe": ["击杀敌人触发旋风裂斩", "击杀与每3击触发大范围裂斩"],
    "blade": ["每4击追加一次高速穿刺连斩", "每3击触发范围刃风连斩"],
    "sling": ["每次发射2枚石弹", "每次发射3枚石弹，命中额外弹射1次"],
    "powder": ["爆炸后残留灼烧烟场", "爆炸向四周分裂4枚破片并扩大范围"],
    "staff": ["每次发射4枚符能弹", "每次5枚且穿透+1，定期展开符阵轰击"],
    "spear": ["向前方扇面同时刺出多道骨矛", "往返双重贯刺，覆盖更广扇面"],
    "hammer": ["跃砸落地追加震荡余波", "连续跃砸两次，震击更大范围"],
    "boomerang": ["连续投掷2轮往返骨镖", "连续投掷3轮往返骨镖"],
    "totem": ["4敌连锁雷击并概率麻痹（同敌限1次）", "连锁分叉并定期召天雷，高概率劈出赤雷"],
    "bonebow": ["每次齐射2支贯穿骨箭", "每次齐射3支，最大穿透提升至5敌"],
    "firepot": ["每次抛出2只火种壶", "每次抛出3只并定期召炎柱砸向敌群"],
    "wardrum": ["三拍震波扩大范围", "强力四拍大范围震波扫场"],
    "crystal": ["晶簇可连续引爆2次", "更大引爆范围，迸射10道贯晶"]
}
static func abilities(key: String,shown: int,owned: int=0) -> String:
    var labels: Array=Evolution.MILESTONES.get(key,["进阶","觉醒"])
    var descs: Array=MILESTONE_DESC.get(key,["",""])
    var d0: String=("（"+str(descs[0])+"）") if not str(descs[0]).is_empty() else ""
    var d1: String=("（"+str(descs[1])+"）") if not str(descs[1]).is_empty() else ""
    if shown>=5: return ("本次觉醒" if owned<5 else "已含觉醒")+" · "+str(labels[1])+d1+"\n已含进阶 · "+str(labels[0])+d0
    if shown>=3: return ("本次进阶" if owned<3 else "已含进阶")+" · "+str(labels[0])+d0+"\n5级觉醒 · "+str(labels[1])+d1
    return "3级进阶 · "+str(labels[0])+d0+"\n5级觉醒 · "+str(labels[1])+d1
