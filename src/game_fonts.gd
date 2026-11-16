extends RefCounted
const FALLBACK=preload("res://assets/fonts/NotoSansSC-Variable.ttf")

static func create_system(names: PackedStringArray,weight: int=400) -> SystemFont:
    var result:=SystemFont.new()
    result.font_names=names
    result.font_weight=weight
    var bundled:=FontVariation.new()
    bundled.base_font=FALLBACK
    bundled.variation_opentype={"wght":weight}
    result.fallbacks=[bundled]
    return result
