from pathlib import Path
from datetime import datetime
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import tarfile
import zipfile
import build_release as build

ROOT, WORK, OUTPUT = build.ROOT, build.WORK, build.OUTPUT
PROOF = WORK / ('verified_' + datetime.now().strftime('%Y%m%d_%H%M%S'))
PROOF.mkdir()
env = os.environ.copy(); env['APPDATA'] = str(PROOF / 'appdata'); env['LOCALAPPDATA'] = str(PROOF / 'appdata/local')

def run(args, name, cwd=ROOT, environment=None):
    result = subprocess.run([str(arg) for arg in args], env=environment or env, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
    (PROOF / (name + '.log')).write_bytes(result.stdout)
    text = result.stdout.decode('utf-8', errors='replace')
    assert result.returncode == 0, (name, result.returncode, text[-3000:])
    return text

manifest = json.loads((OUTPUT / 'build_manifest.json').read_text('utf-8'))
assert {row['platform'] for row in manifest['artifacts']} == {'Windows', 'Linux', 'Android'}
for relative, digest in manifest['source_sha256'].items():
    assert build.digest(ROOT / relative) == digest, 'Runtime source changed since export: ' + relative
for row in manifest['artifacts']:
    assert build.digest(OUTPUT / row['file']) == row['sha256'], row['file']

runner = (ROOT / 'tools/run_tests.ps1').read_text('utf-8-sig')
names = re.findall(r"'([a-z0-9_]+)'", runner.split('foreach ($testName in @(')[1].split('))')[0])
assert len(names) == len(set(names)) == 50
tests = []
for name in names:
    path = ROOT / 'logs' / ('release_v023_verified_suite_' + name + '.log')
    log = path.read_text('utf-8-sig')
    result = re.search(r'RESULT: (\d+) checks, (\d+) failures', log)
    assert result and int(result[2]) == 0 and not re.search(r'ERROR:|SCRIPT ERROR|Parse Error|FAIL:', log), name
    tests.append({'group': name, 'checks': int(result[1]), 'sha256': build.digest(path)})

pack_reports = {}
for target, filename in [('Windows', 'PrimitiveWildfrontier.pck'), ('Linux', 'PrimitiveWildfrontier.pck')]:
    path = OUTPUT / target / filename
    report = PROOF / (target.lower() + '_pack.json')
    text = run([build.ENGINE, '--headless', '--main-pack', path, '--script', ROOT / 'tests/inspect_distribution_pack.gd', '--', report], target.lower() + '_pack')
    assert 'ERROR:' not in text
    data = json.loads(report.read_text('utf-8'))
    assert data['font_available'] and data['regions_available'] and data['license_available']
    for file in data['files']:
        assert not any(part in file for part in ['/runtime/', '/tests/', '/tools/', '/previews/', 'private_keys', 'update_private', '.keystore', 'signing_password']), file
    pack_reports[target] = {'files': len(data['files']), 'report': str(report)}

windows_zip = OUTPUT / 'PrimitiveWildfrontier-v0.23.0-Windows-x64.zip'
with zipfile.ZipFile(windows_zip) as archive:
    assert archive.testzip() is None
    assert any(name.endswith('PrimitiveWildfrontier.pck') for name in archive.namelist())
    assert len(archive.namelist()) == 6
with tarfile.open(OUTPUT / 'PrimitiveWildfrontier-v0.23.0-Linux-x86_64.tar.gz') as archive:
    for member in archive.getmembers():
        if member.name.endswith(('.x86_64', '.sh')): assert member.mode == 0o755
    executable = next(member for member in archive.getmembers() if member.name.endswith('.x86_64'))
    header = archive.extractfile(executable).read(64)
    assert header[:4] == b'\x7fELF' and header[4] == 2 and struct.unpack_from('<H', header, 18)[0] == 62
exe = OUTPUT / 'Windows/PrimitiveWildfrontier.exe'
header = exe.read_bytes()[:4096]
pe = struct.unpack_from('<I', header, 0x3c)[0]
assert header[:2] == b'MZ' and header[pe:pe+4] == b'PE\0\0' and struct.unpack_from('<H', header, pe+4)[0] == 0x8664

apk = OUTPUT / 'PrimitiveWildfrontier-v0.23.0-Android.apk'
jdk = next((build.DEPS / 'jdk17').glob('jdk-*'))
sdk = build.DEPS / 'android_sdk/build-tools/35.0.1'
signature = run([jdk / 'bin/java.exe', '-jar', sdk / 'lib/apksigner.jar', 'verify', '--verbose', '--print-certs', apk], 'android_signature')
assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature
assert 'Verified using v3 scheme (APK Signature Scheme v3): true' in signature
badging = run([sdk / 'aapt.exe', 'dump', 'badging', apk.name], 'android_badging', OUTPUT)
assert "name='org.cavebattle.wildfrontier'" in badging and "versionName='0.23.0'" in badging and "sdkVersion:'24'" in badging
with zipfile.ZipFile(apk) as archive:
    assert archive.testzip() is None
    files = archive.namelist()
    assert {name.split('/')[1] for name in files if name.startswith('lib/')} == {'arm64-v8a', 'armeabi-v7a'}
    assert any('Godot-third-party.txt' in name for name in files)
    for name in files:
        assert not any(part in name for part in ['update_private', '.keystore', 'signing_password', 'assets/runtime/', 'assets/tests/', 'assets/tools/', 'assets/previews/']), name

smokes = {}
for kind, touch in [('desktop', False), ('touch', True)]:
    profile = env.copy(); profile['APPDATA'] = str(PROOF / ('profile_' + kind)); profile['LOCALAPPDATA'] = str(PROOF / ('profile_' + kind) / 'local')
    folder = PROOF / kind
    arguments = [exe, '--audio-driver', 'Dummy', '--', '--verify-release=' + str(folder)]
    if touch: arguments.append('--touch-controls')
    text = run(arguments, 'native_' + kind, exe.parent, profile)
    assert not re.search(r'ERROR:|SCRIPT ERROR|Parse Error', text)
    smoke = json.loads((folder / 'smoke.json').read_text('utf-8'))
    assert smoke['game_ready'] and not smoke['cached'] and smoke['updater_requests'] == 0
    if touch: assert smoke['touch_checks'] and all(smoke['touch_checks'].values())
    else: assert not smoke['touch_controls']
    smokes[kind] = smoke

run(['python', ROOT / 'tools/verify_release_transport.py'], 'transport')
run(['python', ROOT / 'tools/verify_release_recovery.py'], 'recovery')
content = WORK.parent / 'content_update_2026111604/public'
signed = json.loads((content / 'manifest.json').read_text('utf-8'))
payload = json.loads(signed['payload'])
metadata = payload['packages']['windows']
profile = env.copy(); profile['APPDATA'] = str(PROOF / 'profile_full_content'); profile['LOCALAPPDATA'] = str(PROOF / 'profile_full_content/local')
cache = Path(profile['APPDATA']) / 'Godot/app_userdata/原始人大作战 · 战斗样板/content_updates/v1'
cache.mkdir(parents=True)
pack = content / 'game-2026111604-windows.pck'
assert build.digest(pack) == metadata['sha256']
shutil.copy2(pack, cache / (metadata['sha256'] + '.pck'))
shutil.copy2(content / 'manifest.json', cache / 'active.json')
text = run([exe, '--headless', '--', '--verify-release=' + str(PROOF / 'full_content')], 'full_content', exe.parent, profile)
assert 'ERROR:' not in text
full_content = json.loads((PROOF / 'full_content/smoke.json').read_text('utf-8'))
assert full_content['cached'] and full_content['game_ready'] and full_content['build'] == 2026111604

baseline = json.loads((ROOT / 'docs/native_ui_v32_baseline.json').read_text('utf-8'))
assets, players = [], []
for relative, data in baseline['files'].items():
    if relative.startswith('assets/') or '/saves/' in relative:
        assert build.digest(ROOT / relative) == data['sha256'], relative
        (players if '/saves/' in relative else assets).append(relative)
assert len(assets) == 156 and len(players) == 4
report = {'verified_at': datetime.now().astimezone().isoformat(), 'artifacts': manifest['artifacts'],
          'test_groups': tests, 'checks': sum(item['checks'] for item in tests), 'failures': 0,
          'native_windows': smokes, 'pack_inspection': pack_reports, 'apk_signatures_v2_v3_valid': True,
          'linux_elf64_x86_64_and_executable_modes_valid': True,
          'local_https_and_next_boot': json.loads((WORK / 'transport_verification.json').read_text('utf-8')),
          'failed_update_recovery': json.loads((WORK / 'recovery_verification.json').read_text('utf-8')),
          'publisher_full_pack_loaded': full_content, 'original_assets_unchanged': len(assets),
          'current_player_files_unchanged': len(players), 'proof_directory': str(PROOF),
          'network_updates_enabled': False, 'linux_native_run_verified': False, 'android_device_run_verified': False}
(ROOT / 'docs/distribution_v023_verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'groups': len(tests), 'checks': report['checks'], 'failures': 0,
                  'windows_native_and_touch': True, 'apk_signatures_valid': True,
                  'update_transport_recovery_and_full_pack': True,
                  'assets_preserved': len(assets), 'player_files_preserved': len(players),
                  'proof': str(PROOF)}, ensure_ascii=False))
