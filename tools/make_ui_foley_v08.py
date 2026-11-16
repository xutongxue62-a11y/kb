"""Original, quiet UI paper/wood foley. Python standard library only.

No external recordings, oscillators, frequency sweeps, peak normalization,
compression, or distortion. Each cue uses fixed-gain, band-limited noise
gestures; amplitudes intentionally differ. Existing sfx files are never read
or modified. Output is restricted to assets/sfx/ui_v08.

Run: python tools/make_ui_foley_v08.py
QC:  python tools/make_ui_foley_v08.py --check

QC is an engineering check, not a listening assessment. This model session
cannot receive audio input, so listening_verified must remain false.
"""

from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import random
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sfx" / "ui_v08"
RATE = 44100

# Time, fixed playback gain, cooldown. Keep the semantic contract in ui_audio.gd.
SPECS = {
    "button_press": (0.072, -3.0, 90),
    "paper_popup": (0.220, -2.0, 170),
    "page_turn": (0.380, -3.0, 240),
    "scroll_unroll": (0.580, -4.0, 400),
    "paper_close": (0.164, -2.0, 140),
    "parchment_burn": (0.890, -5.0, 800),
    "choice_confirm": (0.168, -1.0, 150),
}

DESIGN = {
    "button_press": "One small, muted wooden contact; nearly no trailing fiber.",
    "paper_popup": "Two small paper folds opening, then a soft settling touch.",
    "page_turn": "Paper picked up, flexed across the middle, and lightly laid down.",
    "scroll_unroll": "Four uneven low paper rolls, slowing into a faint final contact.",
    "paper_close": "A short padded paper flap with a warm, non-resonant contact.",
    "parchment_burn": "A low fibrous crumble with sparse tiny ember textures and a long fade.",
    "choice_confirm": "A deliberate two-part wooden/paper seal press, without a chime.",
}


def smoothstep(x: float) -> float:
    x = min(1.0, max(0.0, x))
    return x * x * (3.0 - 2.0 * x)


def band_noise(count: int, rng: random.Random, highpass_hz: float, lowpass_hz: float) -> list[float]:
    """Two low-pass stages after a gentle high-pass, with no resonant poles."""
    high_alpha = 1.0 - math.exp(-2.0 * math.pi * highpass_hz / RATE)
    low_alpha = 1.0 - math.exp(-2.0 * math.pi * lowpass_hz / RATE)
    slow = low1 = low2 = 0.0
    result = []
    for _ in range(count):
        white = rng.uniform(-1.0, 1.0)
        slow += high_alpha * (white - slow)
        low1 += low_alpha * ((white - slow) - low1)
        low2 += low_alpha * (low1 - low2)
        result.append(low2)
    return result


def gesture(
    output: list[float], noise: list[float], start: float, span: float,
    gain: float, attack: float = 0.3, release: float = 0.4, decay: float = 0.0,
) -> None:
    """Asymmetric, click-free contact/rustle envelope over fixed filtered noise."""
    first = max(0, int(start * RATE))
    last = min(len(output), int((start + span) * RATE))
    for i in range(first, last):
        x = (i / RATE - start) / span
        env = smoothstep(x / attack) * smoothstep((1.0 - x) / release)
        output[i] += noise[i] * gain * env * math.exp(-decay * x)


def soften_edges_and_dc(samples: list[float]) -> list[float]:
    """Remove only DC and taper endpoints; never raise or normalize the level."""
    count = len(samples)
    taper = []
    for i in range(count):
        t = i / RATE
        tail = (count - 1 - i) / RATE
        taper.append(smoothstep(t / 0.003) * smoothstep(tail / 0.012))
    samples = [value * weight for value, weight in zip(samples, taper)]
    correction = sum(samples) / sum(taper)
    return [value - correction * weight for value, weight in zip(samples, taper)]


