extends RefCounted

const TRIAL_IDS = ["club", "axe", "blade", "sling", "powder", "staff"]
const NEW_IDS = ["spear", "hammer", "boomerang", "totem"]
const EXPANDED_IDS = ["bonebow", "firepot", "wardrum", "crystal"]
const IDS = ["club", "axe", "blade", "sling", "powder", "staff", "spear", "hammer", "boomerang", "totem", "bonebow", "firepot", "wardrum", "crystal"]
const POWDER_RANGE: float = 340.0
const WEAPONS = {
    "club": {"name": "木棒", "kind": "melee", "damage": 7.5, "cooldown": 0.32, "orbit_speed": 10.0, "size": 43.0, "color": Color("#d9a65c"), "description": "7.5 重击 · 一击小怪\n均衡环绕，稳健击退"},
    "axe": {"name": "石斧", "kind": "melee", "damage": 13.5, "cooldown": 0.62, "orbit_speed": 6.8, "size": 46.0, "color": Color("#e8d8b2"), "description": "13.5 劈砍 · 重斧高伤\n沉重挥击，大片破阵"},
    "blade": {"name": "骨刃", "kind": "melee", "damage": 5.5, "cooldown": 0.12, "orbit_speed": 15.0, "size": 38.0, "color": Color("#a2e6ec"), "description": "5.5 切割 · 极速高频\n轻快环绕，连续收割"},
    "sling": {"name": "弹弓", "kind": "ranged", "damage": 2.5, "cooldown": 0.30, "range": 360.0, "speed": 620.0, "size": 33.0, "color": Color("#b88b5b"), "description": "2.5 石弹 · 快速连射\n安全射程，自动瞄准"},
    "powder": {"name": "木质火药筒", "kind": "ranged", "damage": 13.0, "cooldown": 1.37, "range": POWDER_RANGE, "speed": 330.0, "size": 43.0, "color": Color("#d48a52"), "description": "13.0 重炮 · 范围高爆\n装填较慢，范围轰炸"},
    "staff": {"name": "魔法杖", "kind": "ranged", "damage": 1.6, "cooldown": 0.72, "range": 300.0, "speed": 450.0, "size": 42.0, "color": Color("#8db49b"), "description": "每弹 1.6 · 三枚符能\n纯粹伤害，5级展开符阵轰击"},
    "spear": {"name": "骨矛", "kind": "special", "damage": 7.4, "cooldown": 0.54, "range": 185.0, "speed": 600.0, "size": 58.0, "color": Color("#edddb3"), "description": "定向贯刺 · 一线穿敌\n保持距离，刺出收回"},
    "hammer": {"name": "石槌", "kind": "special", "damage": 20.0, "cooldown": 2.00, "range": 250.0, "speed": 500.0, "size": 50.0, "color": Color("#b5a98c"), "description": "跃空重砸 · 超重震击\n间隔较长，飞跃重砸大片敌群"},
    "boomerang": {"name": "回旋骨镖", "kind": "special", "damage": 3.6, "cooldown": 0.76, "range": 300.0, "speed": 540.0, "size": 42.0, "color": Color("#ebcc87"), "description": "掷出再返回身边\n往返各可命中一次"},
    "totem": {"name": "雷鸣图腾", "kind": "special", "damage": 3.4, "cooldown": 0.68, "range": 320.0, "speed": 600.0, "size": 48.0, "color": Color("#78bac3"), "description": "连锁雷击 · 最多三敌\n3级起短暂麻痹，同敌一生仅一次"},
    "bonebow": {"name": "骨弩", "kind": "special", "damage": 4.0, "cooldown": 0.64, "range": 430.0, "speed": 660.0, "size": 48.0, "color": Color("#e8d8ad"), "description": "骨箭直射 · 穿透三敌\n真实飞行，沿途贯穿"},
    "firepot": {"name": "火种壶", "kind": "special", "damage": 2.2, "cooldown": 1.60, "range": 300.0, "speed": 340.0, "size": 43.0, "color": Color("#e89a4c"), "description": "抛壶落地 · 延迟燃烧\n5级召炎柱砸向敌群"},
    "wardrum": {"name": "战鼓", "kind": "special", "damage": 3.2, "cooldown": 1.26, "range": 148.0, "speed": 440.0, "size": 49.0, "color": Color("#d5ac64"), "description": "三拍鼓震 · 近身扩环\n声波逐圈扫过敌人"},
    "crystal": {"name": "晶簇", "kind": "special", "damage": 10.5, "cooldown": 0.95, "range": 290.0, "speed": 520.0, "size": 45.0, "color": Color("#b09cdb"), "description": "10.5 晶爆 · 迅捷布雷\n落地瞬爆并迸射八向贯晶"}
}
const LINKS = {
    "none": {"id": "none", "name": "不联动", "kind": "none", "weapons": [], "suppressed": [], "cooldown_multiplier": 1.0, "range": POWDER_RANGE, "enchanted": false, "summary": "不联动\n六件武器独立攻击", "benefit": "各武器保持独立攻击", "cost": "无联动改造"},
    "rune_shell": {"id": "rune_shell", "name": "魔法炮", "kind": "rune", "weapons": ["powder", "staff"], "suppressed": ["staff"], "cooldown_multiplier": 1.5, "range": POWDER_RANGE, "enchanted": true, "summary": "魔法炮\n炮弹化为符能爆炸并留下灼烧\n魔法杖停止独立发射", "benefit": "魔法杖与火药筒组成魔法炮，炮弹化为符能爆炸并留下灼烧", "cost": "魔法杖停止独立发射，火药筒装填间隔增加50%"},
    "chain_club": {"id": "chain_club", "name": "锁链木棒", "kind": "chain", "weapons": ["powder", "club"], "suppressed": ["club"], "cooldown_multiplier": 1.15, "range": 210.0, "enchanted": false, "summary": "锁链木棒\n弹射往返；射程缩短\n失去环绕和普通炮弹", "benefit": "木棒从火药筒炮口弹出并弹射往返", "cost": "木棒不再环绕护身，火药筒不发普通炮弹；射程缩至210"},
    "chain_axe": {"id": "chain_axe", "name": "锁链石斧", "kind": "chain", "weapons": ["powder", "axe"], "suppressed": ["axe"], "cooldown_multiplier": 1.15, "range": 210.0, "enchanted": false, "summary": "锁链石斧\n弹射往返；射程缩短\n失去环绕和普通炮弹", "benefit": "石斧从火药筒炮口弹出并弹射往返", "cost": "石斧不再环绕护身，火药筒不发普通炮弹；射程缩至210"},
    "chain_blade": {"id": "chain_blade", "name": "锁链骨刃", "kind": "chain", "weapons": ["powder", "blade"], "suppressed": ["blade"], "cooldown_multiplier": 1.15, "range": 210.0, "enchanted": false, "summary": "锁链骨刃\n弹射往返；射程缩短\n失去环绕和普通炮弹", "benefit": "骨刃从火药筒炮口弹出并弹射往返", "cost": "骨刃不再环绕护身，火药筒不发普通炮弹；射程缩至210"},
    "fire_drum": {"id":"fire_drum","name":"鼓风燎原","kind":"fire_drum","weapons":["firepot","wardrum"],"suppressed":[],"cooldown_multiplier":1.15,"reload_weapon":"firepot","range":300.0,"enchanted":false,"summary":"鼓风燎原\n鼓波扩散现有火场\n火种壶装填慢15%","benefit":"鼓波扩散并增强已有火场","cost":"仅鼓波接触的已有火场增强一次；火种壶装填慢15%"},
    "thunder_crystal": {"id":"thunder_crystal","name":"雷晶共鸣","kind":"thunder_crystal","weapons":["totem","crystal"],"suppressed":[],"cooldown_multiplier":1.15,"reload_weapon":"totem","range":320.0,"enchanted":false,"summary":"雷晶共鸣\n雷击充能附近晶簇\n图腾施法慢15%","benefit":"雷击为附近晶簇充能，触发更强碎晶","cost":"雷击需落在晶簇附近；图腾施法慢15%，不强化无关武器"},
    "storm_arrow": {"id":"storm_arrow","name":"导雷骨箭","kind":"storm_arrow","weapons":["bonebow","totem"],"suppressed":["totem"],"cooldown_multiplier":1.18,"reload_weapon":"bonebow","range":430.0,"enchanted":false,"summary":"导雷骨箭\n弩箭命中后导雷\n图腾改为给骨弩注能","benefit":"骨箭命中后向附近敌人导雷","cost":"图腾停止独立攻击；骨弩装填慢18%，命中才导雷"},
    "fire_cannon": {"id":"fire_cannon","name":"烈焰火炮","kind":"fire_enchant","weapons":["firepot","powder"],"suppressed":["firepot"],"cooldown_multiplier":1.18,"reload_weapon":"powder","range":POWDER_RANGE,"enchanted":false,"summary":"烈焰火炮\n炮弹爆炸始终留下火场\n火种壶停止独立投掷","benefit":"火药筒爆炸始终留下燃烧火场","cost":"火种壶停止独立投掷，火药筒装填变慢"},
    "fire_arrow": {"id":"fire_arrow","name":"燃骨箭","kind":"fire_enchant","weapons":["firepot","bonebow"],"suppressed":["firepot"],"cooldown_multiplier":1.18,"reload_weapon":"bonebow","range":430.0,"enchanted":false,"summary":"燃骨箭\n骨箭命中点燃并留下火场\n火种壶停止独立投掷","benefit":"骨箭命中点燃敌人，并留下小片火场","cost":"火种壶停止独立投掷，骨弩装填变慢"},
    "fire_sling": {"id":"fire_sling","name":"燃石弹","kind":"fire_enchant","weapons":["firepot","sling"],"suppressed":["firepot"],"cooldown_multiplier":1.18,"reload_weapon":"sling","range":360.0,"enchanted":false,"summary":"燃石弹\n石弹命中点燃并留下火场\n火种壶停止独立投掷","benefit":"石弹命中点燃并留下小片火场","cost":"火种壶停止独立投掷，弹弓装填变慢"},
    "fire_hammer": {"id":"fire_hammer","name":"熔火重砸","kind":"fire_enchant","weapons":["firepot","hammer"],"suppressed":["firepot"],"cooldown_multiplier":1.20,"reload_weapon":"hammer","range":250.0,"enchanted":false,"summary":"熔火重砸\n落点炸出大片持久熔火场\n火种壶停止独立投掷","benefit":"石槌砸地炸出更大更猛的熔火场","cost":"火种壶停止独立投掷，石槌挥击变慢"},
    "fire_boomerang": {"id":"fire_boomerang","name":"焚风骨镖","kind":"fire_enchant","weapons":["firepot","boomerang"],"suppressed":["firepot"],"cooldown_multiplier":1.18,"reload_weapon":"boomerang","range":300.0,"enchanted":false,"summary":"焚风骨镖\n往返命中留下小片火场\n火种壶停止独立投掷","benefit":"骨镖往返命中时留下小片火场","cost":"火种壶停止独立投掷，骨镖装填变慢"},
    "rune_arrow": {"id":"rune_arrow","name":"符能骨箭","kind":"rune_enchant","weapons":["staff","bonebow"],"suppressed":["staff"],"cooldown_multiplier":1.16,"reload_weapon":"bonebow","range":430.0,"enchanted":true,"summary":"符能骨箭\n骨箭命中追加符能爆发\n魔法杖停止独立发射","benefit":"骨箭附上符能，命中时额外爆发魔力","cost":"魔法杖停止独立发射，骨弩装填变慢"},
    "rune_sling": {"id":"rune_sling","name":"符能弹","kind":"rune_enchant","weapons":["staff","sling"],"suppressed":["staff"],"cooldown_multiplier":1.16,"reload_weapon":"sling","range":360.0,"enchanted":true,"summary":"符能弹\n石弹命中追加符能爆发\n魔法杖停止独立发射","benefit":"石弹附上符能，命中时额外爆发魔力","cost":"魔法杖停止独立发射，弹弓装填变慢"},
    "rune_boomerang": {"id":"rune_boomerang","name":"符能骨镖","kind":"rune_enchant","weapons":["staff","boomerang"],"suppressed":["staff"],"cooldown_multiplier":1.16,"reload_weapon":"boomerang","range":300.0,"enchanted":true,"summary":"符能骨镖\n骨镖命中追加符能爆发\n魔法杖停止独立发射","benefit":"骨镖附上符能，命中时额外爆发魔力","cost":"魔法杖停止独立发射，骨镖装填变慢"},
    "fire_axe": {"id":"fire_axe","name":"焚石斧","kind":"fire_enchant","weapons":["firepot","axe"],"suppressed":["firepot"],"cooldown_multiplier":1.18,"reload_weapon":"axe","range":80.0,"enchanted":false,"summary":"焚石斧\n石斧命中点燃并留下火场\n火种壶停止独立投掷","benefit":"石斧命中点燃敌人，并留下小片火场","cost":"火种壶停止独立投掷，石斧挥击变慢"},
    "fire_blade": {"id":"fire_blade","name":"燃骨刃","kind":"fire_enchant","weapons":["firepot","blade"],"suppressed":["firepot"],"cooldown_multiplier":1.18,"reload_weapon":"blade","range":80.0,"enchanted":false,"summary":"燃骨刃\n骨刃命中点燃并留下火场\n火种壶停止独立投掷","benefit":"骨刃命中点燃敌人，并留下小片火场","cost":"火种壶停止独立投掷，骨刃挥击变慢"},
    "fire_club": {"id":"fire_club","name":"燃木重击","kind":"fire_enchant","weapons":["firepot","club"],"suppressed":["firepot"],"cooldown_multiplier":1.18,"reload_weapon":"club","range":80.0,"enchanted":false,"summary":"燃木重击\n木棒命中点燃并留下火场\n火种壶停止独立投掷","benefit":"木棒命中点燃敌人，并留下小片火场","cost":"火种壶停止独立投掷，木棒挥击变慢"},
    "fire_spear": {"id":"fire_spear","name":"焚骨矛","kind":"fire_enchant","weapons":["firepot","spear"],"suppressed":["firepot"],"cooldown_multiplier":1.18,"reload_weapon":"spear","range":185.0,"enchanted":false,"summary":"焚骨矛\n骨矛命中点燃并留下火场\n火种壶停止独立投掷","benefit":"骨矛命中点燃敌人，并留下小片火场","cost":"火种壶停止独立投掷，骨矛装填变慢"},
    "rune_hammer": {"id":"rune_hammer","name":"符能重砸","kind":"rune_enchant","weapons":["staff","hammer"],"suppressed":["staff"],"cooldown_multiplier":1.20,"reload_weapon":"hammer","range":250.0,"enchanted":true,"summary":"符能重砸\n落点触发强力符能爆发与符阵\n魔法杖停止独立发射","benefit":"石槌砸击触发大范围符能爆发并留符阵","cost":"魔法杖停止独立发射，石槌挥击变慢"},
    "rune_axe": {"id":"rune_axe","name":"符能石斧","kind":"rune_enchant","weapons":["staff","axe"],"suppressed":["staff"],"cooldown_multiplier":1.16,"reload_weapon":"axe","range":80.0,"enchanted":true,"summary":"符能石斧\n石斧命中追加符能爆发\n魔法杖停止独立发射","benefit":"石斧附上符能，命中时额外爆发魔力","cost":"魔法杖停止独立发射，石斧挥击变慢"},
    "rune_blade": {"id":"rune_blade","name":"符能骨刃","kind":"rune_enchant","weapons":["staff","blade"],"suppressed":["staff"],"cooldown_multiplier":1.16,"reload_weapon":"blade","range":80.0,"enchanted":true,"summary":"符能骨刃\n骨刃命中追加符能爆发\n魔法杖停止独立发射","benefit":"骨刃附上符能，命中时额外爆发魔力","cost":"魔法杖停止独立发射，骨刃挥击变慢"},
    "rune_club": {"id":"rune_club","name":"符能木棒","kind":"rune_enchant","weapons":["staff","club"],"suppressed":["staff"],"cooldown_multiplier":1.16,"reload_weapon":"club","range":80.0,"enchanted":true,"summary":"符能木棒\n木棒命中追加符能爆发\n魔法杖停止独立发射","benefit":"木棒附上符能，命中时额外爆发魔力","cost":"魔法杖停止独立发射，木棒挥击变慢"},
    "rune_spear": {"id":"rune_spear","name":"符能骨矛","kind":"rune_enchant","weapons":["staff","spear"],"suppressed":["staff"],"cooldown_multiplier":1.16,"reload_weapon":"spear","range":185.0,"enchanted":true,"summary":"符能骨矛\n骨矛命中追加符能爆发\n魔法杖停止独立发射","benefit":"骨矛附上符能，命中时额外爆发魔力","cost":"魔法杖停止独立发射，骨矛装填变慢"},
    "thunder_shell": {"id":"thunder_shell","name":"导雷火炮","kind":"thunder_enchant","weapons":["totem","powder"],"suppressed":["totem"],"cooldown_multiplier":1.18,"reload_weapon":"powder","range":POWDER_RANGE,"enchanted":false,"summary":"导雷火炮\n炮弹爆炸后向附近敌人导雷\n图腾改为给火药筒注能","benefit":"火药筒爆炸后向附近敌人导雷","cost":"图腾停止独立攻击；火药筒装填变慢，爆炸才导雷"},
    "thunder_sling": {"id":"thunder_sling","name":"导雷石弹","kind":"thunder_enchant","weapons":["totem","sling"],"suppressed":["totem"],"cooldown_multiplier":1.18,"reload_weapon":"sling","range":360.0,"enchanted":false,"summary":"导雷石弹\n石弹命中后向附近敌人导雷\n图腾改为给弹弓注能","benefit":"石弹命中后向附近敌人导雷","cost":"图腾停止独立攻击；弹弓装填变慢，命中才导雷"},
    "thunder_hammer": {"id":"thunder_hammer","name":"引雷重砸","kind":"thunder_enchant","weapons":["totem","hammer"],"suppressed":["totem"],"cooldown_multiplier":1.30,"reload_weapon":"hammer","range":250.0,"enchanted":false,"summary":"引雷重砸\n改砸地为举锤引一道巨雷轰击大片敌群\n图腾改为给石槌注能","benefit":"石槌改为举锤引下一道从天而降的大雷电轰击整片敌群，并在地面留下雷电裂纹","cost":"图腾停止独立攻击；石槌不再砸地裂坑且间隔变慢"},
    "thunder_axe": {"id":"thunder_axe","name":"引雷石斧","kind":"thunder_enchant","weapons":["totem","axe"],"suppressed":["totem"],"cooldown_multiplier":1.18,"reload_weapon":"axe","range":80.0,"enchanted":false,"summary":"引雷石斧\n石斧命中后向附近敌人导雷\n图腾改为给石斧注能","benefit":"石斧命中后向附近敌人导雷","cost":"图腾停止独立攻击；石斧挥击变慢，命中才导雷"},
    "thunder_blade": {"id":"thunder_blade","name":"引雷骨刃","kind":"thunder_enchant","weapons":["totem","blade"],"suppressed":["totem"],"cooldown_multiplier":1.18,"reload_weapon":"blade","range":80.0,"enchanted":false,"summary":"引雷骨刃\n骨刃命中后向附近敌人导雷\n图腾改为给骨刃注能","benefit":"骨刃命中后向附近敌人导雷","cost":"图腾停止独立攻击；骨刃挥击变慢，命中才导雷"},
    "thunder_club": {"id":"thunder_club","name":"引雷木棒","kind":"thunder_enchant","weapons":["totem","club"],"suppressed":["totem"],"cooldown_multiplier":1.18,"reload_weapon":"club","range":80.0,"enchanted":false,"summary":"引雷木棒\n木棒命中后向附近敌人导雷\n图腾改为给木棒注能","benefit":"木棒命中后向附近敌人导雷","cost":"图腾停止独立攻击；木棒挥击变慢，命中才导雷"},
    "thunder_boomerang": {"id":"thunder_boomerang","name":"导雷骨镖","kind":"thunder_enchant","weapons":["totem","boomerang"],"suppressed":["totem"],"cooldown_multiplier":1.18,"reload_weapon":"boomerang","range":300.0,"enchanted":false,"summary":"导雷骨镖\n骨镖命中后向附近敌人导雷\n图腾改为给骨镖注能","benefit":"骨镖命中后向附近敌人导雷","cost":"图腾停止独立攻击；骨镖装填变慢，命中才导雷"},
    "thunder_spear": {"id":"thunder_spear","name":"导雷骨矛","kind":"thunder_enchant","weapons":["totem","spear"],"suppressed":["totem"],"cooldown_multiplier":1.18,"reload_weapon":"spear","range":185.0,"enchanted":false,"summary":"导雷骨矛\n骨矛命中后向附近敌人导雷\n图腾改为给骨矛注能","benefit":"骨矛命中后向附近敌人导雷","cost":"图腾停止独立攻击；骨矛装填变慢，命中才导雷"}
}
const LINK_ORDER = ["none", "rune_shell", "chain_club", "chain_axe", "chain_blade", "fire_drum", "thunder_crystal", "storm_arrow", "fire_cannon", "fire_arrow", "fire_sling", "fire_hammer", "fire_boomerang", "fire_axe", "fire_blade", "fire_club", "fire_spear", "rune_arrow", "rune_sling", "rune_boomerang", "rune_hammer", "rune_axe", "rune_blade", "rune_club", "rune_spear", "thunder_shell", "thunder_sling", "thunder_hammer", "thunder_axe", "thunder_blade", "thunder_club", "thunder_boomerang", "thunder_spear"]
const DINOS = {
    "hunter": {"hp": 5.0, "speed": 112.0, "radius": 22.0, "size": 62.0},
    "charger": {"hp": 10.0, "speed": 66.0, "radius": 28.0, "size": 78.0},
    "spitter": {"hp": 7.0, "speed": 62.0, "radius": 23.0, "size": 68.0},
    "tank": {"hp": 22.0, "speed": 45.0, "radius": 33.0, "size": 91.0},
    "boss": {"hp": 160.0, "speed": 54.0, "radius": 56.0, "size": 158.0},
    "raptor": {"hp":7.5,"speed":88.0,"radius":18.0,"size":70.0},
    "thrower": {"hp":10.0,"speed":48.0,"radius":21.0,"size":75.0},
    "armored": {"hp":24.0,"speed":29.0,"radius":29.0,"size":98.0}
}

