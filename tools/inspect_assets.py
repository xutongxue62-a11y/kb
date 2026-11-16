"""Read-only raster analysis; writes atlas metadata, never changes image pixels."""
from pathlib import Path
from collections import deque
from PIL import Image
import json

ROOT = Path(__file__).resolve().parents[1]

def rectangle(points):
    xs, ys = zip(*points)
    left, top, right, bottom = min(xs), min(ys), max(xs), max(ys)
    return [left - 2, top - 2, right - left + 5, bottom - top + 5]

def components(image):
    alpha = image.getchannel("A").tobytes()
    width, height = image.size
    visited = bytearray(width * height)
    found = []
    for origin, opacity in enumerate(alpha):
        if opacity < 180 or visited[origin]:
            continue
        queue = [origin]
        visited[origin] = 1
        count = 0
        min_x = max_x = origin % width
        min_y = max_y = origin // width
        while queue:
            index = queue.pop()
            x, y = index % width, index // width
            count += 1
            min_x, max_x = min(min_x, x), max(max_x, x)
            min_y, max_y = min(min_y, y), max(max_y, y)
            neighbours = []
            if x > 0: neighbours.append(index - 1)
            if x + 1 < width: neighbours.append(index + 1)
            if y > 0: neighbours.append(index - width)
            if y + 1 < height: neighbours.append(index + width)
            for next_index in neighbours:
                if not visited[next_index] and alpha[next_index] >= 180:
                    visited[next_index] = 1
                    queue.append(next_index)
        if count > 300:
            found.append({"rect": [min_x - 2, min_y - 2, max_x - min_x + 5, max_y - min_y + 5], "pixels": count})
    return sorted(found, key=lambda item: item["pixels"], reverse=True)

def center(rect):
    return (rect[0] + rect[2] / 2, rect[1] + rect[3] / 2)

def grid_bounds(image, columns, rows, names):
    width, height = image.size
    alpha = image.getchannel("A")
    pixels = alpha.load()
    result = {}
    for index, name in enumerate(names):
        x0, y0 = index % columns * width // columns, index // columns * height // rows
        x1, y1 = (index % columns + 1) * width // columns, (index // columns + 1) * height // rows
        points = [(x, y) for y in range(y0, y1) for x in range(x0, x1) if pixels[x, y] >= 205]
        if not points:
            raise RuntimeError("Atlas cell has no opaque shape: " + name)
        result[name] = rectangle(points)
    return result

hero = Image.open(ROOT / "assets/hero.png")
dinos = Image.open(ROOT / "assets/dinosaurs.png")
weapons = Image.open(ROOT / "assets/weapons.png")
for name, image in [("hero", hero), ("dinosaurs", dinos), ("weapons", weapons)]:
    if image.mode != "RGBA" or image.getchannel("A").getextrema()[0] != 0:
        raise RuntimeError(name + " lacks genuine alpha transparency")
parts = components(hero)
if len(parts) != 5:
    raise RuntimeError("Expected separate body plus four limbs, found " + str(len(parts)))
body = parts[0]["rect"]
body_center = center(body)
hands = sorted([p["rect"] for p in parts[1:] if center(p["rect"])[1] < body[1] + body[3] * 0.85], key=lambda r: center(r)[0])
feet = sorted([p["rect"] for p in parts[1:] if center(p["rect"])[1] >= body[1] + body[3] * 0.85], key=lambda r: center(r)[0])
if len(hands) != 2 or len(feet) != 2:
    raise RuntimeError("Could not identify two hands and two feet")
dino_parts = components(dinos)
if len(dino_parts) != 4:
    raise RuntimeError("Expected four isolated whole dinosaurs")
top_dinos = sorted([p["rect"] for p in dino_parts if center(p["rect"])[1] < dinos.height / 2], key=lambda r: center(r)[0])
bottom_dinos = sorted([p["rect"] for p in dino_parts if center(p["rect"])[1] >= dinos.height / 2], key=lambda r: center(r)[0])
regions = {
    "hero": dict(zip(["body", "left_hand", "right_hand", "left_foot", "right_foot"], [body] + hands + feet)),
    "dinosaurs": dict(zip(["hunter", "charger", "spitter", "tank"], top_dinos + bottom_dinos)),
    "weapons": grid_bounds(weapons, 3, 2, ["club", "axe", "blade", "sling", "powder", "staff"])
}
(ROOT / "assets/regions.json").write_text(json.dumps(regions, indent=2), encoding="utf-8")
print(json.dumps({"hero_parts": len(parts), "regions": regions, "pixels_unchanged": True}, ensure_ascii=False))
