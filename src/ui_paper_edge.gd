extends RefCounted
## Deterministic inward chips: stable hit shapes, no animated/random edge flicker.
static func fray(base: PackedVector2Array,depth: float,seed: int=11) -> PackedVector2Array:
    var result:=PackedVector2Array()
    for edge in range(base.size()):
        var start: Vector2=base[edge]
        var end: Vector2=base[(edge+1)%base.size()]
        var tangent: Vector2=(end-start).normalized()
        var inward:=Vector2(-tangent.y,tangent.x)
        var steps: int=maxi(1,floori(start.distance_to(end)/13.0))
        result.append(start)
        for i in range(1,steps):
            var phase: float=float(seed*19+edge*71+i*37)
            var t: float=(i+sin(phase)*0.17)/float(steps)
            var wear: float=(0.15+0.55*absf(sin(phase*0.71))+0.3*absf(cos(phase*1.13)))*depth
            if steps>6 and i==2+posmod(seed+edge*3,steps-4): wear*=1.85
            wear*=minf(1.0,sin(t*PI)*2.5)
            result.append(start.lerp(end,t)+inward*wear)
    return result

static func fibres(canvas: CanvasItem,points: PackedVector2Array,seed: int=11,amount: float=1.0) -> void:
    if points.size()<4: return
    for i in range(points.size()):
        if posmod(i+seed,9)!=0: continue
        var point: Vector2=points[i]
        var tangent: Vector2=(points[(i+1)%points.size()]-points[(i-1+points.size())%points.size()]).normalized()
        var inward:=Vector2(-tangent.y,tangent.x)
        var length: float=(2.0+absf(sin(i*3.7))*3.0)*amount
        canvas.draw_line(point+inward*0.5,point+inward*length+tangent*1.5,Color(0.40,0.27,0.15,0.22),0.8,true)
        canvas.draw_line(point+tangent*1.2,point+inward*length*0.65+tangent*2.4,Color(1.0,0.96,0.82,0.48),0.7,true)
