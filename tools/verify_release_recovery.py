from pathlib import Path
from datetime import datetime
import json
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT.parent / '原始人大作战_发行准备/v0.23.0'
TEST = WORK / ('recovery_' + datetime.now().strftime('%Y%m%d_%H%M%S'))
TEST.mkdir()
ENGINE = ROOT / 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
EXE = ROOT.parent / '原始人大作战_发行版/v0.23.0/Windows/PrimitiveWildfrontier.exe'
env = os.environ.copy(); env['APPDATA'] = str(TEST / 'appdata'); env['LOCALAPPDATA'] = str(TEST / 'appdata/local')
result = subprocess.run([str(ENGINE), '--headless', '--path', str(ROOT), '--script',
                         'res://tools/release_failure_fixtures.gd', '--', str(TEST),
                         str(WORK.parent / 'private_keys/update_private.pem')], env=env, capture_output=True, timeout=30)
assert result.returncode == 0, result.stderr
cache = TEST / 'appdata/Godot/app_userdata/原始人大作战 · 战斗样板/content_updates/v1'
cache.mkdir(parents=True)
for name, pointer in [('A', 'previous.json'), ('B', 'active.json')]:
    envelope = json.loads((TEST / (name + '.json')).read_text('utf-8'))
    payload = json.loads(envelope['payload'])
    shutil.copy2(TEST / (name + '.pck'), cache / (payload['packages']['windows']['sha256'] + '.pck'))
    shutil.copy2(TEST / (name + '.json'), cache / pointer)
for name in ('B', 'A'):
    result = subprocess.run([str(EXE), '--headless', '--quit-after', '120'], env=env, cwd=EXE.parent, capture_output=True, timeout=30)
    (TEST / (name + '_startup.log')).write_bytes(result.stdout + result.stderr)
    text = (result.stdout + result.stderr).decode('utf-8', errors='replace')
    assert 'UNREADY_' + name + '_EXECUTED' in text, text[-2000:]
    assert result.returncode == 1 and (cache / 'starting.json').exists(), 'Unready game was wrongly accepted and its recovery marker cleared'
    assert 'SCRIPT ERROR' not in text, text[-2000:]
result = subprocess.run([str(EXE), '--headless', '--', '--verify-release=' + str(TEST / 'base_recovered')], env=env, cwd=EXE.parent, capture_output=True, timeout=30)
(TEST / 'base_startup.log').write_bytes(result.stdout + result.stderr)
assert result.returncode == 0
smoke = json.loads((TEST / 'base_recovered/smoke.json').read_text('utf-8'))
assert smoke['game_ready'] and not smoke['cached'] and smoke['build'] == 2026111601
failed = json.loads((cache / 'failed.json').read_text('utf-8'))
assert set(failed['builds']) == {2026111602, 2026111603}
assert not (cache / 'active.json').exists() and not (cache / 'previous.json').exists()
report = {'fixture_root': str(TEST), 'unready_game_never_confirmed': True,
          'failed_active_then_failed_previous_recovers_builtin': True, 'failed_builds': failed['builds'],
          'builtin_smoke': smoke, 'real_player_storage_used': False}
(WORK / 'recovery_verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('RECOVERY RESULT: signed unready B rejected, signed unready A rejected, built-in game recovered.')
