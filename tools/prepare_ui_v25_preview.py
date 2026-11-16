from pathlib import Path
import json
import hashlib
import shutil

root = Path(__file__).resolve().parents[1]
stage = root.parent / '原始人大作战_UI预览' / 'v25_pastel'
assert not stage.exists(), 'Preserve any existing preview workspace'
baseline = json.loads((root / 'docs/native_ui_v24_baseline.json').read_text('utf-8'))
before = Path(baseline['snapshot'])
stage.mkdir(parents=True)
for directory in ('src', 'assets'):
    shutil.copytree(root / directory, stage / directory)
for name in ('project.godot', 'main.tscn'):
    shutil.copy2(root / name, stage / name)
shutil.copytree(root / '.godot/imported', stage / '.godot/imported')
for name in ('global_script_class_cache.cfg', 'uid_cache.bin'):
    if (root / '.godot' / name).exists():
        shutil.copy2(root / '.godot' / name, stage / '.godot' / name)

# Only undo this turn's production visual edits, after keeping them in the preview workspace.
# The previous v23 work, other sources, user assets and all saves stay in place.
restored = []
for name in ('ui_paper_brush.gd', 'ui_home_action.gd', 'ui_ink_button_fx.gd', 'ui_paper.gd', 'ui_offer_layout.gd'):
    current = root / 'src' / name
    assert current.read_bytes() == (stage / 'src' / name).read_bytes(), 'Concurrent source edit: ' + name
    original = before / 'src' / name
    assert hashlib.sha256(original.read_bytes()).hexdigest() == baseline['files']['src/' + name]['sha256']
    shutil.copy2(original, current)
    restored.append('src/' + name)
new_art = root / 'src/ui_reward_scroll_art.gd'
assert new_art.read_bytes() == (stage / 'src/ui_reward_scroll_art.gd').read_bytes()
new_art.unlink()
assert all(hashlib.sha256((root / rel).read_bytes()).hexdigest() == data['sha256']
           for rel, data in baseline['files'].items() if rel.startswith(('src/', 'assets/')) or '/saves/' in rel)
report = {'workspace': str(stage), 'formal_sources_restored_to_turn_start': True,
          'formal_assets_and_player_saves_unchanged': True, 'restored_visual_sources': restored,
          'applied_to_formal_game': False, 'awaiting_user_visual_review': True}
(root / 'docs/native_ui_v25_preview.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=True))
