extends RefCounted

# Independent resource bands, rather than the old one-XP/one-coin per enemy.
# LOOT_SCALE is a modest generosity cut: kills still drop gold and XP, just a bit less.
const LOOT_SCALE: float = 0.75
const BLOOD_PACK_CHANCE: float = 0.03
const BLOOD_PACK_HEAL: float = 2.0
const ELITE_CHEST_CHANCE: float = 0.5
const BANDS={
    "hunter":[1,2,1,2], "charger":[2,4,2,3], "spitter":[2,3,2,3],
    "tank":[3,6,3,5], "raptor":[2,4,2,3], "thrower":[3,5,2,4],
    "armored":[5,8,4,6], "boss":[18,26,10,16]
}

static func _scaled(amount: int, random: RandomNumberGenerator) -> int:
    # Round the fraction probabilistically: small rewards still vary and the
    # 0.75 scale affects their average instead of rounding every 2 back to 2.
    var scaled: float = maxf(1.0, float(amount) * LOOT_SCALE)
    var whole: int = floori(scaled)
    return whole + (1 if random.randf() < scaled - float(whole) else 0)

static func enemy_reward(kind: String,stage: int,elite: bool,size: float,random: RandomNumberGenerator) -> Dictionary:
    var band: Array=BANDS.get(kind,BANDS.hunter)
    var stage_bonus: int=mini(8,maxi(0,stage-1)/4)
    var size_bonus: int=clampi(floori((size-62.0)/25.0),0,3)
    var multiplier:=2 if elite else 1
    var coin: int=_scaled(random.randi_range(int(band[0])+stage_bonus+size_bonus,int(band[1])+stage_bonus*2+size_bonus)*multiplier,random)
    var experience: int=_scaled(random.randi_range(int(band[2])+stage_bonus/2,int(band[3])+stage_bonus+size_bonus)*multiplier,random)
    return {"coin":coin,"xp":experience}

static func rock_reward(random: RandomNumberGenerator) -> Dictionary:
    return {"coin":_scaled(random.randi_range(1,2),random),"xp":_scaled(random.randi_range(1,2),random)}

# Small regular monsters only. Bosses and elites never drop a health pack.
static func should_drop_blood_pack(kind: String, elite: bool, random: RandomNumberGenerator) -> bool:
    if elite or kind == "boss":
        return false
    return random.randf() < BLOOD_PACK_CHANCE
