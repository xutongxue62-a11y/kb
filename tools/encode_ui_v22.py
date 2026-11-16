"""Encode the native capture at its actual frame rate, retaining recorded audio."""
from pathlib import Path
from fractions import Fraction
import json
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root.parents[1]/".audio-tools"))
import av

stem = "ui_v22_final3"
source = root/"previews"/(stem+".avi")
target = source.with_suffix(".mp4")
assert not target.exists(), "Keep an existing encoded preview"
video_count = audio_samples = 0
with av.open(str(source)) as incoming, av.open(str(target),"w",options={"movflags":"+faststart"}) as outgoing:
    rate = Fraction(incoming.streams.video[0].average_rate)
    video = outgoing.add_stream("libx264",rate=rate)
    video.width = incoming.streams.video[0].width
    video.height = incoming.streams.video[0].height
    video.pix_fmt = "yuv420p"
    video.options = {"crf":"20","preset":"veryfast"}
    video.codec_context.thread_count = 2
    audio = outgoing.add_stream("aac",rate=48000)
    audio.layout = "stereo"
    audio.bit_rate = 128000
    resampler = av.AudioResampler(format="fltp",layout="stereo",rate=48000)
    for frame in incoming.decode():
        if isinstance(frame,av.VideoFrame):
            frame.pts = video_count
            frame.time_base = 1/rate
            frame.pict_type = av.video.frame.PictureType.NONE
            for packet in video.encode(frame): outgoing.mux(packet)
            video_count += 1
        elif isinstance(frame,av.AudioFrame):
            for converted in resampler.resample(frame):
                converted.pts = audio_samples
                converted.time_base = Fraction(1,48000)
                audio_samples += converted.samples
                for packet in audio.encode(converted): outgoing.mux(packet)
    for converted in resampler.resample(None):
        converted.pts = audio_samples
        converted.time_base = Fraction(1,48000)
        audio_samples += converted.samples
        for packet in audio.encode(converted): outgoing.mux(packet)
    for packet in video.encode(): outgoing.mux(packet)
    for packet in audio.encode(): outgoing.mux(packet)

with av.open(str(target)) as final:
    metadata = {"file":str(target),"frames":video_count,"fps":str(final.streams.video[0].average_rate),"dimensions":[video.width,video.height],"seconds":final.duration/av.time_base,"audio_codec":final.streams.audio[0].codec_context.name,"audio_seconds":audio_samples/48000,"bytes":target.stat().st_size,"manual_listening_verified":False}
assert abs(float(video_count/rate)-audio_samples/48000)<0.04
with av.open(str(target)) as final:
    decoded = sum(1 for _ in final.decode(video=0))
assert decoded == video_count
target.with_name(stem+"_metadata.json").write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(metadata,ensure_ascii=True))
