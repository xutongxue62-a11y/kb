"""Encode the engine-recorded AVI files and extract unmodified decoded QA frames."""
from pathlib import Path
from fractions import Fraction
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parents[1] / ".audio-tools"))
import av

records = []
for name in ["动作预览", "六武器战斗"]:
    source = ROOT / "previews" / (name + ".avi")
    target = ROOT / "previews" / (name + ".mp4")
    if target.exists():
        raise RuntimeError("Refusing to overwrite " + str(target))
    count = 0
    with av.open(str(source)) as incoming, av.open(str(target), "w", options={"movflags": "+faststart"}) as outgoing:
        video = incoming.streams.video[0]
        encoded = outgoing.add_stream("libx264", rate=Fraction(30, 1))
        encoded.width, encoded.height = video.width, video.height
        encoded.pix_fmt = "yuv420p"
        encoded.options = {"crf": "20", "preset": "fast"}
        encoded.codec_context.thread_count = 2
        for frame in incoming.decode(video=0):
            frame.pts = count
            frame.time_base = Fraction(1, 30)
            for packet in encoded.encode(frame):
                outgoing.mux(packet)
            count += 1
        for packet in encoded.encode():
            outgoing.mux(packet)
    with av.open(str(target)) as result:
        stream = result.streams.video[0]
        records.append({"file": str(target), "frames": count, "fps": str(stream.average_rate), "width": stream.width, "height": stream.height, "seconds": float(result.duration / av.time_base), "bytes": target.stat().st_size})
checks = ROOT / "previews" / "checks"
checks.mkdir(exist_ok=True)
for name, frames in [("动作预览", {30: "idle.png", 66: "walk.png", 330: "attack.png"}), ("六武器战斗", {255: "battle.png"})]:
    with av.open(str(ROOT / "previews" / (name + ".mp4"))) as incoming:
        for index, frame in enumerate(incoming.decode(video=0)):
            if index in frames:
                frame.to_image().save(checks / frames[index])
print(json.dumps(records, ensure_ascii=False, indent=2))
