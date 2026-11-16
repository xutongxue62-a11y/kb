extends SceneTree
var checks:=0
var failures:=0
class WorldStub extends Node:
    var game_ready:=false
    var hud: Node
    var hero: Node
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void:
    var path: String="res://release/update_boot_state.gd"
    expect(FileAccess.file_exists(path),"startup remembers every failed package and requires explicit game readiness")
    if FileAccess.file_exists(path):
        var State=load(path)
        var folder: String="res://runtime/tests/boot_state_"+str(Time.get_ticks_usec())
        DirAccess.make_dir_recursive_absolute(folder)
        State.write_json(folder.path_join("active.json"),{"tag":"B"})
        State.write_json(folder.path_join("previous.json"),{"tag":"A"})
        expect(State.begin(folder,"active.json",2026111603),"current package records its exact pointer before loading")
        var failed: Dictionary=State.recover(folder)
        expect(failed.highest_failure==2026111603 and failed.failed_builds.has(2026111603),"failed B is remembered")
        expect(not failed.failed_builds.has(2026111602),"previous A can still be tried after B fails")
        expect(not FileAccess.file_exists(folder.path_join("active.json")) and FileAccess.file_exists(folder.path_join("previous.json")),"only failed active pointer is isolated")
        State.begin(folder,"previous.json",2026111602)
        failed=State.recover(folder)
        expect(failed.failed_builds.has(2026111602) and failed.failed_builds.has(2026111603),"if A also fails both failures survive, rather than repeatedly retrying A")
        expect(not FileAccess.file_exists(folder.path_join("previous.json")),"failed previous pointer is isolated so built-in content can start")
        State.write_json(folder.path_join("active.json"),{"tag":"C"})
        State.begin(folder,"previous.json",2026111602);State.recover(folder)
        expect(FileAccess.file_exists(folder.path_join("active.json")),"recovering a previous-package attempt never removes a different active package")
        var world:=WorldStub.new()
        expect(not State.ready_for_play(world),"a valid scene without completed ready does not count as healthy")
        world.game_ready=true
        expect(not State.ready_for_play(world),"the ready flag alone does not replace required HUD and hero initialization")
        world.hud=Node.new();world.hero=Node.new()
        expect(State.ready_for_play(world),"fully initialized game can confirm startup")
        world.hud.free();world.hero.free();world.free()
        var supports_dispose:=false
        for method in State.get_script_method_list():
            if method.name=="dispose_world": supports_dispose=true
        expect(supports_dispose,"failed startup removes its game tree before showing recovery controls")
        if supports_dispose:
            var failed_world:=Node.new();var always_hud:=Node.new()
            always_hud.process_mode=Node.PROCESS_MODE_ALWAYS
            failed_world.add_child(always_hud);root.add_child(failed_world)
            State.dispose_world(failed_world)
            expect(not is_instance_valid(failed_world) and not is_instance_valid(always_hud),"even ALWAYS-processing HUD callbacks cannot survive failed-world disposal")
    print("RELEASE STARTUP RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
