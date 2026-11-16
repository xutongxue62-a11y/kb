"""Original short game sounds; paper, ink, and dry typographic gestures. No source recordings."""
from pathlib import Path
import math, random, struct, wave, json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sfx"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 44100
PEAK = 0.92

SPECS = {
    "wood_hit": 0.22,
    "stone_hit": 0.26,
    "swing": 0.16,
    "sling": 0.12,
    "powder": 0.40,
    "blast": 0.44,
    "magic": 0.28,
    "magic_hit": 0.22,
    "chain_out": 0.28,
    "chain_in": 0.24,
    "step": 0.09,
    "hurt": 0.18,
    "ui_hover": 0.12,
    "ui_click": 0.14,
    "ui_open": 0.36,
    "ui_whoosh": 0.32,
    "ui_back": 0.30,
    "ui_stamp": 0.22,
}


def env_exp(t, duration, attack=0.003, release_tail=0.03, decay=6.0):
    x = t / duration
    attack_g = min(1.0, t / max(attack, 1e-4))
    release = min(1.0, max(0.0, (1.0 - x) / max(release_tail / duration, 1e-3)))
    return attack_g * math.exp(-x * decay) * release


def soft_noise(rng, prev, coeff=0.8):
    n = rng.uniform(-1.0, 1.0)
    return coeff * prev + (1.0 - coeff) * n, n


def tone(freq, t, phase=0.0):
    return math.sin(2 * math.pi * freq * t + phase)


def finalize(samples):
    if not samples:
        return samples
    peak = max(abs(v) for v in samples) or 1.0
    out = [max(-1.0, min(1.0, v * (PEAK / peak))) for v in samples]
    peak2 = max(abs(v) for v in out) or 1.0
    if peak2 > 0.98:
        out = [v * (0.98 / peak2) for v in out]
    return out


def write_wav(path, samples):
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in samples))


def rustle(white, mid, t, duration, reverse=False):
    """Dry page-fiber noise with a typographic whoosh, almost no musical pitch."""
    x = t / duration
    sweep = (1.0 - x) if reverse else x
    # band-limited paper: mid fibers minus slow body
    paper = mid * 0.85 + white * 0.18
    gate = math.sin(math.pi * min(1.0, max(0.0, x))) ** 1.05
    # a faint air fringe, not a beep: very quiet, quickly decaying
    air = math.sin(2 * math.pi * (220 + 260 * sweep) * t) * 0.04 * gate
    flap = 0.0
    if 0.12 < x < 0.55:
        flap = mid * 0.35 * math.sin((x - 0.12) / 0.43 * math.pi)
    return (paper * (0.7 + 0.3 * gate) + air + flap) * min(1.0, t / 0.008) * min(1.0, (1.0 - x) / 0.10)


