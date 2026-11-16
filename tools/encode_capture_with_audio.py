"""Encode actual Godot Movie Maker video+audio, preserving the recorded timeline."""
from pathlib import Path
from fractions import Fraction
import json, sys, math
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parents[1] / ".audio-tools"))
import av
import numpy as np

stem = sys.argv[1] if len(sys.argv) > 1 else "二联动修订_有声_v0.2"
source, target = ROOT/"previews"/(stem+".avi"), ROOT/"previews"/(stem+".mp4")
if target.exists():
    raise RuntimeError("Refusing to overwrite " + str(target))
video_count = audio_samples = sample_values = 0
square_sum = peak = 0.0
with av.open(str(source)) as incoming, av.open(str(target), "w", options={"movflags":"+faststart"}) as outgoing:
    original_video = incoming.streams.video[0]
    video = outgoing.add_stream("libx264", rate=Fraction(30,1))
    video.width, video.height = original_video.width, original_video.height
    video.pix_fmt = "yuv420p"
    video.options = {"crf":"20", "preset":"fast"}
    video.codec_context.thread_count = 2
    if not incoming.streams.audio:
        raise RuntimeError("Engine capture has no audio track")
    audio = outgoing.add_stream("aac", rate=48000)
    audio.layout = "stereo"
    audio.bit_rate = 128000
    resampler = av.AudioResampler(format="fltp",layout="stereo",rate=48000)
    for frame in incoming.decode():
        if isinstance(frame, av.VideoFrame):
            frame.pts = video_count
            frame.time_base = Fraction(1,30)
            frame.pict_type = av.video.frame.PictureType.NONE
            for packet in video.encode(frame): outgoing.mux(packet)
            video_count += 1
        elif isinstance(frame, av.AudioFrame):
            for converted in resampler.resample(frame):
                values = converted.to_ndarray().astype(np.float64)
                peak = max(peak, float(np.max(np.abs(values))))
                square_sum += float(np.sum(values*values)); sample_values += values.size
                converted.pts = audio_samples
                converted.time_base = Fraction(1,48000)
                audio_samples += converted.samples
                for packet in audio.encode(converted): outgoing.mux(packet)
    for converted in resampler.resample(None):
        converted.pts=audio_samples; converted.time_base=Fraction(1,48000)
        audio_samples += converted.samples
        for packet in audio.encode(converted): outgoing.mux(packet)
    for packet in video.encode(): outgoing.mux(packet)
    for packet in audio.encode(): outgoing.mux(packet)
if peak < 0.0001:
    raise RuntimeError("Recorded audio is silent")
checks=ROOT/"previews"/"checks_v02"
checks.mkdir(exist_ok=True)
targets={90:"no_link.png",300:"rune_shell.png",525:"chain_attack.png",810:"link_disabled.png"}
with av.open(str(target)) as final:
    for index,frame in enumerate(final.decode(video=0)):
        if index in targets: frame.to_image().save(checks/targets[index])
with av.open(str(target)) as final:
    result={"file":target.name,"video_frames":video_count,"fps":str(final.streams.video[0].average_rate),"size":[video.width,video.height],"seconds":float(final.duration/av.time_base),"audio_codec":final.streams.audio[0].codec_context.name,"audio_samples":audio_samples,"input_audio_peak":peak,"input_audio_rms":math.sqrt(square_sum/max(1,sample_values)),"bytes":target.stat().st_size}
(ROOT/"previews"/(stem+"_metadata.json")).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(result,ensure_ascii=False,indent=2))
