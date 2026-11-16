extends SceneTree
var checks:=0
var failures:=0
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        print("FAIL: "+label)
func _initialize() -> void:
    var path: String="res://src/game_fonts.gd"
    expect(FileAccess.file_exists(path),"release supplies an open-license Chinese font fallback")
    if FileAccess.file_exists(path):
        var helper=load(path)
        var regular: SystemFont=helper.create_system(PackedStringArray(["Missing_Font_For_Portability_Test"]),400)
        expect(regular.font_names[0]=="Missing_Font_For_Portability_Test","factory preserves preferred system font selection")
        expect(regular.fallbacks.size()==1,"missing system fonts have one bundled fallback")
        for character in "原始人大作战购买出售金币层数等级闪避暴击":
            expect(regular.has_char(character.unicode_at(0)),"bundled fallback covers "+character)
        var bold: SystemFont=helper.create_system(PackedStringArray(["Microsoft YaHei"]),800)
        expect(bold.font_weight==800 and bold.fallbacks.size()==1,"display font retains its weight and bundled fallback")
        expect(bold.fallbacks[0] is FontVariation,"variable fallback supports the display weight")
    print("DISTRIBUTION FONTS RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