const CHARACTER_ORDER = ["caveman", "chief", "barbarian", "hunter", "shaman", "firekeeper", "priest"]
const STARTER_WEAPONS = ["sling", "spear", "club", "bonebow", "staff", "firepot", "totem"]
static var PREVIEW_CHARACTER_UNLOCK: bool = true
const CHARACTER_UNLOCKS = {
    "hunter": {"required_character": "caveman", "required_wave": 5},
    "shaman": {"required_character": "chief", "required_wave": 8},
    "firekeeper": {"required_character": "barbarian", "required_wave": 8},
    "priest": {"required_character": "shaman", "required_wave": 12}
}
const CHARACTERS = {
    "caveman": {
        "id": "caveman",
        "name": "原始人",
        "portrait": "res://assets/characters/v14/caveman_portrait.png",
        "body": "res://assets/characters/v13/caveman_body.png",
        "starting_weapon": "sling",
        "weapon_label": "弹弓",
        "confirm_button": "StartSling",
        "skills": [
            {"id": "double_growth", "name": "举一反三", "description": "角色每升三级可拿两份成长，优先各选一份武器和属性。"},
            {"id": "quick_learner", "name": "学得快", "description": "经验 +10%，拾取范围 +12。"}
        ],
        "modifiers": {
            "xp_multiplier": 1.10,
            "pickup_radius": 12.0
        }
    },
    "chief": {
        "id": "chief",
        "name": "酋长",
        "portrait": "res://assets/characters/v14/chief_portrait.png",
        "body": "res://assets/characters/v13/chief_body.png",
        "starting_weapon": "spear",
        "weapon_label": "骨矛",
        "confirm_button": "StartSpear",
        "skills": [
            {"id": "bone_banner", "name": "骨旗夹击", "description": "骨矛命中立旗 3 秒，旗随出矛协击，伤害为 60%。立旗冷却 8 秒。"},
            {"id": "reach", "name": "部族号令", "description": "射程 +8%，攻速 +4%。"}
        ],
        "modifiers": {
            "range_multiplier": 1.08,
            "attack_speed_bonus": 0.04
        }
    },
    "barbarian": {
        "id": "barbarian",
        "name": "野蛮人",
        "portrait": "res://assets/characters/v14/barbarian_portrait.png",
        "body": "res://assets/characters/v13/barbarian_body.png",
        "starting_weapon": "club",
        "weapon_label": "木棒",
        "confirm_button": "StartClub",
        "skills": [
            {"id": "rage_counter", "name": "以伤换势", "description": "受敌方伤害两次后，下一次近战引发震荡，减伤 50% 持续 1 秒。冷却 8 秒。"},
            {"id": "tough", "name": "厚皮", "description": "生命 +1，减伤 6%。"}
        ],
        "modifiers": {
            "max_hp": 1.0,
            "reduction": 0.06
        }
    },
    "hunter": {
        "id": "hunter",
        "name": "猎手",
        "portrait": "res://assets/characters/v14/hunter_portrait.png",
        "body": "res://assets/characters/v13/hunter_body.png",
        "starting_weapon": "bonebow",
        "weapon_label": "骨弩",
        "confirm_button": "StartBonebow",
        "exclusive_weapon": "bonebow",
        "weapon_blurb": "自动瞄准 · 贯穿直射",
        "skills": [
            {"id": "hunt_mark", "name": "追猎弱点", "description": "骨弩三次命中标记同一敌人，下一发伤害 +80%。每个目标冷却 4 秒。"},
            {"id": "piercing_shot", "name": "穿林骨箭", "description": "骨弩穿透 5 敌，射程 +12%。"}
        ]
    },
    "shaman": {
        "id": "shaman",
        "name": "巫师",
        "portrait": "res://assets/characters/v14/shaman_portrait.png",
        "body": "res://assets/characters/v13/shaman_body.png",
        "starting_weapon": "staff",
        "weapon_label": "魔法杖",
        "confirm_button": "StartStaff",
        "exclusive_weapon": "staff",
        "weapon_blurb": "自动瞄准 · 符能散射",
        "skills": [
            {"id": "rune_echo", "name": "回响符印", "description": "每第三轮法杖齐射留下符印，下一轮从符印补射 55% 伤害的符弹。"},
            {"id": "five_runes", "name": "五芒符阵", "description": "魔法杖发射 5 枚略带追踪的符弹，每枚伤害 +3%。"}
        ]
    },
    "firekeeper": {
        "id": "firekeeper",
        "name": "掌火人",
        "portrait": "res://assets/characters/v14/firekeeper_portrait.png",
        "body": "res://assets/characters/v13/firekeeper_body.png",
        "starting_weapon": "firepot",
        "weapon_label": "火种壶",
        "confirm_button": "StartFirepot",
        "exclusive_weapon": "firepot",
        "weapon_blurb": "自动瞄准 · 定点火场",
        "skills": [
            {"id": "living_fire", "name": "活火", "description": "重叠的火种壶火场合成追敌火带，持续 2 秒。冷却 6 秒。"},
            {"id": "living_ember", "name": "薪火更盛", "description": "火种壶火场更大、更久，灼烧伤害 +3%。生命 +1。"}
        ],
        "modifiers": {
            "max_hp": 1.0
        }
    },
    "priest": {
        "id": "priest",
        "name": "祭祀",
        "portrait": "res://assets/characters/v14/priest_portrait.png",
        "body": "res://assets/characters/v13/priest_body.png",
        "starting_weapon": "totem",
        "weapon_label": "雷鸣图腾",
        "confirm_button": "StartTotem",
        "exclusive_weapon": "totem",
        "weapon_blurb": "自动瞄准 · 连锁雷击",
        "skills": [
            {"id": "lightning_altar", "name": "雷坛回路", "description": "累计六次雷击命中立坛。下一轮图腾放电回击一名目标，伤害为 65%。"},
            {"id": "sky_chain", "name": "连天之雷", "description": "雷鸣图腾连锁 5 敌，跳跃衰减稍低。"}
        ]
    }
}