def synthesize(name, duration, rng):
    count = int(RATE * duration)
    samples = []
    low = 0.0
    mid = 0.0
    grain = 0.0
    lp = 0.0
    for i in range(count):
        t = i / RATE
        x = t / duration
        low, white = soft_noise(rng, low, 0.86)
        mid, _ = soft_noise(rng, mid, 0.48)
        grain, _ = soft_noise(rng, grain, 0.22)
        if name == "wood_hit":
            # dry woodblock / inked stamp on a board, short and comic
            body = tone(92 - 36 * x, t) * 0.55 + tone(168 - 50 * x, t) * 0.12
            tick = (white * 0.25 + grain * 0.4) * math.exp(-t * 55)
            value = (body + tick + low * 0.12) * env_exp(t, duration, 0.0012, 0.03, 10.0)
        elif name == "stone_hit":
            body = tone(54 - 16 * x, t) * 0.7
            grit = (white * 0.35 + mid * 0.4 + grain * 0.2) * math.exp(-t * 22)
            value = (body + grit) * env_exp(t, duration, 0.001, 0.04, 7.0)
        elif name == "swing":
            whoosh = (mid * 0.8 + white * 0.2 - low * 0.15) * (math.sin(math.pi * x) ** 1.4)
            value = whoosh * min(1.0, t / 0.006)
        elif name == "sling":
            flick = (grain * 0.55 + mid * 0.2) * math.exp(-t * 48)
            zip_ = tone(740 - 480 * x, t) * 0.12 * math.exp(-t * 22)
            value = (flick + zip_) * env_exp(t, duration, 0.0007, 0.025, 16.0)
        elif name == "powder":
            boom = tone(48 - 16 * x, t) * 0.7 + low * 0.55
            paper_burst = 0.0
            if t > 0.04:
                paper_burst = (white * 0.4 + mid * 0.35) * math.exp(-(t - 0.04) * 8.0)
            value = (boom + paper_burst) * env_exp(t, duration, 0.004, 0.07, 4.6)
        elif name == "blast":
            boom = tone(40 - 12 * x, t) * 0.85 + low * 0.7
            crackle = (white * 0.4 + grain * 0.3) * math.exp(-t * 6.0)
            value = (boom + crackle * 0.7) * env_exp(t, duration, 0.004, 0.08, 3.8)
        elif name == "magic":
            # dry ink-whisper rather than a chime pad
            wash = (mid * 0.35 + white * 0.08) * math.sin(math.pi * x)
            fringe = tone(430 - 60 * x, t) * 0.16 * math.exp(-t * 8)
            value = (wash + fringe) * env_exp(t, duration, 0.008, 0.07, 5.2)
        elif name == "magic_hit":
            slap = (grain * 0.3 + mid * 0.2) * math.exp(-t * 20)
            tip = tone(520, t) * 0.14 * math.exp(-t * 16)
            value = (slap + tip) * env_exp(t, duration, 0.0015, 0.05, 8.0)
        elif name in ("chain_out", "chain_in"):
            value = rustle(white, mid, t, duration, reverse=(name == "chain_in"))
            # a light metallic fiber, still quiet
            freq = (500 + 700 * x) if name == "chain_out" else (1200 - 700 * x)
            value += tone(freq, t) * 0.07 * math.sin(math.pi * x)
        elif name == "step":
            value = (low * 0.65 + mid * 0.12) * env_exp(t, duration, 0.002, 0.025, 18.0)
        elif name == "hurt":
            value = (tone(200 - 120 * x, t) * 0.4 + low * 0.3 + mid * 0.12) * env_exp(t, duration, 0.002, 0.04, 7.5)
        elif name == "ui_hover":
            # fingertip on newsprint: a tiny dry fiber tick, no beep
            tick = (grain * 0.7 + mid * 0.25) * math.exp(-t * 48)
            value = tick * min(1.0, t / 0.0012) * min(1.0, (1.0 - x) / 0.2)
        elif name == "ui_click":
            # type-bar / dry paper tap
            slam = (low * 0.35 + tone(70, t) * 0.2) * math.exp(-t * 28)
            paper = (white * 0.35 + grain * 0.45) * math.exp(-t * 26)
            value = (slam + paper) * env_exp(t, duration, 0.0008, 0.035, 12.0)
        elif name == "ui_open":
            value = rustle(white, mid, t, duration, reverse=False)
        elif name == "ui_whoosh":
            # typographic wipe: shorter, drier page turn
            value = rustle(white, mid, t, duration, reverse=False) * 0.92
        elif name == "ui_back":
            value = rustle(white, mid, t, duration, reverse=True)
        elif name == "ui_stamp":
            # rubber stamp: low thud + ink squish, no sine beep
            thud = (tone(62 - 14 * x, t) * 0.55 + tone(110, t) * 0.08 + low * 0.4) * math.exp(-t * 14)
            ink = (white * 0.28 + mid * 0.35 + grain * 0.15) * math.exp(-t * 16)
            # brief contact slap at the start
            slap = grain * 0.5 * math.exp(-t * 70)
            value = (thud + ink + slap) * env_exp(t, duration, 0.001, 0.045, 9.0)
        else:
            value = (mid * 0.4 + low * 0.2) * env_exp(t, duration, 0.002, 0.04, 7.0)
        samples.append(value)
    return finalize(samples)


def main():
    records = []
    for index, (name, duration) in enumerate(SPECS.items()):
        rng = random.Random(62411 + index * 29)
        samples = synthesize(name, duration, rng)
        path = OUT / (name + ".wav")
        write_wav(path, samples)
        peak = max(abs(v) for v in samples) or 0.0
        rms = math.sqrt(sum(v * v for v in samples) / len(samples))
        records.append({
            "sound": name,
            "seconds": round(duration, 3),
            "peak": round(peak, 4),
            "rms": round(rms, 4),
            "clipped": any(abs(v) >= 0.999 for v in samples),
        })
    print(json.dumps(records, indent=2))


if __name__ == "__main__":
    main()
