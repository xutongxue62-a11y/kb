"""Pack whole-creature frame sheets. The PNG poses are finished source art.

Run with --sheet name=absolute-file.png once per approved sheet.
The packer finds complete sprite silhouettes and preserves a common ground
anchor and scale for the six poses of a creature.
"""
import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/encounters"

GROUPS = {
    "fernmask": (3, ["fernmask"]),
    "cinderback": (3, ["cinderback"]),
    "drumjaw": (3, ["drumjaw"]),
    "fernmask_dark": (3, ["fernmask_dark"]),
    "grass": (6, ["sidesnap", "stonecrest", "shieldback"]),
    "grove": (6, ["leafstalker", "sporeback", "bonecaller"]),
    "volcano": (6, ["embersnout", "ashhound", "basaltroller"]),
    "legacy1": (6, ["hunter", "charger", "spitter"]),
    "legacy2": (6, ["armored", "raptor", "thrower", "tank"]),
    "charger": (6, ["charger"]),
    "ranged": (6, ["reedspitter", "cindertusk"]),
    "boss_moves": (4, ["fernmask_sweep", "cinderback_stomp", "drumjaw_bite"]),
}


def sprites(path, columns, rows):
    original = Image.open(path)
    if original.mode != "RGBA":
        raise ValueError("sheet must have transparent alpha")
    pixels = np.array(original)
    alpha = pixels[:, :, 3]
    if np.mean(alpha < 12) < 0.22:
        raise ValueError("insufficient transparent separation between frames")
    height, width = alpha.shape
    count, labels, stats, centers = cv2.connectedComponentsWithStats((alpha >= 40).astype(np.uint8), connectivity=8)
    cells = {}
    minimum_area = width * height / (rows * columns) * 0.055
    for i in range(1, count):
        x, y, w, h, area = stats[i]
        if area < minimum_area:
            continue
        center_x, center_y = centers[i]
        col = min(columns - 1, int(center_x * columns / width))
        row = min(rows - 1, int(center_y * rows / height))
        if (row, col) in cells:
            raise ValueError(f"multiple main silhouettes in row {row + 1}, column {col + 1}")
        if w > width / columns * 1.12 or h > height / rows * 1.12:
            raise ValueError("a frame bridges its cell or contains two creatures")
        bounds = (max(0, x - 3), max(0, y - 3), min(width, x + w + 3), min(height, y + h + 3))
        x0, y0, x1, y1 = bounds
        selection = (labels[y0:y1, x0:x1] == i).astype(np.uint8)
        # Keep the selected complete sprite and its own anti-aliased fringe.
        neighborhood = cv2.dilate(selection, np.ones((5, 5), np.uint8))
        crop = pixels[y0:y1, x0:x1].copy()
        crop[:, :, 3] *= neighborhood
        tile = Image.fromarray(crop)
        if int(np.max(crop[:, :, 3])) < 220:
            raise ValueError("frame body is not sufficiently opaque")
        core = cv2.distanceTransform(selection, cv2.DIST_L2, 5)**2
        weight = core.sum()
        torso_x = float(np.dot(np.arange(core.shape[1]), core.sum(axis=0)) / weight)
        ground_y = float(y + h - y0)
        cells[(row, col)] = (tile, torso_x, ground_y)
    if len(cells) != rows * columns:
        absent = [(r + 1, c + 1) for r in range(rows) for c in range(columns) if (r, c) not in cells]
        raise ValueError(f"{len(cells)} frames detected; missing positions {absent}")
    return [[cells[(r,c)] for c in range(columns)] for r in range(rows)]


def materialize(group, path):
    columns, creatures = GROUPS[group]
    rows = 2 if columns == 3 else len(creatures)
    sheet = sprites(path, columns, rows)
    if columns == 3:
        sheet = [sheet[0] + sheet[1]]
    for key, frames in zip(creatures, sheet):
        average_size = float(np.median([max(image.size) for image, _, _ in frames[:4]]))
        median_height = float(np.median([ground for _, _, ground in frames[:4]]))
        boss = group == "boss_moves" or columns == 3
        factor = min(1.0, (215 if boss else 154) / average_size)
        size = round(average_size * factor, 2)
        entries = []
        for tile, x, ground in frames:
            if factor < 1.0:
                tile = tile.resize((max(1, round(tile.width * factor)), max(1, round(tile.height * factor))), Image.Resampling.LANCZOS)
            anchor = [round(-x * factor, 2), round((median_height * 0.5 - ground) * factor, 2)]
            entries.append((tile, anchor))
        yield key, size, entries


def pack(name, sheets, keep_existing):
    creatures = {}
    if keep_existing:
        original = Image.open(OUT / f"{name}.png").convert("RGBA")
        source = json.loads((OUT / f"{name}.json").read_text(encoding="utf-8"))
        for key, record in source.items():
            frames = [(original.crop((x,y,x+w,y+h)), [ox,oy]) for x,y,w,h,ox,oy in record["frames"]]
            creatures[key] = (record["extent"], frames)
    for group, path in sheets.items():
        for key, size, frames in materialize(group, path):
            creatures[key] = (size, frames)
    records = {key: {"extent":size, "frames":[None] * len(frames)}
               for key, (size, frames) in creatures.items()}
    to_pack = [(key, i, image, offset) for key, (_, frames) in creatures.items()
               for i, (image, offset) in enumerate(frames)]
    width = 1536
    x, y, shelf = 3, 3, 0
    placed = []
    for key, frame, image, offset in sorted(to_pack, key=lambda item: -item[2].height):
        if x + image.width + 3 > width:
            x, y, shelf = 3, y + shelf + 6, 0
        records[key]["frames"][frame] = [x, y, image.width, image.height, *offset]
        placed.append((image, (x,y)))
        x += image.width + 6
        shelf = max(shelf, image.height)
    atlas = Image.new("RGBA", (width, y + shelf + 3))
    for image, pos in placed:
        atlas.paste(image, pos)
    atlas.save(OUT / f"{name}.png", optimize=True)
    (OUT / f"{name}.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")
    print(f"Packed {len(to_pack)} complete frames for {len(records)} creatures")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sheet", action="append", required=True)
    parser.add_argument("--name", default="creature_frames")
    parser.add_argument("--keep-existing", action="store_true", help="Retain all poses not supplied by the replacement sheets")
    parser.add_argument("--check", action="store_true", help="Validate sheet cells, without writing game files")
    args = parser.parse_args()
    sheets = dict(item.split("=", 1) for item in args.sheet)
    for group, path in sheets.items():
        for key, size, frames in materialize(group, path):
            print(group, key, len(frames), round(size, 2))
    if not args.check:
        pack(args.name, sheets, args.keep_existing)


if __name__ == "__main__":
    main()