static func character(id: String) -> Dictionary:
    if CHARACTERS.has(id):
        return CHARACTERS[id].duplicate(true)
    return CHARACTERS["caveman"].duplicate(true)

static func character_id_for_weapon(weapon_id: String) -> String:
    for key in CHARACTER_ORDER:
        if str(CHARACTERS[key].get("starting_weapon", "")) == weapon_id:
            return key
    return "caveman"

static func resolve_character_id(character_id: String, starting_weapon: String = "sling") -> String:
    if CHARACTERS.has(character_id):
        return character_id
    return character_id_for_weapon(starting_weapon)

static func normalized_best_waves(progress: Variant) -> Dictionary:
    var result: Dictionary = {}
    if typeof(progress) != TYPE_DICTIONARY:
        return result
    for key in progress:
        if typeof(key) == TYPE_STRING and CHARACTERS.has(key):
            result[key] = maxi(0, int(progress[key]))
    return result

static func best_wave_for(progress: Variant, character_id: String) -> int:
    return int(normalized_best_waves(progress).get(character_id, 0))

static func is_character_unlocked(character_id: String, progress: Variant = {}) -> bool:
    if not CHARACTERS.has(character_id):
        return false
    if not CHARACTER_UNLOCKS.has(character_id):
        return true
    var requirement: Dictionary = CHARACTER_UNLOCKS[character_id]
    return best_wave_for(progress, str(requirement.get("required_character", ""))) >= int(requirement.get("required_wave", 0))

