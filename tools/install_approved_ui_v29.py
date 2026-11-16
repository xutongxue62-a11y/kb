from pathlib import Path
from datetime import datetime
import hashlib
import json

root = Path(__file__).resolve().parents[1]
approval = json.loads((root / 'docs/native_ui_v29_preview.json').read_text('utf-8'))
stage = Path(approval['workspace'])
baseline = json.loads((root / 'docs/native_ui_v29_baseline.json').read_text('utf-8'))
assert not (root / 'docs/ui_v29_install.json').exists(), 'Preserve the existing installation record'
sources = {
    'src/ui_frontend.gd', 'src/ui_home_action.gd', 'src/ui_ink_button_fx.gd',
    'src/ui_offer_layout.gd', 'src/ui_paper.gd', 'src/ui_paper_brush.gd',
    'src/ui_paper_pattern.gd', 'src/ui_paper_toggle.gd',
    'src/ui_reward_scroll_art.gd', 'src/ui_weapon_details.gd',
}
def sha(data): return hashlib.sha256(data).hexdigest()

# The approved artifact stays immutable; refuse unexpected candidate or live edits.
for rel, digest in approval['preview_source_sha256'].items():
    assert sha((stage / rel).read_bytes()) == digest, 'Candidate changed: ' + rel
for rel, data in baseline['files'].items():
    if rel.startswith(('src/', 'assets/')):
        assert sha((root / rel).read_bytes()) == data['sha256'], 'Concurrent edit: ' + rel
actual = {p.relative_to(stage).as_posix() for p in (stage / 'src').glob('*.gd')
          if not (root / p.relative_to(stage)).exists()
          or p.read_bytes() != (root / p.relative_to(stage)).read_bytes()}
assert actual == sources, ('Unexpected source scope', actual)

prepared = {}
for rel in sources:
    data = (stage / rel).read_bytes()
    if rel not in baseline['files']:
        assert not (root / rel).exists(), 'Do not replace an unrelated new source: ' + rel
    if rel == 'src/ui_weapon_details.gd':
        # Read-only review clarification: high-tier/buffed sling shots can ricochet/pierce.
        old = '石弹飞行命中单个目标。'
        new = '石弹沿飞行路径命中敌人。'
        text = data.decode('utf-8')
        assert text.count(old) == 1
        data = text.replace(old, new, 1).encode('utf-8')
    prepared[rel] = data

fixtures = {
    'capture_controls_preview.gd': 'capture_ui_v29_controls.gd',
    'capture_cave_marks_preview.gd': 'capture_ui_v29.gd',
    'capture_pattern_preview.gd': 'capture_ui_v29_details.gd',
}
for old, new in fixtures.items():
    assert not (root / 'tests' / new).exists(), 'Preserve existing capture: ' + new
    text = (stage / 'tests' / old).read_text('utf-8')
    text = text.replace('res://tests/capture_controls_preview.gd', 'res://tests/capture_ui_v29_controls.gd')
    text = text.replace('native_ui_v27', 'ui_v29_installed_controls')
    text = text.replace('native_ui_v28', 'ui_v29_installed_details')
    text = text.replace('native_ui_v29', 'ui_v29_installed')
    text = text.replace('"applied_to_formal_game":false', '"applied_to_formal_game":true')
    prepared['tests/' + new] = text.encode('utf-8')

for rel, data in prepared.items():
    (root / rel).write_bytes(data)
    assert (root / rel).read_bytes() == data

readme = root / 'README.md'
text = readme.read_text('utf-8-sig')
note = '> 当前 UI 更新：v29，已合入用户确认的壁画/图腾纸面、刷色后隐藏花纹、设置开关排版、奖励单份出售和武器详细说明；原素材与玩家进度保留。见 [docs/ui_v29_notes.md](docs/ui_v29_notes.md)。\n\n'
readme.write_text(note + text, encoding='utf-8')
report = {
    'installed_at': datetime.now().astimezone().isoformat(),
    'approved_preview_workspace': str(stage), 'before_snapshot': baseline['snapshot'],
    'changed_source_files': sorted(sources),
    'installed_sha256': {rel: sha(data) for rel, data in prepared.items()},
    'review_copy_clarification': {'path': 'src/ui_weapon_details.gd', 'from': '石弹飞行命中单个目标。', 'to': '石弹沿飞行路径命中敌人。'},
    'user_visual_approval': '还行，这个改得还可以，把这个加进去吧。',
    'verification_pending': True,
}
(root / 'docs/ui_v29_install.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'installed_ui_sources': len(sources), 'capture_fixtures': len(fixtures), 'snapshot': baseline['snapshot']}, ensure_ascii=True))
