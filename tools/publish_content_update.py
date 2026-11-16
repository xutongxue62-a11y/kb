"""Prepare signed update files for owner-controlled HTTPS hosting; never uploads."""
from pathlib import Path
from urllib.parse import urlsplit
import argparse
import json
import re
import shutil
import subprocess
import build_release as build

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--version', required=True)
    parser.add_argument('--build', type=int, required=True)
    parser.add_argument('--base-url', required=True, help='HTTPS directory where the public files will be hosted')
    options = parser.parse_args()
    assert re.fullmatch(r'\d+\.\d+\.\d+', options.version), 'Use a numeric game version'
    assert options.build > 2026111601, 'Content updates must use a newer build number'
    url = urlsplit(options.base_url)
    assert url.scheme == 'https' and url.hostname and not url.username and not url.password and not url.query and not url.fragment
    assert (build.KEYS / 'update_public.pem').read_bytes() == (build.ROOT / 'release/update_public.pem').read_bytes(), 'Signing identity changed'
    work = build.WORK.parent / ('content_update_' + str(options.build))
    work.mkdir(exist_ok=False)
    project = work / 'project'; project.mkdir()
    public = work / 'public'; public.mkdir()
    for folder in ('src', 'assets', 'release'):
        shutil.copytree(build.ROOT / folder, project / folder)
    shutil.copy2(build.ROOT / 'main.tscn', project / 'main.tscn')
    source_config = (build.ROOT / 'project.godot').read_text('utf-8')
    source_config = source_config.replace('[rendering]', '[rendering]\ntextures/vram_compression/import_etc2_astc=true\ntextures/vram_compression/import_s3tc_bptc=true')
    (project / 'project.godot').write_text(source_config, encoding='utf-8')
    cfg = build.presets().replace('exclude_filter=""', 'exclude_filter="release/*"')
    cfg = cfg.replace('release/*.json,release/*.pem,', '').replace('application/icon="res://release/icon.ico"', 'application/icon=""')
    (project / 'export_presets.cfg').write_text(cfg, encoding='utf-8')
    env = build.sdk_setup()
    env['APPDATA'] = str(work / 'export_userdata'); env['LOCALAPPDATA'] = str(work / 'export_userdata/local')
    def run(arguments, name):
        with (work / (name + '.log')).open('wb') as log:
            result = subprocess.run([str(build.ENGINE), '--headless', '--path', str(project), *arguments], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=600)
        output = (work / (name + '.log')).read_text('utf-8', errors='replace')
        assert result.returncode == 0 and not re.search(r'ERROR:|SCRIPT ERROR|Parse Error', output), name
    run(['--import'], 'import')
    packages = {}
    for platform in ('Windows', 'Linux', 'Android'):
        filename = f'game-{options.build}-{platform.lower()}.pck'
        path = public / filename
        run(['--export-pack', platform, str(path)], platform)
        packages[platform.lower()] = {'url': options.base_url.rstrip('/') + '/' + filename,
                                      'bytes': path.stat().st_size, 'sha256': build.digest(path)}
    payload = {'schema': 1, 'game': 'primitive_wildfrontier', 'version': options.version,
               'build': options.build, 'engine': '4.7.2', 'launcher_api': 1, 'packages': packages}
    payload_path = work / 'payload.json'
    payload_path.write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    result = subprocess.run([str(build.ENGINE), '--headless', '--path', str(build.ROOT), '--script',
                             'res://tools/sign_release_update.gd', '--', str(build.KEYS / 'update_private.pem'),
                             str(payload_path), str(public / 'manifest.json')], env=env, capture_output=True)
    assert result.returncode == 0, 'Signing failed'
    (public / 'SHA256SUMS.txt').write_text(''.join(build.digest(p) + '  ' + p.name + '\n' for p in sorted(public.iterdir()) if p.is_file()), encoding='utf-8')
    print('Prepared signed update files:', public)
    print('No files were uploaded. Upload only the public directory, with manifest.json last.')

if __name__ == '__main__': main()
