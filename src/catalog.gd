extends RefCounted

const TRIAL_IDS = ["club", "axe", "blade", "sling", "powder", "staff"]
const NEW_IDS = ["spear", "hammer", "boomerang", "totem"]
const EXPANDED_IDS = ["bonebow", "firepot", "wardrum", "crystal"]
const IDS = ["club", "axe", "blade", "sling", "powder", "staff", "spear", "hammer", "boomerang", "totem", "bonebow", "firepot", "wardrum", "crystal"]
const WEAPONS = {
    "club": {"name": "木棒", "kind": "melee", "damage": 8.5, "cooldown": 0.40, "orbit_speed": 10.0, "size": 43.0, "color": Color("#d9a65c"), "description": "8.5 重击 · 一击小怪\n快速环绕，强力击退"},
    "axe": {"name": "石斧", "kind": "melee", "damage": 12.0, "cooldown": 0.60, "orbit_speed": 8.2, "size": 46.0, "color": Color("#e8d8b2"), "description": "12 劈砍 · 近身高伤\n重斧破阵，大片斩击"},
    "blade": {"name": "骨刃", "kind": "melee", "damage": 6.0, "cooldown": 0.20, "orbit_speed": 14.0, "size": 38.0, "color": Color("#a2e6ec"), "description": "6 切割 · 高频环绕\n近距离连续收割"},
    "sling": {"name": "弹弓", "kind": "ranged", "damage": 3.2, "cooldown": 0.42, "range": 360.0, "speed": 620.0, "size": 33.0, "color": Color("#b88b5b"), "description": "3.2 石弹 · 快速连射\n安全射程，自动瞄准"},
    "powder": {"name": "木质火药筒", "kind": "ranged", "damage": 5.0, "cooldown": 1.15, "range": 395.0, "speed": 330.0, "size": 43.0, "color": Color("#d48a52"), "description": "5 炮击 · 范围爆炸\n火焰冲击与烟尘"},
    "staff": {"name": "魔法杖", "kind": "ranged", "damage": 2.0, "cooldown": 0.78, "range": 300.0, "speed": 450.0, "size": 42.0, "color": Color("#8db49b"), "description": "每弹 2 · 三枚符能\n展开散射 / 收束集中"},
    "spear": {"name": "骨矛", "kind": "special", "damage": 9.0, "cooldown": 0.72, "range": 185.0, "speed": 600.0, "size": 58.0, "color": Color("#edddb3"), "description": "定向贯刺 · 一线穿敌\n保持距离，刺出收回"},
    "hammer": {"name": "石槌", "kind": "special", "damage": 16.0, "cooldown": 1.4, "range": 140.0, "speed": 500.0, "size": 50.0, "color": Color("#b5a98c"), "description": "蓄势重砸 · 范围震击\n清理近处成群恐龙"},
    "boomerang": {"name": "回旋骨镖", "kind": "special", "damage": 4.5, "cooldown": 1.05, "range": 300.0, "speed": 540.0, "size": 42.0, "color": Color("#ebcc87"), "description": "掷出再返回身边\n往返各可命中一次"},
    "totem": {"name": "雷鸣图腾", "kind": "special", "damage": 3.5, "cooldown": 0.95, "range": 320.0, "speed": 600.0, "size": 48.0, "color": Color("#78bac3"), "description": "连锁雷击 · 最多三敌\n每次跳跃伤害递减"},
    "bonebow": {"name": "骨弩", "kind": "special", "damage": 6.0, "cooldown": 0.90, "range": 430.0, "speed": 660.0, "size": 48.0, "color": Color("#e8d8ad"), "description": "骨箭直射 · 穿透三敌\n真实飞行，沿途贯穿"},
    "firepot": {"name": "火种壶", "kind": "special", "damage": 2.6, "cooldown": 2.20, "range": 300.0, "speed": 340.0, "size": 43.0, "color": Color("#e89a4c"), "description": "抛壶落地 · 延迟燃烧\n定点火场，持续灼伤"},
    "wardrum": {"name": "战鼓", "kind": "special", "damage": 3.8, "cooldown": 1.75, "range": 148.0, "speed": 440.0, "size": 49.0, "color": Color("#d5ac64"), "description": "三拍鼓震 · 近身扩环\n声波逐圈扫过敌人"},
    "crystal": {"name": "晶簇", "kind": "special", "damage": 7.0, "cooldown": 2.30, "range": 290.0, "speed": 420.0, "size": 45.0, "color": Color("#b09cdb"), "description": "布置晶簇 · 近敌触发\n六向碎晶，各沿弹道"}
}
const LINKS = {
    "none": {"id": "none", "name": "不联动", "kind": "none", "weapons": [], "suppressed": [], "cooldown_multiplier": 1.0, "range": 395.0, "enchanted": false, "summary": "不联动\n六件武器独立攻击", "cost": "无联动改造"},
    "rune_shell": {"id": "rune_shell", "name": "符火炮弹", "kind": "rune", "weapons": ["powder", "staff"], "suppressed": ["staff"], "cooldown_multiplier": 1.5, "range": 395.0, "enchanted": true, "summary": "符火炮弹\n范围灼烧；装填更慢\n法杖不再独立发射", "cost": "魔法杖停止独立发射，火药筒装填间隔增加50%"},
    "chain_club": {"id": "chain_club", "name": "锁链木棒", "kind": "chain", "weapons": ["powder", "club"], "suppressed": ["club"], "cooldown_multiplier": 1.15, "range": 210.0, "enchanted": false, "summary": "锁链木棒\n弹射往返；射程缩短\n失去环绕和普通炮弹", "cost": "木棒不再环绕护身，火药筒不发普通炮弹；射程缩至210"},
    "chain_axe": {"id": "chain_axe", "name": "锁链石斧", "kind": "chain", "weapons": ["powder", "axe"], "suppressed": ["axe"], "cooldown_multiplier": 1.15, "range": 210.0, "enchanted": false, "summary": "锁链石斧\n弹射往返；射程缩短\n失去环绕和普通炮弹", "cost": "石斧不再环绕护身，火药筒不发普通炮弹；射程缩至210"},
    "chain_blade": {"id": "chain_blade", "name": "锁链骨刃", "kind": "chain", "weapons": ["powder", "blade"], "suppressed": ["blade"], "cooldown_multiplier": 1.15, "range": 210.0, "enchanted": false, "summary": "锁链骨刃\n弹射往返；射程缩短\n失去环绕和普通炮弹", "cost": "骨刃不再环绕护身，火药筒不发普通炮弹；射程缩至210"},
    "fire_drum": {"id":"fire_drum","name":"鼓风燎原","kind":"fire_drum","weapons":["firepot","wardrum"],"suppressed":[],"cooldown_multiplier":1.15,"reload_weapon":"firepot","range":300.0,"enchanted":false,"summary":"鼓风燎原\n鼓波扩散现有火场\n火种壶装填慢15%","cost":"仅鼓波接触的已有火场增强一次；火种壶装填慢15%"},
    "thunder_crystal": {"id":"thunder_crystal","name":"雷晶共鸣","kind":"thunder_crystal","weapons":["totem","crystal"],"suppressed":[],"cooldown_multiplier":1.15,"reload_weapon":"totem","range":320.0,"enchanted":false,"summary":"雷晶共鸣\n雷击充能附近晶簇\n图腾施法慢15%","cost":"雷击需落在晶簇附近；图腾施法慢15%，不强化无关武器"},
    "storm_arrow": {"id":"storm_arrow","name":"导雷骨箭","kind":"storm_arrow","weapons":["bonebow","totem"],"suppressed":["totem"],"cooldown_multiplier":1.18,"reload_weapon":"bonebow","range":430.0,"enchanted":false,"summary":"导雷骨箭\n弩箭命中后导雷\n图腾改为给骨弩注能","cost":"图腾停止独立攻击；骨弩装填慢18%，命中才导雷"}
}
const LINK_ORDER = ["none", "rune_shell", "chain_club", "chain_axe", "chain_blade", "fire_drum", "thunder_crystal", "storm_arrow"]
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