static func can_start_character(character_id: String, progress: Variant = {}) -> bool:
    return is_character_unlocked(character_id, progress) or PREVIEW_CHARACTER_UNLOCK

static func unlock_requirement_text(character_id: String) -> String:
    if not CHARACTER_UNLOCKS.has(character_id):
        return ""
    var requirement: Dictionary = CHARACTER_UNLOCKS[character_id]
    var required_id: String = str(requirement.get("required_character", ""))
    var required_name: String = str(character(required_id).get("name", required_id))
    return "用%s到达第 %d 关解锁" % [required_name, int(requirement.get("required_wave", 0))]

static func shows_preview_unlock(character_id: String, progress: Variant = {}) -> bool:
    return PREVIEW_CHARACTER_UNLOCK and CHARACTERS.has(character_id) and not is_character_unlocked(character_id, progress)

static func exclusive_weapon_id(character_id: String) -> String:
    return str(character(character_id).get("exclusive_weapon", ""))

static func has_weapon_mastery(character_id: String, weapon_id: String) -> bool:
    return not weapon_id.is_empty() and exclusive_weapon_id(character_id) == weapon_id

static func exclusive_bonus(character_id: String, weapon_id: String) -> Dictionary:
    if not has_weapon_mastery(character_id, weapon_id):
        return {}
    match weapon_id:
        "bonebow":
            return {"pierce_limit": 5, "range_multiplier": 1.12}
        "staff":
            return {"shot_count": 5, "homing": 1.6, "shot_damage_multiplier": 1.03}
        "firepot":
            return {"area_multiplier": 1.15, "life_multiplier": 1.35, "field_damage_multiplier": 1.03}
        "totem":
            return {"chain_count": 5, "decay": 0.80}
        _:
            return {}