def synthesize(key: str, duration: float, seed: int) -> list[float]:
    count = round(duration * RATE)
    rng = random.Random(seed)
    wood = band_noise(count, rng, 105.0, 880.0)
    body = band_noise(count, rng, 85.0, 460.0)
    fiber = band_noise(count, rng, 340.0, 2350.0)
    soft_fiber = band_noise(count, rng, 220.0, 1280.0)
    out = [0.0] * count
    if key == "button_press":
        gesture(out, wood, 0.003, 0.052, 0.83, 0.08, 0.65, 3.0)
        gesture(out, body, 0.004, 0.056, 0.47, 0.10, 0.65, 2.7)
        gesture(out, soft_fiber, 0.006, 0.023, 0.12, 0.14, 0.60, 2.6)
    elif key == "paper_popup":
        gesture(out, soft_fiber, 0.010, 0.105, 0.42, 0.36, 0.50)
        gesture(out, fiber, 0.052, 0.108, 0.26, 0.42, 0.50)
        gesture(out, soft_fiber, 0.115, 0.087, 0.34, 0.27, 0.70, 0.8)
        gesture(out, wood, 0.148, 0.056, 0.28, 0.10, 0.65, 2.0)
    elif key == "page_turn":
        gesture(out, soft_fiber, 0.012, 0.125, 0.29, 0.26, 0.65)
        gesture(out, fiber, 0.064, 0.212, 0.34, 0.52, 0.62)
        gesture(out, soft_fiber, 0.172, 0.175, 0.47, 0.35, 0.68)
        gesture(out, body, 0.290, 0.073, 0.31, 0.10, 0.65, 1.8)
    elif key == "scroll_unroll":
        gesture(out, body, 0.015, 0.520, 0.30, 0.20, 0.70)
        for start, span, gain in [(0.016, 0.143, 0.40), (0.112, 0.178, 0.54), (0.245, 0.171, 0.43), (0.382, 0.140, 0.29)]:
            gesture(out, soft_fiber, start, span, gain, 0.25, 0.64)
        gesture(out, fiber, 0.050, 0.155, 0.17, 0.36, 0.58)
        gesture(out, fiber, 0.240, 0.180, 0.13, 0.35, 0.70)
        gesture(out, wood, 0.494, 0.064, 0.24, 0.12, 0.68, 2.1)
    elif key == "paper_close":
        gesture(out, soft_fiber, 0.009, 0.107, 0.35, 0.26, 0.65)
        gesture(out, body, 0.040, 0.102, 0.52, 0.10, 0.72, 2.0)
        gesture(out, wood, 0.042, 0.089, 0.31, 0.09, 0.69, 2.8)
        gesture(out, fiber, 0.087, 0.060, 0.11, 0.25, 0.70, 1.0)
    elif key == "parchment_burn":
        gesture(out, soft_fiber, 0.020, 0.835, 0.18, 0.20, 0.65, 0.5)
        gesture(out, fiber, 0.070, 0.755, 0.13, 0.30, 0.64, 0.5)
        # Tiny dull grains, never sharp isolated impulses or a pitched fire hum.
        for start, span, gain in [(0.083, 0.045, 0.10), (0.174, 0.030, 0.16), (0.249, 0.052, 0.12), (0.341, 0.031, 0.19), (0.426, 0.046, 0.14), (0.548, 0.035, 0.11), (0.631, 0.044, 0.08), (0.746, 0.038, 0.05)]:
            gesture(out, fiber, start, span, gain, 0.18, 0.72, 1.8)
        gesture(out, body, 0.080, 0.600, 0.10, 0.30, 0.70)
    elif key == "choice_confirm":
        gesture(out, wood, 0.005, 0.065, 0.69, 0.08, 0.66, 2.7)
        gesture(out, body, 0.008, 0.068, 0.54, 0.11, 0.72, 2.3)
        gesture(out, wood, 0.072, 0.074, 0.42, 0.10, 0.72, 2.5)
        gesture(out, soft_fiber, 0.043, 0.111, 0.25, 0.28, 0.65, 0.7)
    else:
        raise ValueError(f"Unknown semantic cue: {key}")
    return soften_edges_and_dc(out)


