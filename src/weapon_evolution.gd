extends RefCounted

const MILESTONES = {
    "club":["震荡重击","连续震荡"],"axe":["破阵溅斩","旋风劈斩"],"blade":["追影斩","交叉追影"],
    "sling":["双石齐射","回弹三连"],"powder":["余烬炮弹","碎石爆破"],"staff":["四重符弹","五芒符阵"],
    "spear":["扇面贯刺","回身连刺"],"hammer":["扩散震波","二段重砸"],"boomerang":["双轮回旋","三轮回旋"],
    "totem":["四跃闪电","天雷降世"],"bonebow":["双弩齐发","三箭贯阵"],"firepot":["双壶铺火","炎柱燎原"],
    "wardrum":["四拍战歌","五拍终奏"],"crystal":["八向碎晶","二次晶爆"]
}
static func tier(level: int) -> int:
    return 2 if level>=5 else (1 if level>=3 else 0)
static func shot_count(key: String,level: int) -> int:
    var stage: int=tier(level)
    return 3+stage if key=="staff" else 1+stage
static func offer_description(key: String,level: int) -> String:
    var labels: Array=MILESTONES.get(key,["进阶","觉醒"])
    var next: int=level+1
    if next==3: return "3级解锁 · "+labels[0]+"\n5级觉醒 · "+labels[1]
    if next==5: return "5级觉醒 · "+labels[1]+"\n保留已解锁的进阶能力"
    return "3级 · "+labels[0]+"\n5级 · "+labels[1]

const MELEE_IDS = ["club", "axe", "blade", "spear", "hammer"]
const SKY_LIGHTNING_LEVEL: int = 5
const SKY_LIGHTNING_COOLDOWN: float = 9.0
const SKY_LIGHTNING_DAMAGE_MULT: float = 5.5
const SKY_LIGHTNING_RADIUS: float = 92.0
const SKY_LIGHTNING_HEIGHT: float = 240.0
const FIRE_PILLAR_LEVEL: int = 5
const FIRE_PILLAR_COOLDOWN: float = 8.0
const FIRE_PILLAR_DAMAGE_MULT: float = 3.6
const FIRE_PILLAR_RADIUS: float = 78.0
const RUNE_NOVA_LEVEL: int = 5
const RUNE_NOVA_COOLDOWN: float = 7.5
const RUNE_NOVA_DAMAGE_MULT: float = 3.4
const RUNE_NOVA_RADIUS: float = 110.0

static func stage_damage_bonus(level: int) -> float:
    if level >= 10:
        return 3.15
    if level >= 9:
        return 2.75
    if level >= 8:
        return 2.40
    if level >= 7:
        return 2.10
    if level >= 6:
        return 1.85
    if level >= 5:
        return 1.65
    if level >= 4:
        return 1.35
    if level >= 3:
        return 1.25
    return 1.0

static func damage_multiplier(key: String, level: int) -> float:
    var lvl: int = maxi(1, level)
    var base: float = 1.0 + float(lvl - 1) * 0.35
    var mult: float = base * stage_damage_bonus(lvl)
    if key in MELEE_IDS:
        mult *= (1.22 if lvl >= 5 else 1.15)
    elif key == "sling":
        mult *= (1.22 if lvl >= 5 else (1.10 if lvl >= 3 else 1.0))
    elif key == "powder":
        mult *= (1.25 if lvl >= 5 else (1.12 if lvl >= 3 else 1.0))
    elif lvl >= 5 and key in ["firepot", "staff"]:
        mult *= 1.28
    return mult

static func sky_lightning_unlocked(level: int) -> bool:
    return level >= SKY_LIGHTNING_LEVEL

static func fire_pillar_unlocked(level: int) -> bool:
    return level >= FIRE_PILLAR_LEVEL

static func rune_nova_unlocked(level: int) -> bool:
    return level >= RUNE_NOVA_LEVEL

static func sky_lightning_profile(level: int) -> Dictionary:
    return {"unlocked": sky_lightning_unlocked(level), "cooldown": SKY_LIGHTNING_COOLDOWN, "damage_multiplier": SKY_LIGHTNING_DAMAGE_MULT, "radius": SKY_LIGHTNING_RADIUS, "height": SKY_LIGHTNING_HEIGHT}

static func fire_pillar_profile(level: int) -> Dictionary:
    return {"unlocked": fire_pillar_unlocked(level), "cooldown": FIRE_PILLAR_COOLDOWN, "damage_multiplier": FIRE_PILLAR_DAMAGE_MULT, "radius": FIRE_PILLAR_RADIUS}

static func rune_nova_profile(level: int) -> Dictionary:
    return {"unlocked": rune_nova_unlocked(level), "cooldown": RUNE_NOVA_COOLDOWN, "damage_multiplier": RUNE_NOVA_DAMAGE_MULT, "radius": RUNE_NOVA_RADIUS}
