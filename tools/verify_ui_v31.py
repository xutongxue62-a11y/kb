from pathlib import Path
from datetime import datetime
from PIL import Image, ImageChops, ImageStat
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
baseline = json.loads((root / 'docs/native_ui_v31_baseline.json').read_text('utf-8'))
install = json.loads((root / 'docs/ui_v31_install.json').read_text('utf-8'))
approval = json.loads((root / 'docs/native_ui_v31_preview.json').read_text('utf-8'))
before = Path(baseline['snapshot'])

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

runner = (root / 'tools/run_tests.ps1').read_text('utf-8-sig')
names = re.findall(r"'([a-z0-9_]+)'", runner.split('foreach ($testName in @(')[1].split('))')[0])
assert len(names) == len(set(names)) == 46
groups = []
for name in names:
    path = root / 'logs' / ('ui_v31_suite_' + name + '.log')
    log = path.read_text('utf-8-sig')
    result = re.search(r'RESULT: (\d+) checks, (\d+) failures', log)
    assert result and int(result[2]) == 0, name
    assert not re.search(r'ERROR:|SCRIPT ERROR|Parse Error|FAIL:', log), name
    groups.append({'group': name, 'checks': int(result[1]), 'log_sha256': sha(path)})

captures = {}
for folder, script in [('ui_v31_installed_readability', 'capture_ui_v30'),
                       ('ui_v31_installed_incoming', 'capture_ui_v31')]:
    data = json.loads((root / 'previews' / folder / 'preview.json').read_text('utf-8'))
    assert data['failures'] == 0 and data['applied_to_formal_game']
    assert not data['real_player_storage_used']
    assert all(mark['native_viewport'] for mark in data['screenshots'])
    for suffix in ('.log', '_console.log'):
        path = root / 'logs' / ('ui_v31_installed_' + script + suffix)
        assert not re.search(r'ERROR:|SCRIPT ERROR|Parse Error|FAIL:', path.read_text('utf-8-sig')), str(path)
    captures[folder] = data

parity = []
for old, new, name, box in [
    ('native_ui_v30', 'ui_v31_installed_readability', 'buff_rewards', (145, 112, 1135, 585)),
    ('native_ui_v30', 'ui_v31_installed_readability', 'shop_readability', (105, 65, 1175, 730)),
    ('native_ui_v31', 'ui_v31_installed_incoming', 'incoming_weapon_group', (105, 65, 1175, 730)),
]:
    approved = root / 'previews' / old / (name + '.png')
    applied = root / 'previews' / new / (name + '.png')
    with Image.open(approved) as a, Image.open(applied) as b:
        assert a.size == b.size == (1280, 800)
        difference = ImageChops.difference(a.convert('RGB').crop(box), b.convert('RGB').crop(box))
        error = ImageStat.Stat(difference).mean
        assert max(error) < .5, (name, error)
    parity.append({'scene': name, 'crop': box, 'mean_pixel_error_rgb': error,
                   'applied_screenshot': str(applied), 'screenshot_sha256': sha(applied)})

assets = []
players = []
changed = []
protected = []
for rel, item in baseline['files'].items():
    if rel.startswith('assets/'):
        assert sha(root / rel) == item['sha256'], 'Original asset changed: ' + rel
        assets.append(rel)
    elif rel.startswith('src/'):
        if sha(root / rel) != item['sha256']:
            changed.append(rel)
        else:
            protected.append(rel)
    elif '/saves/' in rel:
        assert sha(root / rel) == item['sha256'], 'Player save changed: ' + rel
        players.append({'path': rel, 'sha256': item['sha256'], 'backup': str(before / rel)})
assert len(players) == 4
assert set(changed) == set(install['changed_source_files']).intersection(baseline['files'])
new = [p.relative_to(root).as_posix() for p in (root / 'src').glob('*.gd')
       if p.relative_to(root).as_posix() not in baseline['files']]
assert set(new) == set(install['changed_source_files']) - set(baseline['files'])
for rel, digest in install['installed_sha256'].items():
    assert sha(root / rel) == digest, 'Installed output changed: ' + rel
for rel, digest in approval['preview_source_sha256'].items():
    assert sha(root / rel) == digest, 'Formal source differs from approved preview: ' + rel
for rel in ('启动样板.cmd', 'project.godot', 'main.tscn'):
    assert sha(root / rel) == baseline['files'][rel]['sha256'], rel
assert (root / 'README.md').read_text('utf-8-sig').endswith((before / 'README.md').read_text('utf-8-sig'))

report = {
    'verified_at': datetime.now().astimezone().isoformat(),
    'installed': True, 'before_snapshot': baseline['snapshot'],
    'user_visual_approval': install['user_visual_approval'],
    'test_groups': groups, 'checks': sum(item['checks'] for item in groups),
    'failures': 0,
    'native_checks': sum(item['checks'] for item in captures.values()),
    'native_captures': captures, 'approved_scene_pixel_comparison': parity,
    'original_assets_unchanged': len(assets), 'player_files_unchanged': players,
    'changed_existing_sources': sorted(changed), 'new_sources': sorted(new),
    'protected_sources': protected, 'all_approved_sources_match': True,
    'launcher_project_scene_unchanged': True,
    'source_sha256': {p.relative_to(root).as_posix(): sha(p) for p in (root / 'src').glob('*.gd')},
    'deferred_scope': ['ground chest appearance', 'left-to-right character-page burn'],
}
(root / 'docs/ui_v31_verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
install['verification_pending'] = False
install['verification_report'] = 'docs/ui_v31_verification.json'
(root / 'docs/ui_v31_install.json').write_text(json.dumps(install, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'installed': True, 'groups': len(groups), 'checks': report['checks'],
                  'native_checks': report['native_checks'], 'failures': 0,
                  'approved_scene_pixel_comparison': parity,
                  'original_assets_unchanged': len(assets), 'player_files_unchanged': len(players)}, ensure_ascii=True))
