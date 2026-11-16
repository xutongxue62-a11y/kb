from pathlib import Path
from datetime import datetime
import hashlib
import json

root = Path(__file__).resolve().parents[1]
approval = json.loads((root / 'docs/native_ui_v31_preview.json').read_text('utf-8'))
stage = Path(approval['workspace'])
stage_base = json.loads((stage / 'formal_baseline.json').read_text('utf-8'))
baseline = json.loads((root / 'docs/native_ui_v31_baseline.json').read_text('utf-8'))
assert not (root / 'docs/ui_v31_install.json').exists(), 'Preserve the existing installation record'
sources = {
    'src/economy.gd', 'src/main.gd', 'src/hud.gd', 'src/ui_buff_details.gd',
    'src/ui_offer_layout.gd', 'src/ui_paper_pattern.gd',
}

def sha(data):
    return hashlib.sha256(data).hexdigest()

# Preflight every input and the complete live source/art scope before writing.
for rel, digest in approval['preview_source_sha256'].items():
    assert sha((stage / rel).read_bytes()) == digest, 'Candidate changed: ' + rel
for rel, digest in stage_base['sha256'].items():
    if rel.startswith(('src/', 'assets/')):
        assert sha((root / rel).read_bytes()) == digest, 'Edit since preview: ' + rel
for rel, item in baseline['files'].items():
    if rel.startswith(('src/', 'assets/')):
        assert sha((root / rel).read_bytes()) == item['sha256'], 'Concurrent edit: ' + rel
actual = {p.relative_to(stage).as_posix() for p in (stage / 'src').glob('*.gd')
          if not (root / p.relative_to(stage)).exists()
          or p.read_bytes() != (root / p.relative_to(stage)).read_bytes()}
assert actual == sources, ('Unexpected source scope', actual)
prepared = {rel: (stage / rel).read_bytes() for rel in sorted(sources)}
for rel in ('tests/test_reward_buff_sale_v30.gd', 'tests/test_reward_sale_v23.gd'):
    if rel in baseline['files']:
        assert sha((root / rel).read_bytes()) == baseline['files'][rel]['sha256'], rel
    else:
        assert not (root / rel).exists(), 'Preserve a new test: ' + rel
    prepared[rel] = (stage / rel).read_bytes()

fixtures = {
    'capture_ui_v30.gd': ('native_ui_v30', 'ui_v31_installed_readability'),
    'capture_ui_v31.gd': ('native_ui_v31', 'ui_v31_installed_incoming'),
}
for name, (old, new) in fixtures.items():
    rel = 'tests/' + name
    assert not (root / rel).exists(), 'Preserve existing capture: ' + name
    assert not (root / 'previews' / new).exists(), 'Preserve previous screenshots'
    text = (stage / rel).read_text('utf-8')
    assert text.count('/previews/' + old) == 1
    assert text.count('"applied_to_formal_game":false') == 1
    text = text.replace('/previews/' + old, '/previews/' + new)
    text = text.replace('"applied_to_formal_game":false', '"applied_to_formal_game":true')
    prepared[rel] = text.encode('utf-8')

runner_rel = 'tools/run_tests.ps1'
assert sha((root / runner_rel).read_bytes()) == baseline['files'][runner_rel]['sha256']
runner = (root / runner_rel).read_text('utf-8-sig')
old = "'reward_sale_v23'))"
assert runner.count(old) == 1 and 'reward_buff_sale_v30' not in runner
prepared[runner_rel] = runner.replace(old, "'reward_sale_v23', 'reward_buff_sale_v30'))").encode('utf-8')
readme = root / 'README.md'
assert sha(readme.read_bytes()) == baseline['files']['README.md']['sha256']
note = '> 当前 UI 更新：v31。已合入确认的 BUFF 奖励出售、等级/功能/购买与金币提示，以及更换武器页的图标和完整说明排版。原配色、花纹、素材和玩家存档保留。详见 [docs/ui_v31_notes.md](docs/ui_v31_notes.md)。\n\n'
prepared['README.md'] = (note + readme.read_text('utf-8-sig')).encode('utf-8')

for rel, data in prepared.items():
    (root / rel).write_bytes(data)
    assert (root / rel).read_bytes() == data, rel
report = {
    'installed_at': datetime.now().astimezone().isoformat(),
    'approved_preview_workspace': str(stage),
    'approval_record': 'docs/native_ui_v31_preview.json',
    'includes_preview': 'native_ui_v30',
    'before_snapshot': baseline['snapshot'],
    'changed_source_files': sorted(sources),
    'installed_sha256': {rel: sha(data) for rel, data in prepared.items()},
    'user_visual_approval': '还行吧，那就应用上去就。那就应用上去吧。',
    'verification_pending': True,
    'real_player_storage_used': False,
}
(root / 'docs/ui_v31_install.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'installed_sources': len(sources), 'test_files': 2,
                  'capture_fixtures': len(fixtures), 'snapshot': baseline['snapshot']}, ensure_ascii=True))
