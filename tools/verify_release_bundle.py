"""Verify versioned release artifacts and run isolated packaged Windows smokes."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import struct
import subprocess
import tarfile
import zipfile
import build_release as build

parser = argparse.ArgumentParser()
parser.add_argument('--version', required=True)
parser.add_argument('--build', required=True, type=int)
parser.add_argument('--android-version-code', required=True, type=int)
options = parser.parse_args()
build.configure_release(options.version, options.build, options.android_version_code)
proof = build.WORK / 'verification'
proof.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env['APPDATA'] = str(proof / 'profile')
env['LOCALAPPDATA'] = str(proof / 'profile/local')
env['TEMP'] = env['TMP'] = str(build.WORK / 'temporary')

def run(args, name, cwd=None, environment=None):
    result = subprocess.run([str(arg) for arg in args], cwd=cwd or build.ROOT,
                            env=environment or env, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=120)
    (proof / (name + '.log')).write_bytes(result.stdout)
    text = result.stdout.decode('utf-8', errors='replace')
    assert result.returncode == 0, (name, result.returncode, text[-1500:])
    assert not re.search(r'ERROR:|SCRIPT ERROR|Parse Error|FAIL:', text), (name, text[-1500:])
    return text

manifest = json.loads((build.OUTPUT / 'build_manifest.json').read_text('utf-8'))
assert manifest['version'] == options.version and manifest['build'] == options.build
assert not manifest['network_updates_enabled']
assert {row['platform'] for row in manifest['artifacts']} == {'Windows', 'Linux', 'Android'}
for row in manifest['artifacts']:
    artifact = build.OUTPUT / row['file']
    assert artifact.stat().st_size == row['bytes'] and build.digest(artifact) == row['sha256']
for name, digest in manifest['source_sha256'].items():
    assert build.digest(build.ROOT / name) == digest, 'Source changed after export: ' + name
    if name.startswith('src/'):
        assert build.digest(build.PROJECT / name) == digest, 'Staged source differs: ' + name

config = json.loads((build.PROJECT / 'release/update_config.json').read_text('utf-8'))
assert (config['version'], config['build'], config['feed_url']) == (options.version, options.build, '')
packs = {}
for target in ('Windows', 'Linux'):
    report = proof / (target.lower() + '_pack.json')
    run([build.ENGINE, '--headless', '--main-pack', build.OUTPUT / target / 'PrimitiveWildfrontier.pck',
         '--script', build.ROOT / 'tests/inspect_distribution_pack.gd', '--', report], target.lower() + '_pack')
    data = json.loads(report.read_text('utf-8'))
    assert data['font_available'] and data['regions_available'] and data['license_available']
    for name in data['files']:
        assert not any(part in name for part in ('/runtime/', '/tests/', '/tools/', '/previews/', 'private_keys', 'update_private', '.keystore', 'signing_password')), name
    packs[target] = len(data['files'])

with zipfile.ZipFile(build.OUTPUT / f'PrimitiveWildfrontier-v{options.version}-Windows-x64.zip') as archive:
    assert archive.testzip() is None and len(archive.namelist()) == 6
    assert json.loads(archive.read('PrimitiveWildfrontier/updates.json'))['feed_url'] == ''
    assert options.version in archive.read('PrimitiveWildfrontier/开始游玩.txt').decode('utf-8')
with tarfile.open(build.OUTPUT / f'PrimitiveWildfrontier-v{options.version}-Linux-x86_64.tar.gz') as archive:
    for member in archive.getmembers():
        if member.name.endswith(('.x86_64', '.sh')):
            assert member.mode == 0o755
    member = next(m for m in archive.getmembers() if m.name.endswith('.x86_64'))
    header = archive.extractfile(member).read(64)
    assert header[:4] == b'\x7fELF' and header[4] == 2 and struct.unpack_from('<H', header, 18)[0] == 62
exe = build.OUTPUT / 'Windows/PrimitiveWildfrontier.exe'
header = exe.read_bytes()[:4096]
offset = struct.unpack_from('<I', header, 0x3c)[0]
assert header[:2] == b'MZ' and header[offset:offset + 4] == b'PE\0\0' and struct.unpack_from('<H', header, offset + 4)[0] == 0x8664

apk = build.OUTPUT / f'PrimitiveWildfrontier-v{options.version}-Android.apk'
jdk = next((build.DEPS / 'jdk17').glob('jdk-*'))
sdk = build.DEPS / 'android_sdk/build-tools/35.0.1'
signature = run([jdk / 'bin/java.exe', '-jar', sdk / 'lib/apksigner.jar', 'verify', '--verbose', '--print-certs', apk], 'android_signature')
for scheme in ('v2', 'v3'):
    assert re.search(r'Verified using ' + scheme + r' scheme.*: true', signature)
previous = build.ROOT.parent / '原始人大作战_发行版/v0.23.0/PrimitiveWildfrontier-v0.23.0-Android.apk'
old_signature = run([jdk / 'bin/java.exe', '-jar', sdk / 'lib/apksigner.jar', 'verify', '--print-certs', previous], 'previous_android_signature')
certificate = re.search(r'Signer #1 certificate SHA-256 digest: (\w+)', signature)[1]
assert certificate == re.search(r'Signer #1 certificate SHA-256 digest: (\w+)', old_signature)[1], 'Android upgrade signing identity changed'
badging = run([sdk / 'aapt.exe', 'dump', 'badging', apk.name], 'android_badging', build.OUTPUT)
assert "name='org.cavebattle.wildfrontier'" in badging and f"versionName='{options.version}'" in badging
assert f"versionCode='{options.android_version_code}'" in badging and "sdkVersion:'24'" in badging
with zipfile.ZipFile(apk) as archive:
    assert archive.testzip() is None
    names = archive.namelist()
    assert {name.split('/')[1] for name in names if name.startswith('lib/')} == {'arm64-v8a', 'armeabi-v7a'}
    embedded = json.loads(archive.read('assets/release/update_config.json'))
    assert embedded['version'] == options.version and embedded['build'] == options.build
    for name in names:
        assert not any(part in name for part in ('private_keys', 'update_private', '.keystore', 'signing_password', 'assets/runtime/', 'assets/tests/', 'assets/tools/', 'assets/previews/')), name

smokes = {}
for kind, touch in (('desktop', False), ('touch', True)):
    profile = env.copy()
    profile['APPDATA'] = str(proof / ('profile_' + kind))
    profile['LOCALAPPDATA'] = str(proof / ('profile_' + kind) / 'local')
    output = proof / kind
    arguments = [exe, '--audio-driver', 'Dummy', '--', '--verify-release=' + str(output)]
    if touch:
        arguments.append('--touch-controls')
    run(arguments, 'native_' + kind, exe.parent, profile)
    smoke = json.loads((output / 'smoke.json').read_text('utf-8'))
    assert smoke['game_ready'] and not smoke['cached'] and smoke['updater_requests'] == 0
    assert (smoke['version'], smoke['build']) == (options.version, options.build)
    assert not smoke['real_player_storage_used']
    if touch:
        assert smoke['touch_checks'] and all(smoke['touch_checks'].values())
    smokes[kind] = smoke

checksums = '\n'.join(row['sha256'] + '  ' + row['file'] for row in manifest['artifacts']) + '\n'
(build.OUTPUT / 'SHA256SUMS.txt').write_text(checksums, encoding='utf-8', newline='\n')
report = {'version': options.version, 'build': options.build, 'artifacts': manifest['artifacts'],
          'pack_file_counts': packs, 'native_windows': smokes, 'android_signing_identity_unchanged': True,
          'apk_signatures_v2_v3_valid': True, 'linux_architecture_and_modes_valid': True,
          'private_files_absent': True, 'network_updates_enabled': False,
          'linux_device_playtested': False, 'android_device_playtested': False}
(proof / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'version': options.version, 'artifacts': len(manifest['artifacts']),
                  'windows_native_and_touch': True, 'apk_same_signature': True,
                  'linux_structure_valid': True, 'private_files_absent': True,
                  'proof': str(proof)}, ensure_ascii=False), flush=True)
