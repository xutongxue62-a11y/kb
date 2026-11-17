extends RefCounted
const Growth=preload("res://src/growth.gd")
static func plain(key: String) -> String:
    if not Growth.BUFFS.has(key): return ""
    return str(Growth.BUFFS[key].description).replace(" 个百分点","%")
static func headline(key: String) -> String:
    if key=="pet": return "幼龙自动扑咬"
    if key=="drone": return "符能弹自动点射"
    if key=="pierce": return "额外穿透 1 个敌人"
    if key=="ricochet": return "额外弹射 1 次"
    var first: String=plain(key).get_slice("\n",0)
    var limit: int=first.find(" · 最多")
    return first.substr(0,limit) if limit>=0 else first
static func detail(key: String) -> String:
    if key=="pet": return "幼龙跟随角色自动扑咬。\n再次强化提升伤害和攻速。"
    if key=="drone": return "飞行器跟随并自动点射。\n再次强化提升伤害和攻速。"
    if key=="pierce": return "石弹、符能弹可贯穿敌人。\n火药范围弹不参与。"
    if key=="ricochet": return "石弹、符能弹可弹向邻敌。\n同一发不重复命中同一敌人。"
    var parts: PackedStringArray=plain(key).split("\n")
    return parts[1] if parts.size()>1 else "每次选择增加一层强化。"
static func limit(key: String) -> String:
    # Layers no longer have a cap (batch 3); the draw weight keeps falling
    # as the stack grows, so deep stacks stay rare on their own.
    return "可无限叠加 · 层数越高越少见"
