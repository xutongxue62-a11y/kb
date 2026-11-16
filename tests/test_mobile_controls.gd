extends SceneTree
var checks:=0
var failures:=0
class WorldStub extends Node:
    var touch_input:=Vector2.ZERO
    var dodges:=0
    var direction:=Vector2.ZERO
    func request_dodge(value: Vector2) -> bool:
        dodges+=1;direction=value;return true
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var path: String="res://src/mobile_controls.gd"
    expect(FileAccess.file_exists(path),"Android release provides touch movement and dodge controls")
    if FileAccess.file_exists(path):
        var controls=load(path).new()
        var stub:=WorldStub.new();root.add_child(stub)
        controls.world=stub;root.add_child(controls);controls.set_process(false)
        controls.set_active(true)
        expect(controls.feed_touch(3,true,controls.stick_center),"one finger captures the movement pad")
        controls.feed_drag(3,controls.stick_center+Vector2(70,0))
        expect(stub.touch_input.x>0.99 and absf(stub.touch_input.y)<0.01,"dragging the stick moves right")
        expect(controls.feed_touch(8,true,controls.dodge_center) and stub.dodges==1,"a second finger triggers dodge")
        expect(stub.direction.x>0.99 and stub.touch_input.x>0.99,"dodge does not steal movement finger")
        controls.feed_touch(8,false,controls.dodge_center)
        expect(stub.touch_input.x>0.99,"releasing action finger keeps movement")
        controls.feed_drag(99,Vector2.ZERO)
        expect(stub.touch_input.x>0.99,"unowned fingers cannot move the pad")
        controls.feed_drag(3,controls.stick_center+Vector2(200,200))
        expect(stub.touch_input.length()<=1.001,"touch movement is clamped to normal speed")
        controls.feed_touch(3,false,Vector2.ZERO)
        expect(stub.touch_input==Vector2.ZERO,"lifting the movement finger stops the player")
        controls.feed_touch(1,true,controls.stick_center)
        controls.feed_drag(1,controls.stick_center-Vector2(70,0))
        controls.set_active(false)
        expect(stub.touch_input==Vector2.ZERO and controls.stick_finger==-1,"pause/dialog clears held movement")
        expect(not controls.feed_touch(1,true,controls.stick_center),"menus receive touches while game controls are inactive")
        controls.set_active(true);controls.feed_touch(1,true,controls.stick_center)
        controls.feed_drag(1,controls.stick_center+Vector2(70,0));controls.reset_input()
        expect(stub.touch_input==Vector2.ZERO,"focus loss/reset cannot leave a stuck movement direction")
        controls.queue_free();stub.queue_free();await process_frame
    print("MOBILE CONTROLS RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