const CHARACTER_ORDER = ["caveman", "chief", "barbarian"]
const STARTER_WEAPONS = ["sling", "spear", "club"]
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
            {"id": "quick_learner", "name": "学得快", "description": "经验 +25%，升级更快，成长来得更勤。"},
            {"id": "scavenger", "name": "拾荒手", "description": "拾取范围 +40，掉落更容易收齐。"}
        ],
        "modifiers": {
            "xp_multiplier": 1.25,
            "pickup_radius": 40.0
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
            {"id": "reach", "name": "枪阵延伸", "description": "武器攻击距离 +20%，骨矛更好先手贯刺。"},
            {"id": "command", "name": "部族号令", "description": "攻速 +12%，弹道额外穿透 1 名敌人。"}
        ],
        "modifiers": {
            "range_multiplier": 1.20,
            "attack_speed_bonus": 0.12,
            "pierce": 1
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
            {"id": "tough", "name": "蛮力厚皮", "description": "伤害 +18%，生命 +2，受伤减免 12%。"},
            {"id": "slam", "name": "近身猛击", "description": "靠近敌人 140 距离内，伤害再提高 20%。"}
        ],
        "modifiers": {
            "damage_multiplier": 1.18,
            "max_hp": 2.0,
            "reduction": 0.12,
            "close_damage_bonus": 0.20,
            "close_damage_range": 140.0
        }
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
    if starting_weapon == "spear":
        return "chief"
    return "caveman"

static func is_starter_weapon(weapon_id: String) -> bool:
    return STARTER_WEAPONS.has(weapon_id)

static func apply_character_modifiers(stats: Dictionary, character_id: String) -> Dictionary:
    var profile: Dictionary = character(character_id)
    var mods: Dictionary = profile.get("modifiers", {})
    stats["range_multiplier"] = float(mods.get("range_multiplier", 1.0))
    stats["attack_speed"] = float(stats.get("attack_speed", 1.0)) + float(mods.get("attack_speed_bonus", 0.0))
    stats["damage_multiplier"] = float(stats.get("damage_multiplier", 1.0)) * float(mods.get("damage_multiplier", 1.0))
    stats["reduction"] = float(stats.get("reduction", 0.0)) + float(mods.get("reduction", 0.0))
    stats["max_hp"] = float(stats.get("max_hp", 8.0)) + float(mods.get("max_hp", 0.0))
    stats["pierce"] = int(stats.get("pierce", 0)) + int(mods.get("pierce", 0))
    stats["xp_multiplier"] = float(stats.get("xp_multiplier", 1.0)) * float(mods.get("xp_multiplier", 1.0))
    stats["pickup_radius"] = float(stats.get("pickup_radius", 100.0)) + float(mods.get("pickup_radius", 0.0))
    stats["close_damage_bonus"] = float(mods.get("close_damage_bonus", 0.0))
    stats["close_damage_range"] = float(mods.get("close_damage_range", 140.0))
    return stats
