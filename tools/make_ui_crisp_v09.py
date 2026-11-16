"""Deterministic original UI micro-plucks, no recordings or external libraries except numpy.
Generate: python tools/make_ui_crisp_v09.py
Verify only: python tools/make_ui_crisp_v09.py --check
QC describes signal properties; listening_verified deliberately remains false.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/sfx/ui_v09'
RATE = 44100
# duration_ms, playback gain, cooldown_ms, source peak dBFS
SPECS = {
    'button_press': (60, -3., 90, -11.),
    'paper_popup': (130, -2., 170, -12.),
    'page_turn': (200, -3., 240, -12.),
    'scroll_unroll': (300, -4., 400, -11.),
    'paper_close': (95, -2., 140, -13.),
    'parchment_burn': (460, -5., 800, -15.),
    'choice_confirm': (150, -1., 150, -12.),
}
DESIGN = {
    'button_press': 'One dry small wooden tick; 1.65kHz body with rapidly damped inharmonic modes.',
    'paper_popup': 'Light 1.4kHz pluck, tiny fiber release, higher settling tick at 44ms.',
    'page_turn': 'Short fiber pickup and two clean fold articulations at 49ms / 107ms; no noise bed.',
    'scroll_unroll': 'Three spaced spindle ticks at 0 / 69 / 151ms, declining in weight, tiny paper accents.',
    'paper_close': 'One slightly lower woody tap, tiny soft paper contact at 13ms.',
    'parchment_burn': 'Eight irregular, quiet, very short ember snaps; no continuous hiss or sustained tone.',
    'choice_confirm': 'Two restrained bright modal plucks at 0 / 63ms with a rising interval and fast decay.',
}

def smooth(x):
    x = np.clip(x, 0., 1.)
    return x*x*(3.-2.*x)


def pluck(out, start, frequency, decay, gain):
    """Damped inharmonic resonances approximate a struck wood/glass contact, no pitch sweep."""
    first = round(start*RATE)
    t = np.arange(len(out)-first)/RATE
    envelope = smooth(t/.00065)
    modes = [(1., 1., 1.), (2.19, .40, .57), (3.73, .15, .33)]
    pulse = np.zeros_like(t)
    for ratio, weight, damping in modes:
        pulse += weight*np.sin(2*np.pi*frequency*ratio*t)*np.exp(-t/(decay*damping))
    out[first:] += gain*envelope*pulse


def fiber(out, rng, start, duration, gain):
    """Brief band-limited contact only; no sustained broadband paper wash."""
    first = round(start*RATE)
    count = min(round(duration*RATE), len(out)-first)
    t = np.arange(count)/RATE
    white = rng.normal(0., 1., count)
    freqs = np.fft.rfftfreq(count, 1/RATE)
    # Broad smooth band, tapered on both sides to avoid brittle digital crackle.
    band = smooth((freqs-1800)/1400)*smooth((8200-freqs)/2400)
    filtered = np.fft.irfft(np.fft.rfft(white)*band, n=count)
    env = smooth(t/.0007)*smooth((duration-t)/.003)*np.exp(-t/(duration*.25))
    out[first:first+count] += gain*filtered*env


def synthesize(key, seed):
    duration_ms, _, _, target = SPECS[key]
    out = np.zeros(round(duration_ms*RATE/1000))
    rng = np.random.default_rng(seed)
    if key == 'button_press':
        pluck(out, 0, 1650, .0065, 1.)
        fiber(out, rng, 0, .007, .08)
    elif key == 'paper_popup':
        pluck(out, 0, 1430, .011, 1.)
        fiber(out, rng, .008, .011, .16)
        pluck(out, .044, 2250, .006, .30)
    elif key == 'page_turn':
        fiber(out, rng, 0, .015, .22)
        pluck(out, .006, 1870, .007, .55)
        pluck(out, .049, 2490, .008, .75)
        fiber(out, rng, .055, .014, .16)
        pluck(out, .107, 1610, .007, .42)
    elif key == 'scroll_unroll':
        for start, frequency, gain in [(0, 1280, 1.), (.069, 1780, .72), (.151, 2180, .43)]:
            pluck(out, start, frequency, .011, gain)
            fiber(out, rng, start+.008, .012, .12*gain)
    elif key == 'paper_close':
        pluck(out, 0, 1180, .008, 1.)
        pluck(out, .013, 2540, .004, .14)
        fiber(out, rng, .007, .009, .12)
    elif key == 'parchment_burn':
        for start, frequency, gain in [(0, 2900, .75), (.029, 2400, .5), (.073, 3300, 1.), (.112, 1800, .45), (.169, 2800, .65), (.231, 3700, .38), (.298, 2200, .30), (.366, 3000, .18)]:
            pluck(out, start, frequency, .0025, gain)
            fiber(out, rng, start, .006, .13*gain)
    elif key == 'choice_confirm':
        pluck(out, 0, 1760, .013, .74)
        pluck(out, .063, 2349, .016, 1.)
        fiber(out, rng, 0, .006, .04)
    # Smooth source endpoints and remove DC with a tapered correction (also zero endpoints).
    t = np.arange(len(out))/RATE
    taper = smooth(t/.00045)*smooth((len(out)-1-np.arange(len(out)))/(.006*RATE))
    out *= taper
    out -= (out.sum()/taper.sum())*taper
    out *= 10**(target/20)/np.max(np.abs(out))
    return out


def write_wav(path, samples):
    assert np.max(np.abs(samples)) < 1, path
    pcm = np.rint(samples*32767).astype('<i2')
    with wave.open(str(path), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(pcm.tobytes())


def read_wav(path):
    with wave.open(str(path), 'rb') as f:
        assert (f.getnchannels(), f.getsampwidth(), f.getframerate()) == (1, 2, RATE)
        return np.frombuffer(f.readframes(f.getnframes()), '<i2').astype(float)/32768


def db(value):
    return float(20*np.log10(max(float(value), 1e-12)))


def stats(samples, gain):
    energy = samples*samples
    spectrum = np.abs(np.fft.rfft(samples))**2
    frequencies = np.fft.rfftfreq(len(samples), 1/RATE)
    return {
        'duration_ms': round(len(samples)/RATE*1000, 3),
        'source_peak_dbfs': round(db(np.max(np.abs(samples))), 3),
        'playback_peak_dbfs': round(db(np.max(np.abs(samples)))+gain, 3),
        'playback_rms_dbfs': round(db(np.sqrt(np.mean(energy)))+gain, 3),
        'mean_dc': round(float(np.mean(samples)), 9),
        'first_sample': float(samples[0]), 'last_sample': float(samples[-1]),
        'energy_90pct_ms': round(np.searchsorted(np.cumsum(energy), energy.sum()*.9)/RATE*1000, 3),
        'spectral_centroid_hz': round(float(np.sum(frequencies*spectrum)/np.sum(spectrum)), 1),
        'energy_below_600hz_pct': round(float(spectrum[frequencies<600].sum()/spectrum.sum()*100), 3),
    }


def validate():
    manifest = json.loads((OUT/'ui_v09_manifest.json').read_text(encoding='utf-8'))
    hashes = set()
    for key, (duration, gain, _, _) in SPECS.items():
        path = OUT/f'{key}.wav'
        samples = read_wav(path)
        measured = stats(samples, gain)
        assert measured == manifest['cues'][key]['measured'], f'stale manifest: {key}'
        assert abs(measured['duration_ms']-duration)<.1
        peak = measured['playback_peak_dbfs']
        assert (-23<=peak<=-18) if key=='parchment_burn' else (-16.1<=peak<=-12)
        assert samples[0] == samples[-1] == 0
        assert abs(samples.mean())<.0001
        assert np.max(np.abs(samples))<.5
        assert measured['energy_below_600hz_pct']<2
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest == manifest['cues'][key]['sha256']
        hashes.add(digest)
        assert digest != hashlib.sha256((ROOT/f'assets/sfx/ui_v08/{key}.wav').read_bytes()).hexdigest()
        old = manifest['cues'][key]['v08_measured']
        assert duration < old['duration_ms'], f'new tail not shorter: {key}'
        assert measured['energy_90pct_ms'] < old['energy_90pct_ms'], f'energy not faster: {key}'
    assert len(hashes)==7
    # Reconstruct previews from real source files and the production gain, catching wrong gain/order.
    for name in ['ui_v09_preview.wav', 'ui_v08_v09_ab_preview.wav']:
        actual = read_wav(OUT/name)
        for entry in manifest['previews'][name]:
            source = read_wav(ROOT/entry['file'])*10**(entry['gain_db']/20)
            first = round(entry['start_seconds']*RATE)
            assert np.max(np.abs(actual[first:first+len(source)]-source)) < 2/32768
    assert manifest['listening_verified'] is False
    print('UI_V09_QC RESULT: 7 distinct cues; duration/headroom/DC/endpoints, fast energy decay, preview gain/order: 0 failures')
    for key in SPECS:
        print(key, manifest['cues'][key]['measured'])


def generate():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {'version': '0.9', 'sample_rate': RATE, 'format': 'mono PCM16', 'listening_verified': False,
                'provenance': 'Original deterministic procedural synthesis; no external recordings/downloads.',
                'cues': {}, 'previews': {}}
    for index, (key, (duration, gain, cooldown, _)) in enumerate(SPECS.items()):
        path = OUT/f'{key}.wav'
        write_wav(path, synthesize(key, 900+index))
        manifest['cues'][key] = {'file': path.relative_to(ROOT).as_posix(), 'gain_db': gain,
            'min_gap_ms': cooldown, 'design': DESIGN[key],
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'measured': stats(read_wav(path), gain),
            'v08_measured': stats(read_wav(ROOT/f'assets/sfx/ui_v08/{key}.wav'), gain)}
    for name, versions in [('ui_v09_preview.wav', ['v09']), ('ui_v08_v09_ab_preview.wav', ['v08', 'v09'])]:
        chunks = [np.zeros(round(.3*RATE))]
        entries = []
        cursor = len(chunks[0])
        for key, (_, gain, _, _) in SPECS.items():
            for version in versions:
                path = ROOT/f'assets/sfx/ui_{version}/{key}.wav'
                samples = read_wav(path)*10**(gain/20)
                entries.append({'cue': key, 'version': version, 'file': path.relative_to(ROOT).as_posix(),
                    'gain_db': gain, 'start_seconds': round(cursor/RATE, 6),
                    'end_seconds': round((cursor+len(samples))/RATE, 6)})
                chunks.extend([samples, np.zeros(round(.55*RATE))])
                cursor += len(samples)+len(chunks[-1])
        write_wav(OUT/name, np.concatenate(chunks))
        manifest['previews'][name] = entries
    (OUT/'ui_v09_manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    text = ['UI v0.9: short bright micro-plucks / ticks', '',
        'Original deterministic synthesis. No external recording or licensing dependencies.',
        'Seven semantic keys, existing gains/cooldowns, four-voice scheduler and silent hover are retained.',
        'v08 remains intact. Resonant plucks supersede the rejected v08 filtered-noise palette.',
        'No reverb, pitch sweeps, sustained hiss, limiter or clipping. Modal attacks fade in under 1ms.',
        'Peak-scaled individually, then production gain is applied at playback; previews use that same gain.',
        'Engineering QC only: no model listening assessment and no user acceptance claimed.',
        '', 'Reproduce: python tools/make_ui_crisp_v09.py',
        'Check: python tools/make_ui_crisp_v09.py --check', '']
    for name, entries in manifest['previews'].items():
        text.extend([name, 'A/B preview: for EACH action, v08 first then v09. No spoken labels.' if 'ab_' in name else 'New v09 only, seven actions in the order below. No spoken labels.'])
        text.extend(f"{e['start_seconds']:6.3f}-{e['end_seconds']:6.3f}s  {e['version']}  {e['cue']}" for e in entries)
        text.append('')
    (OUT/'README.txt').write_text('\n'.join(text), encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if not args.check:
        generate()
    validate()
