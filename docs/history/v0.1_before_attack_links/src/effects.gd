extends Node2D

var particles: Array = []

func burst(at: Vector2, color: Color, size: float = 16.0, kind: String = "hit") -> void:
    particles.append({"at": at, "color": color, "size": size, "kind": kind, "age": 0.0, "life": 0.36 if kind == "ring" else 0.22})
    if particles.size() > 120:
        particles.pop_front()

func beam(start: Vector2, end: Vector2, color: Color) -> void:
    particles.append({"at": start, "end": end, "color": color, "size": 2.0, "kind": "beam", "age": 0.0, "life": 0.16})

func advance(delta: float) -> void:
    for particle in particles:
        particle["age"] += delta
    particles = particles.filter(func(item): return item["age"] < item["life"])
    queue_redraw()

func _draw() -> void:
    for particle in particles:
        var progress: float = particle["age"] / particle["life"]
        var color: Color = particle["color"]
        color.a *= 1.0 - progress
        var point: Vector2 = particle["at"]
        var size: float = particle["size"]
        match particle["kind"]:
            "ring":
                draw_arc(point, size * (0.3 + progress * 0.7), 0.0, TAU, 40, color, 3.0 * (1.0 - progress) + 0.5, true)
            "beam":
                draw_line(point, particle["end"], color, 2.5 * (1.0 - progress), true)
            _:
                for index in range(4):
                    var direction: Vector2 = Vector2.from_angle(float(index) * PI / 2.0 + 0.35)
                    draw_line(point + direction * size * progress, point + direction * size * (0.4 + progress), color, 2.6, true)
