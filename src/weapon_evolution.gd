extends RefCounted

const MILESTONES = {
    "club":["震荡重击","连续震荡"],"axe":["破阵溅斩","旋风劈斩"],"blade":["追影斩","交叉追影"],
    "sling":["双石齐射","回弹三连"],"powder":["余烬炮弹","碎石爆破"],"staff":["四重符弹","五芒贯穿"],
    "spear":["扇面贯刺","回身连刺"],"hammer":["扩散震波","二段重砸"],"boomerang":["双轮回旋","三轮回旋"],
    "totem":["四跃闪电","分叉雷链"],"bonebow":["双弩齐发","三箭贯阵"],"firepot":["双壶铺火","三壶燎原"],
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
