extends RefCounted
## Cards and articulated world supports share the same ink art; originals remain archived.
const PATHS: Dictionary = {"pet": "res://assets/supports/v11/pet_raptor.png", "drone": "res://assets/supports/v11/drone_bonewing.png"}
const Rig=preload("res://src/support_rig.gd")
static func texture(key: String) -> Texture2D:
    return Rig.portrait(key) if PATHS.has(key) else null
