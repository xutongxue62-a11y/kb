from pathlib import Path
from datetime import datetime
from PIL import Image, ImageChops, ImageStat
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
baseline = json.loads((root / 'docs/native_ui_v29_baseline.json').read_text('utf-8'))
install = json.loads((root / 'docs/ui_v29_install.json').read_text('utf-8'))
before = Path(baseline['snapshot'])

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

runner = (root / 'tools/run_tests.ps1').read_text('utf-8-sig')
test_list = runner.split('foreach ($testName in @(')[1].split('))')[0]
names = re.findall(r"'([a-z0-9_]+)'", test_list)
assert len(names) == 45 and len(set(names)) == 45
groups = []
for name in names:
    path = root / 'logs' / ('ui_v29_suite_' + name + '.log')
    log = path.read_text('utf-8-sig')
    result = re.search(r'RESULT: (\d+) checks, (\d+) failures', log)
    assert result and int(result[2]) == 0 and not re.search(r'ERROR:|SCRIPT ERROR|Parse Error|FAIL:', log), name
    groups.append({'group': name, 'checks': int(result[1]), 'log_sha256': sha(path)})

captures = {}
for folder, script in [('ui_v29_installed', 'capture_ui_v29'),
                       ('ui_v29_installed_controls', 'capture_ui_v29_controls'),
                       ('ui_v29_installed_details', 'capture_ui_v29_details')]:
    data = json.loads((root / 'previews' / folder / 'preview.json').read_text('utf-8'))
    assert data['failures'] == 0 and data['applied_to_formal_game'] and not data['real_player_storage_used']
    for suffix in ('.log', '_console.log'):
        log = (root / 'logs' / (script + suffix)).read_text('utf-8-sig')
        assert not re.search(r'ERROR:|SCRIPT ERROR|Parse Error|FAIL:', log), (script, suffix)
    captures[folder] = data

folder = root / 'previews/ui_v29_installed'
regions = captures['ui_v29_installed']['target_regions']

def region(key, part='all'):
    x, y, w, h = regions[key]
    if part == 'left':
        return tuple(map(round, (x + 15, y + 9, x + w * .40, y + h - 10)))
    if part == 'right':
        return tuple(map(round, (x + w * .60, y + 9, x + w - 15, y + h - 10)))
    return tuple(map(round, (x + 13, y + 9, x + w - 13, y + h - 10)))

def difference(first, second, box):
    with Image.open(folder / (first + '.png')) as a, Image.open(folder / (second + '.png')) as b:
        return ImageChops.difference(a.convert('RGB').crop(box), b.convert('RGB').crop(box)).getbbox()

pixel_checks = []
for key in regions:
    assert difference(key + '_full', key + '_full_without_marks', region(key)) is None, key
    pixel_checks.append({'button': key, 'fully_brushed_marks_absent': True})
assert difference('weapon_rest', 'weapon_rest_without_marks', region('weapon')) is not None
assert difference('reward_cave_mid', 'weapon_mid_without_marks', region('weapon', 'left')) is None
assert difference('reward_cave_mid', 'weapon_mid_without_marks', region('weapon', 'right')) is not None

controls = root / 'previews/ui_v29_installed_controls'
status_bounds = []
with Image.open(controls / 'settings_toggled.png') as a, Image.open(controls / 'settings_without_status_text.png') as b:
    for key in ('music_switch', 'autosave_switch'):
        x, y, w, h = regions[key]
        box = tuple(map(round, (x, y, x + w, y + h)))
        changed = ImageChops.difference(a.convert('RGB').crop(box), b.convert('RGB').crop(box)).getbbox()
        assert changed and 77 <= changed[0] < changed[2] <= 149 and 0 <= changed[1] < changed[3] <= 50
        status_bounds.append({'setting': key, 'visible_status_pixel_bounds': changed, 'inside_button': True})

with Image.open(root / 'previews/native_ui_v29/reward_cave_mid.png') as a, Image.open(folder / 'reward_cave_mid.png') as b:
    box = (145, 112, 1135, 585)
    diff = ImageChops.difference(a.convert('RGB').crop(box), b.convert('RGB').crop(box))
    approved_ui_mean_error = ImageStat.Stat(diff).mean
    assert max(approved_ui_mean_error) < .5, approved_ui_mean_error

changed_existing = []
assets = []
players = []
protected_sources = []
for rel, data in baseline['files'].items():
    if rel.startswith('assets/'):
        assert sha(root / rel) == data['sha256'], 'An original asset changed: ' + rel
        assets.append(rel)
    elif rel.startswith('src/'):
        if sha(root / rel) != data['sha256']:
            changed_existing.append(rel)
        else:
            protected_sources.append(rel)
    elif '/saves/' in rel:
        assert sha(root / rel) == data['sha256'], 'Player save changed during integration: ' + rel
        players.append({'path': rel, 'sha256': data['sha256'], 'backup': str(before / rel)})
assert len(players) == 4
assert set(changed_existing) == set(install['changed_source_files']).intersection(baseline['files'])
for rel, digest in install['installed_sha256'].items():
    assert sha(root / rel) == digest, 'Installed output changed: ' + rel
new_sources = [p.relative_to(root).as_posix() for p in (root / 'src').glob('*.gd')
               if p.relative_to(root).as_posix() not in baseline['files']]
assert set(new_sources) == set(install['changed_source_files']) - set(baseline['files'])
for rel in ('启动样板.cmd', 'project.godot', 'main.tscn'):
    assert sha(root / rel) == baseline['files'][rel]['sha256']
assert (root / 'README.md').read_text('utf-8-sig').endswith((before / 'README.md').read_text('utf-8-sig'))

report = {
    'verified_at': datetime.now().astimezone().isoformat(),
    'installed': True, 'user_visual_approval': install['user_visual_approval'],
    'before_snapshot': baseline['snapshot'],
    'test_groups': groups, 'checks': sum(group['checks'] for group in groups),
    'native_checks': sum(data['checks'] for data in captures.values()), 'native_captures': captures,
    'native_pixel_mask_checks': pixel_checks,
    'half_brush': {'covered_marks_absent': True, 'uncovered_marks_present': True},
    'settings_status_pixel_bounds': status_bounds,
    'approved_ui_mean_pixel_error_rgb': approved_ui_mean_error,
    'original_assets_unchanged': len(assets), 'player_files_unchanged': players,
    'changed_existing_sources': sorted(changed_existing), 'new_sources': sorted(new_sources),
    'protected_sources': protected_sources, 'launcher_project_scene_unchanged': True,
    'review': {'blocking_p1_p2': 0, 'minor_copy_clarification': install['review_copy_clarification']},
    'source_sha256': {p.relative_to(root).as_posix(): sha(p) for p in (root / 'src').glob('*.gd')},
    'deferred_scope': ['ground chest appearance', 'left-to-right character-page burn'],
}
(root / 'docs/ui_v29_verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
install['verification_pending'] = False
install['verification_report'] = 'docs/ui_v29_verification.json'
(root / 'docs/ui_v29_install.json').write_text(json.dumps(install, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'installed': True, 'groups': len(groups), 'checks': report['checks'],
                  'native_checks': report['native_checks'], 'mask_checks': len(pixel_checks),
                  'original_assets_unchanged': len(assets), 'player_files_unchanged': len(players),
                  'approved_ui_mean_pixel_error_rgb': approved_ui_mean_error}, ensure_ascii=True))