static func is_starter_weapon(weapon_id: String) -> bool:
    return STARTER_WEAPONS.has(weapon_id)

static func apply_character_modifiers(stats: Dictionary, character_id: String) -> Dictionary:
    var profile: Dictionary = character(character_id)
    var mods: Dictionary = profile.get("modifiers", {})
    stats["range_multiplier"] = float(mods.get("range_multiplier", 1.0))
    stats["attack_speed"] = float(stats.get("attack_speed", 1.0)) + float(mods.get("attack_speed_bonus", 0.0))
    stats["damage_multiplier"] = float(stats.get("damage_multiplier", 1.0)) * float(mods.get("damage_multiplier", 1.0))
    stats["reduction"] = 1.0 - (1.0 - float(stats.get("reduction", 0.0))) * (1.0 - float(mods.get("reduction", 0.0)))
    stats["max_hp"] = float(stats.get("max_hp", 8.0)) + float(mods.get("max_hp", 0.0))
    stats["pierce"] = int(stats.get("pierce", 0)) + int(mods.get("pierce", 0))
    stats["xp_multiplier"] = float(stats.get("xp_multiplier", 1.0)) * float(mods.get("xp_multiplier", 1.0))
    stats["pickup_radius"] = float(stats.get("pickup_radius", 100.0)) + float(mods.get("pickup_radius", 0.0))
    stats["close_damage_bonus"] = float(mods.get("close_damage_bonus", 0.0))
    stats["close_damage_range"] = float(mods.get("close_damage_range", 140.0))
    stats["character_id"] = str(profile.get("id", character_id))
    return stats

