extends RefCounted

const IDS = ["club", "axe", "blade", "sling", "powder", "staff"]
const WEAPONS = {
    "club": {"name": "木棒", "kind": "melee", "damage": 3.0, "cooldown": 0.55, "size": 37.0, "color": Color("#a96f47"), "description": "环绕重击 · 推开近处恐龙"},
    "axe": {"name": "石斧", "kind": "melee", "damage": 4.5, "cooldown": 0.7, "size": 39.0, "color": Color("#a19c90"), "description": "环绕砍击 · 单次伤害更高"},
    "blade": {"name": "骨刃", "kind": "melee", "damage": 1.9, "cooldown": 0.24, "size": 33.0, "color": Color("#ecdbad"), "description": "环绕切割 · 快速连续命中"},
    "sling": {"name": "投石索", "kind": "ranged", "damage": 2.8, "cooldown": 0.58, "range": 360.0, "speed": 570.0, "size": 33.0, "color": Color("#b88b5b"), "description": "自动投石 · 稳定单体远程"},
    "powder": {"name": "木质火药筒", "kind": "ranged", "damage": 4.0, "cooldown": 1.45, "range": 395.0, "speed": 290.0, "size": 43.0, "color": Color("#d48a52"), "description": "木桶火药弹 · 小范围爆炸"},
    "staff": {"name": "魔法杖", "kind": "ranged", "damage": 1.65, "cooldown": 0.95, "range": 300.0, "speed": 385.0, "size": 42.0, "color": Color("#8db49b"), "description": "三枚符能弹 · 展开散射/收束集中"}
}
const PAIRS = [
    {"id": "break", "name": "裂地重击", "weapons": ["club", "axe"], "hits": 4, "color": Color("#d7b268")},
    {"id": "hunt", "name": "猎手追击", "weapons": ["blade", "sling"], "hits": 5, "color": Color("#e7d1a0")},
    {"id": "rune", "name": "符火爆破", "weapons": ["powder", "staff"], "hits": 4, "color": Color("#8ab3a0")}
]
const TRIPLES = [
    {"id": "quake", "name": "碎骨震波", "weapons": ["club", "axe", "blade"], "hits": 7, "color": Color("#e5be73")},
    {"id": "wildfire", "name": "巫火齐射", "weapons": ["sling", "powder", "staff"], "hits": 6, "color": Color("#a5c2a3")}
]
const DINOS = {
    "hunter": {"hp": 5.0, "speed": 112.0, "radius": 22.0, "size": 62.0},
    "charger": {"hp": 10.0, "speed": 66.0, "radius": 28.0, "size": 78.0},
    "spitter": {"hp": 7.0, "speed": 62.0, "radius": 23.0, "size": 68.0},
    "tank": {"hp": 22.0, "speed": 45.0, "radius": 33.0, "size": 91.0}
}
