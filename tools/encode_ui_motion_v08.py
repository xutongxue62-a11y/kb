"""Encode a new native Godot AVI with its actual recorded mix; preserve all sources."""
from pathlib import Path
from fractions import Fraction
import sys, json, math
import av
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
stem = sys.argv[1]
source = ROOT / "previews" / (stem + ".avi")
target = ROOT / "previews" / (stem + ".mp4")
if target.exists():
    raise RuntimeError("Refusing to replace an existing preview")
count = samples = values_count = 0
square_sum = peak = 0.0
with av.open(str(source)) as incoming, av.open(str(target), "w", options={"movflags":"+faststart"}) as outgoing:
    source_video = incoming.streams.video[0]
    video = outgoing.add_stream("libx264", rate=Fraction(30, 1))
    video.width, video.height = source_video.width, source_video.height
    video.pix_fmt = "yuv420p"
    video.options = {"crf":"20", "preset":"fast"}
    video.codec_context.thread_count = 2
    if not incoming.streams.audio:
        raise RuntimeError("Native capture has no audio")
    audio = outgoing.add_stream("aac", rate=48000)
    audio.layout = "stereo"
    audio.bit_rate = 128000
    resampler = av.AudioResampler(format="fltp", layout="stereo", rate=48000)
    for frame in incoming.decode():
        if isinstance(frame, av.VideoFrame):
            frame.pts, frame.time_base = count, Fraction(1, 30)
            frame.pict_type = av.video.frame.PictureType.NONE
            for packet in video.encode(frame): outgoing.mux(packet)
            count += 1
        elif isinstance(frame, av.AudioFrame):
            for converted in resampler.resample(frame):
                array = converted.to_ndarray().astype(np.float64)
                peak = max(peak, float(np.abs(array).max()))
                square_sum += float(np.sum(array * array))
                values_count += array.size
                converted.pts, converted.time_base = samples, Fraction(1, 48000)
                samples += converted.samples
                for packet in audio.encode(converted): outgoing.mux(packet)
    for converted in resampler.resample(None):
        converted.pts, converted.time_base = samples, Fraction(1, 48000)
        samples += converted.samples
        for packet in audio.encode(converted): outgoing.mux(packet)
    for packet in video.encode(): outgoing.mux(packet)
    for packet in audio.encode(): outgoing.mux(packet)
if peak < 0.0001:
    raise RuntimeError("Recorded mix is unexpectedly silent")
result = {"file":target.name,"video_frames":count,"fps":30,"size":[video.width,video.height],"seconds":count/30,"audio_samples":samples,"input_mix_peak":peak,"input_mix_rms":math.sqrt(square_sum/max(1,values_count)),"bytes":target.stat().st_size,"listening_verified":False}
(ROOT/"previews"/(stem+"_metadata.json")).write_text(json.dumps(result,indent=2),encoding="utf-8")
print(json.dumps(result))