def pcm16(samples: list[float]) -> bytes:
    # Deliberately fail rather than clipping a design mistake into a harsh sound.
    if any(abs(sample) >= 1.0 for sample in samples):
        raise ValueError("Signal outside PCM headroom; reduce the fixed source gains")
    pcm = array.array("h", (round(value * 32767.0) for value in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    return pcm.tobytes()


def write_wav(path: Path, samples: list[float]) -> None:
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm16(samples))


def read_wav(path: Path) -> list[float]:
    with wave.open(str(path), "rb") as src:
        if (src.getnchannels(), src.getsampwidth(), src.getframerate()) != (1, 2, RATE):
            raise ValueError(f"Unexpected WAV format: {path.name}")
        pcm = array.array("h", src.readframes(src.getnframes()))
    if sys.byteorder != "little":
        pcm.byteswap()
    return [value / 32767.0 for value in pcm]


def db(value: float) -> float:
    return round(20.0 * math.log10(max(value, 1e-12)), 2)


def measure(path: Path) -> dict:
    samples = read_wav(path)
    peak = max(map(abs, samples))
    rms = math.sqrt(sum(value * value for value in samples) / len(samples))
    return {
        "file": path.name,
        "duration_s": round(len(samples) / RATE, 6),
        "peak": round(peak, 7),
        "peak_dbfs": db(peak),
        "rms": round(rms, 7),
        "rms_dbfs": db(rms),
        "dc_mean": round(sum(samples) / len(samples), 9),
        "max_adjacent_step": round(max(abs(a - b) for a, b in zip(samples, samples[1:])), 7),
        "endpoint_samples": [samples[0], samples[-1]],
        "clipped_samples": sum(abs(value) >= 0.999 for value in samples),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def check() -> list[dict]:
    records = []
    for key, (duration, gain_db, _) in SPECS.items():
        path = OUT / f"{key}.wav"
        record = measure(path)
        assert abs(record["duration_s"] - duration) < 1.0 / RATE, record
        assert -55.0 < record["rms_dbfs"] < -25.0, record
        assert record["peak"] < 0.30, record
        assert abs(record["dc_mean"]) < 0.00001, record
        assert record["endpoint_samples"] == [0.0, 0.0], record
        assert record["max_adjacent_step"] < 0.10, record
        assert record["clipped_samples"] == 0, record
        record["playback_gain_db"] = gain_db
        record["playback_peak_dbfs"] = round(record["peak_dbfs"] + gain_db, 2)
        record["playback_rms_dbfs"] = round(record["rms_dbfs"] + gain_db, 2)
        records.append(record)
    assert len({r["sha256"] for r in records}) == len(SPECS), "Cues must be distinct"
    assert len({r["peak_dbfs"] for r in records}) > 3, "Do not normalize all source clips to a common peak"
    return records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Read and validate existing outputs without regenerating")
    args = parser.parse_args()
    if args.check:
        records = check()
        print(json.dumps({"technical_qc": "passed", "listening_verified": False, "cues": records}, indent=2))
        return
    OUT.mkdir(parents=True, exist_ok=True)
    samples_by_key = {}
    for index, (key, (duration, _, _)) in enumerate(SPECS.items()):
        samples = synthesize(key, duration, 80115 + 7919 * index)
        write_wav(OUT / f"{key}.wav", samples)
        samples_by_key[key] = samples
    records = check()
    # Preview uses the same gains as in-game playback, with no added normalization.
    preview = [0.0] * round(0.5 * RATE)
    order = []
    for key, (duration, gain_db, _) in SPECS.items():
        start = len(preview) / RATE
        order.append({"cue": key, "starts_at_s": round(start, 3), "ends_at_s": round(start + duration, 3), "gain_db": gain_db, "gesture": DESIGN[key]})
        gain = 10.0 ** (gain_db / 20.0)
        preview.extend(sample * gain for sample in samples_by_key[key])
        preview.extend([0.0] * round(0.65 * RATE))
    write_wav(OUT / "ui_v08_preview.wav", preview)
    report = {
        "source": "Original procedural foley; no recordings or third-party media",
        "format": "44100 Hz, mono, signed 16-bit PCM WAV",
        "level_policy": "Fixed layer gains; no peak/loudness normalization and no upward compression",
        "listening_verified": False,
        "verification_boundary": "Durations, samples, headroom, DC and endpoints were measured. This model environment cannot receive audio input; timbre and mix require human listening.",
        "preview": {"file": "ui_v08_preview.wav", "duration_s": round(len(preview) / RATE, 3), "applied_gains": "same as ui_audio.gd; no preview boost", "order": order},
        "cues": records,
    }
    (OUT / "ui_v08_manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "UI v0.8 soft paper / wood cues",
        "=============================",
        "Original synthesized foley. No external media or recording license dependencies.",
        "No tonal oscillators, electronic sweeps, resonant filters, clipping or per-clip peak normalization.",
        "The source WAVs are already quiet. Playback gains below add headroom; do not normalize on import.",
        "", "Cue / seconds / suggested gain / semantic use",
        "button_press / 0.072 / -3 dB / an ordinary local button action",
        "paper_popup / 0.220 / -2 dB / a small panel or modal opens",
        "page_turn / 0.380 / -3 dB / changing the current full page",
        "scroll_unroll / 0.580 / -4 dB / growth or shop parchment unfolds",
        "paper_close / 0.164 / -2 dB / a panel folds or closes",
        "parchment_burn / 0.890 / -5 dB / a special parchment burn/dissolve exit",
        "choice_confirm / 0.168 / -1 dB / an accepted purchase or growth choice",
        "", "Hover: silent. Use one semantic sound for a visible UI action, avoiding a redundant press + page cue.",
        "UIAudio: preload('res://src/ui_audio.gd').new(); add_child(node); node.play('page_turn').",
        "Four voices maximum; per-cue cooldowns; full pool drops new requests to preserve soft tails.",
        "Headless mode creates no AudioStreamPlayer nodes and loads no audio streams.",
        "", "Listening boundary: NOT listened to in this model session. Technical QC cannot establish pleasantness.",
        "ui_v08_preview.wav plays these cues at the actual suggested gains. Timings:",
    ]
    lines.extend(f"  {item['starts_at_s']:.3f} - {item['ends_at_s']:.3f} s : {item['cue']}" for item in order)
    (OUT / "README.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"technical_qc": "passed", "listening_verified": False, "preview": report["preview"], "cues": records}, indent=2))


if __name__ == "__main__":
    main()