static func weapon_name(weapon_id: String) -> String:
    return str(WEAPONS[weapon_id]["name"]) if WEAPONS.has(weapon_id) else weapon_id

static func inventory_ids(inventory: Array) -> Array:
    var ids: Array = []
    for item in inventory:
        var key: String = str(item.get("id", "")) if typeof(item) == TYPE_DICTIONARY else str(item)
        if not key.is_empty() and not ids.has(key):
            ids.append(key)
    return ids

static func recipes_for_weapon(weapon_id: String) -> Array:
    var result: Array = []
    if weapon_id.is_empty() or not WEAPONS.has(weapon_id):
        return result
    for key in LINK_ORDER:
        if key == "none":
            continue
        var recipe: Dictionary = LINKS[key]
        if recipe["weapons"].has(weapon_id):
            result.append(recipe.duplicate(true))
    return result

static func partner_id(recipe: Dictionary, weapon_id: String) -> String:
    var weapons: Array = recipe.get("weapons", [])
    if weapons.size() != 2:
        return ""
    if str(weapons[0]) == weapon_id:
        return str(weapons[1])
    if str(weapons[1]) == weapon_id:
        return str(weapons[0])
    return ""

static func recipe_complete(recipe: Dictionary, owned_ids: Array) -> bool:
    var weapons: Array = recipe.get("weapons", [])
    if weapons.is_empty():
        return false
    for weapon_id in weapons:
        if not owned_ids.has(str(weapon_id)):
            return false
    return true

