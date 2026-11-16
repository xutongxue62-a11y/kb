"""Original Campfire Trail: deterministic modal instruments; no samples or downloads.
8 bars, 4/4, 72 BPM, D suspended pentatonic, 26 2/3 seconds.
Wrap tails and echoes into the beginning to render a genuinely periodic loop.
"""
from pathlib import Path
import hashlib
import json
import math
import wave
import numpy as np

RATE = 44100
BPM = 72
BEAT = 60 / BPM
FRAMES = round(32 * BEAT * RATE)
OUT = Path(__file__).resolve().parents[1] / "assets/music/v10"
EVENTS = []
mix = np.zeros((FRAMES, 2), dtype=np.float64)


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def add(signal, beat, amp, pan=0, echo=False):
    # Equal power stereo and wrapped indexes preserve all boundary tails.
    stereo = signal[:, None] * np.array([math.cos((pan + 1) * math.pi / 4),
                                         math.sin((pan + 1) * math.pi / 4)]) * amp
    start = round(beat * BEAT * RATE)
    np.add.at(mix, (np.arange(len(signal)) + start) % FRAMES, stereo)
    if echo:
        np.add.at(mix, (np.arange(len(signal)) + start + round(.75 * BEAT * RATE)) % FRAMES,
                  stereo[:, ::-1] * .15)


def voice(kind, midi, beats, at, amp, pan=0):
    duration = beats * BEAT
    t = np.arange(round((duration + .35) * RATE)) / RATE
    f = hz(midi)
    attack = 1 - np.exp(-t / (.035 if kind == "flute" else .008))
    if kind == "flute":
        phase = 2 * np.pi * f * t + .022 * np.sin(2 * np.pi * 4.7 * t)
        sound = np.sin(phase) + .14 * np.sin(2 * phase) + .045 * np.sin(3 * phase)
        release = np.exp(-np.maximum(t - duration + .10, 0) / .09)
        env = attack * release * (.85 + .15 * np.sin(np.minimum(t / duration, 1) * np.pi))
    elif kind == "wood":
        sound = np.sin(2 * np.pi * f * t) + .24 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 8)
        sound += .10 * np.sin(2 * np.pi * f * 3 * t) * np.exp(-t * 12)
        env = attack * np.exp(-t / .28) * np.exp(-np.maximum(t-duration, 0) / .08)
    else:
        sound = np.sin(2 * np.pi * f * t) + .15 * np.sin(2 * np.pi * f * 2 * t)
        env = attack * np.exp(-t / .6) * np.exp(-np.maximum(t-duration, 0) / .12)
    # Every note reaches zero before its array ends, preventing truncation clicks.
    env *= np.clip((t[-1] - t) / .015, 0, 1)
    add(sound * env, at, amp, pan, echo=kind != "bass")
    EVENTS.append(dict(instrument=kind, midi=midi, beat=at, duration_beats=beats, amplitude=amp))


def hand_drum(at, high=False, velocity=1):
    t = np.arange(round(.28 * RATE)) / RATE
    # Analytic membrane modes only: no white noise or sampled percussion.
    f = 165 if high else 90
    phase = 2 * np.pi * (f * t + 13 * .018 * (1 - np.exp(-t / .018)))
    signal = np.sin(phase) * np.exp(-t / .073)
    signal += .23 * np.sin(2 * np.pi * f * 1.59 * t) * np.exp(-t / .027)
    signal *= (1 - np.exp(-t / .002)) * np.clip((t[-1] - t) / .012, 0, 1)
    add(signal, at, .105 * velocity, .2 if high else -.16)
    EVENTS.append(dict(instrument="hand_drum_high" if high else "hand_drum_low", beat=at))


def write_wav(name, data):
    pcm = np.round(np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(str(OUT / name), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    return pcm.astype(float) / 32768


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # D6sus4 - G6 - Em7 - Asus, two phrases with a small responding variation.
    chords = [(50, [62, 67, 69, 71]), (43, [59, 62, 67, 69]),
              (52, [59, 62, 64, 67]), (45, [57, 62, 64, 69])]
    for bar in range(8):
        bass, chord = chords[bar % 4]
        voice("bass", bass, 2.6, bar*4, .19, -.04)
        voice("bass", bass+12, .7, bar*4+2.5, .065, .04)
        for step, index in [(0, 0), (.75, 2), (1.5, 1), (2.5, 3), (3.25, 2)]:
            voice("wood", chord[index], .9, bar*4+step, .115 if step == 0 else .083, -.28 if index % 2 else .28)
        for step, high, velocity in [(0, False, 1), (1.5, True, .55), (2, False, .72), (3, True, .62)]:
            hand_drum(bar*4+step, high, velocity)
        if bar in [3, 7]:
            hand_drum(bar*4+3.5, True, .38)
    # Four complete call/response figures, rests leave air between phrases.
    melody = [(0.5, 74, .8), (1.5, 76, .6), (2.5, 79, 1.1),
              (4.5, 81, 1.1), (6, 79, .8), (7, 76, .55),
              (8.5, 74, .8), (10, 71, 1.2), (12.5, 69, .9), (14, 74, 1.25),
              (16.5, 74, .7), (17.5, 76, .6), (18.5, 79, 1),
              (20, 81, .8), (21.5, 83, .7), (22.5, 81, .75),
              (24.5, 79, .8), (26, 76, 1), (28, 74, 1.5)]
    for at, midi, length in melody:
        voice("flute", midi, length, at, .112, -.08)
    # Tiny correction removes measured global DC; no limiting or clipping needed.
    mix[:] -= mix.mean(axis=0)
    mix[:] *= .68 / np.max(np.abs(mix))
    pcm = write_wav("campfire_trail.wav", mix)
    preview = write_wav("campfire_trail_title_gain_preview.wav", mix * 10 ** (-10/20))
    peak = float(np.max(np.abs(pcm)))
    rms = float(np.sqrt(np.mean(pcm ** 2)))
    seam = float(np.max(np.abs(pcm[0] - pcm[-1])))
    max_step = float(np.max(np.abs(np.diff(pcm, axis=0))))
    dc = float(np.max(np.abs(pcm.mean(axis=0))))
    assert 24 <= FRAMES/RATE <= 32 and peak < .7 and dc < 1e-5
    assert seam < .004 and seam < max_step and not np.any(np.abs(pcm) >= .999)
    manifest = dict(title="Campfire Trail", original=True, samples_or_downloads=False,
                    tempo_bpm=BPM, meter="4/4", bars=8, scale="D E G A B pentatonic",
                    progression="D6sus4 G6 Em7 Asus (two 4-bar phrases)",
                    synthesis="analytic wood pluck, harmonic flute, round bass, membrane hand percussion",
                    duration_seconds=FRAMES/RATE, sample_rate=RATE, channels=2, bits=16,
                    loop_frames=FRAMES, tail_method="circular accumulation including stereo echoes",
                    gain_db=dict(title=-10, battle=-12, volcano=-11, pause=-18),
                    qc=dict(peak=peak, rms=rms, peak_dbfs=20*math.log10(peak),
                            rms_dbfs=20*math.log10(rms), max_dc=dc,
                            boundary_step=seam, maximum_internal_step=max_step,
                            clipped_samples=0, preview_title_peak_dbfs=20*math.log10(float(np.max(np.abs(preview)))),
                            playback_listening_verified=False),
                    sha256=hashlib.sha256((OUT / "campfire_trail.wav").read_bytes()).hexdigest(),
                    arrangement=EVENTS)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({k:v for k,v in manifest.items() if k != "arrangement"}, indent=2))


if __name__ == "__main__":
    main()
