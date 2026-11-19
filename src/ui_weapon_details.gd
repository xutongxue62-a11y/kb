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
    "staff":["远程 · 符能弹伤害","向目标同时发射多枚符弹，\n展开散射，收束后集中。"],
    "spear":["近战 · 贯刺伤害","朝目标直线刺出骨矛，\n贯穿同一直线上的敌人。"],
    "hammer":["近战 · 范围震击","挥槌重砸近处目标，\n落点周围敌人同时受伤。"],
    "boomerang":["投掷 · 往返命中","掷出骨镖后飞回角色，\n去程、回程各可命中一次。"],
    "totem":["远程 · 连锁雷击","雷击在附近敌人间跳跃，\n逐次跳跃伤害递减。"],
    "bonebow":["远程 · 贯穿骨箭","向目标发射直线骨箭，\n沿飞行路径贯穿多个敌人。"],
    "firepot":["投掷 · 持续灼伤","抛出火壶，落地形成火场，\n持续伤害火场中的敌人。"],
    "wardrum":["范围 · 波纹震击","击鼓向外扩散多道震波，\n波纹扫过敌人时造成伤害。"],
    "crystal":["布置 · 碎晶伤害","布下晶簇，敌人靠近触发，\n向四周发射可命中的碎晶。"]
}
static func attack_type(key: String) -> String: return str(COPY[key][0]) if COPY.has(key) else ""
# The weapon's own numbers at the level on the card, computed with the same
# formulas combat uses: damage grows +35% of base per level; the interval
# divisor differs per weapon family (basic 0.12, expanded 0.08, armory none).
# Buff multipliers are not included — this is the figure cards are compared by.
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
        return "每弹伤害 %.1f × %d 弹｜间隔 %.2f 秒" % [damage, Evolution.shot_count(key, lvl), interval]
    return "伤害 %.1f · 间隔 %.2f 秒" % [damage, interval]
static func links(key: String) -> String:
    return Catalog.link_details_text(key)

static func attack(key: String,level: int) -> String:
    if key=="spear" and level>=3: return "朝目标扇面刺出骨矛，\n贯穿扇面内的沿途敌人。"
    if key=="totem" and level>=5: return "四跃连锁并向旁侧分叉，\n每次跳跃伤害逐步递减。"
    if key=="totem": return "雷击跳跃，最多连锁 %d 敌，\n每次跳跃伤害逐步递减。" % (4 if level>=3 else 3)
    if key=="boomerang" and level>=3: return "连续 %d 轮掷出并飞回，\n每轮去程、回程各命中一次。" % (3 if level>=5 else 2)
    return str(COPY[key][1]) if COPY.has(key) else ""
static func abilities(key: String,shown: int,owned: int=0) -> String:
    var labels: Array=Evolution.MILESTONES.get(key,["进阶","觉醒"])
    if shown>=5: return ("本次觉醒" if owned<5 else "已含觉醒")+" · "+str(labels[1])+"\n已含进阶 · "+str(labels[0])
    if shown>=3: return ("本次进阶" if owned<3 else "已含进阶")+" · "+str(labels[0])+"\n5级觉醒 · "+str(labels[1])
    return "3级进阶 · "+str(labels[0])+"\n5级觉醒 · "+str(labels[1])