static func benefit_text(recipe: Dictionary) -> String:
    var text: String = str(recipe.get("benefit", "")).strip_edges()
    if not text.is_empty():
        return text
    return str(recipe.get("summary", "")).replace("\n", "；")

static func cost_text(recipe: Dictionary) -> String:
    return str(recipe.get("cost", "")).strip_edges()

static func completing_recipes(weapon_id: String, owned_ids: Array) -> Array:
    var result: Array = []
    if weapon_id.is_empty() or owned_ids.has(weapon_id) or not WEAPONS.has(weapon_id):
        return result
    var held: Array = owned_ids.duplicate()
    held.append(weapon_id)
    for recipe in recipes_for_weapon(weapon_id):
        if recipe_complete(recipe, held) and not recipe_complete(recipe, owned_ids):
            result.append(recipe)
    return result

static func offer_link_text(weapon_id: String, owned_ids: Array) -> String:
    if not WEAPONS.has(weapon_id):
        return ""
    if owned_ids.has(weapon_id):
        return ""
    var ready: Array = completing_recipes(weapon_id, owned_ids)
    if not ready.is_empty():
        var names: PackedStringArray = PackedStringArray()
        for recipe in ready:
            names.append(str(recipe.get("name", "")))
        var first: Dictionary = ready[0]
        return "可联动：%s｜优点：%s｜缺点：%s" % ["、".join(names), benefit_text(first), cost_text(first)]
    var partners: PackedStringArray = PackedStringArray()
    for recipe in recipes_for_weapon(weapon_id):
        var partner: String = partner_id(recipe, weapon_id)
        var label: String = weapon_name(partner)
        if not partner.is_empty() and not partners.has(label):
            partners.append(label)
    if partners.is_empty():
        return ""
    if partners.size() > 2:
        return "可与%s、%s等搭配" % [partners[0], partners[1]]
    return "可与%s搭配" % "、".join(partners)

static func link_details_text(weapon_id: String) -> String:
    var lines: PackedStringArray = PackedStringArray()
    for recipe in recipes_for_weapon(weapon_id):
        var partner: String = weapon_name(partner_id(recipe, weapon_id))
        lines.append("与%s组成「%s」。优点：%s。缺点：%s" % [partner, str(recipe.get("name", "")), benefit_text(recipe), cost_text(recipe)])
    return "\n".join(lines)
