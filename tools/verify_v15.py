"""Verify the close-weapon update and preserve current player saves without restoring old data."""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
baseline = Path(json.loads((root / 'docs/v15_baseline.json').read_text('utf-8'))['snapshot'])

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

runner = (root / 'tools/run_tests.ps1').read_text('utf-8-sig')
names = re.findall(r"'([a-z0-9_]+)'", runner.split('foreach ($testName in @(')[1].split('))')[0])
assert len(names) == 37 and len(set(names)) == 37
groups = []
for name in names:
    path = root / 'logs' / ('v06_' + name + '.log')
    log = path.read_text('utf-8-sig')
    result = re.search(r'RESULT: (\d+) checks, (\d+) failures', log)
    assert result and int(result[2]) == 0 and not re.search(r'ERROR:|SCRIPT ERROR|FAIL:', log), name
    groups.append({'group': name, 'checks': int(result[1]), 'failures': 0, 'sha256': sha(path)})

stem = 'v15_native_v4'
native_folder = root / 'previews' / stem
native = json.loads((native_folder / 'timeline.json').read_text('utf-8'))
assert native['checks'] == 13 and native['failures'] == 0 and len(native['screenshots']) == 7
assert native['real_player_storage_used'] is False
for suffix in ('.log', '_console.log'):
    native_log = (root / 'logs' / (stem + suffix)).read_text('utf-8-sig')
    assert not re.search(r'ERROR:|SCRIPT ERROR|FAIL:|WARNING:', native_log), suffix
images = [native_folder / (shot['name'] + '.png') for shot in native['screenshots']]
images += [native_folder / 'layout_before_after.png', native_folder / 'weapon_growth_sheet.png']
assert all(p.is_file() and p.stat().st_size > 1000 for p in images)
movie = root / 'previews' / (stem + '.mp4')
video = json.loads((root / 'previews' / (stem + '_metadata.json')).read_text('utf-8'))
assert movie.is_file() and video['frames'] > 480 and video['fps'] == '60/1'
assert abs(video['seconds'] - video['audio_seconds']) < .04

assets = [p for p in (baseline / 'assets').rglob('*') if p.is_file()]
assert all(sha(p) == sha(root / p.relative_to(baseline)) for p in assets), 'Earlier asset changed'
allowed = {'src/main.gd', 'src/rules.gd', 'src/weapon_art.gd', 'src/expanded_weapons.gd'}
source_files = sorted(p for p in (baseline / 'src').rglob('*') if p.is_file())
changed = {p.relative_to(baseline).as_posix() for p in source_files if sha(p) != sha(root / p.relative_to(baseline))}
assert changed == allowed, changed
protected = [p.relative_to(baseline).as_posix() for p in source_files if p.relative_to(baseline).as_posix() not in allowed]

latest = baseline.parent / datetime.now().strftime('v15_latest_player_%Y%m%d_%H%M%S')
latest.mkdir()
player = []
for path in (root / 'runtime/Godot/app_userdata').rglob('*.json'):
    if 'saves' not in path.parts:
        continue
    data = path.read_bytes()
    relative = path.relative_to(root)
    target = latest / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    digest = hashlib.sha256(data).hexdigest()
    assert sha(target) == digest
    player.append({'path': str(relative), 'sha256': digest, 'backup': str(target),
                   'same_as_initial': (baseline / relative).is_file() and sha(baseline / relative) == digest})
assert player, 'No live save files found for preservation'

report = {
    'verified_at': datetime.now().astimezone().isoformat(), 'baseline': str(baseline),
    'groups': groups, 'checks': sum(g['checks'] for g in groups), 'native': native,
    'video': video, 'preview_sha256': {p.name: sha(p) for p in images + [movie]},
    'old_asset_files_unchanged': len(assets), 'changed_source_files': sorted(changed),
    'protected_source_files': protected, 'latest_player_files': player,
    'source_sha256': {p.relative_to(root).as_posix(): sha(p) for p in (root / 'src').rglob('*.gd')},
    'review': {'remaining_p1_p2': 0, 'fixed': ['bonebow firing and recoil keep the actual arrow direction']},
    'visual_checks': ['native single crossbow and six-weapon layout', 'native firing and compact formations',
                      'all fourteen stage textures', 'actual alpha torso clearance across all three characters'],
    'comparison': {'same_current_art_in_both_columns': True, 'old_layout_from_readonly_baseline': True,
                   'melee_hits_follow_new_orbit': True},
    'test_storage_isolated': True, 'user_acceptance_verified': False, 'subjective_listening_verified': False,
}
assert report['checks'] == 6601
(root / 'docs/v15_verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
(latest / 'manifest.json').write_text(json.dumps(player, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'groups': len(groups), 'checks': report['checks'], 'native_checks': native['checks'],
                  'old_assets_unchanged': len(assets), 'protected_source': len(protected),
                  'latest_player_files': len(player), 'player_unchanged_during_tests': all(p['same_as_initial'] for p in player)}, ensure_ascii=True))
