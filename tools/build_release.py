"""Build runtime-only Windows/Linux/Android releases without touching player data."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import secrets
import shutil
import subprocess
import tarfile
import zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT.parent / '原始人大作战_发行准备' / 'v0.23.0'
KEYS = WORK.parent / 'private_keys'
DEPS = WORK / 'dependencies'
PROJECT = WORK / 'project'
OUTPUT = ROOT.parent / '原始人大作战_发行版' / 'v0.23.0'
ENGINE = ROOT / 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
TEMPLATES = ENGINE.parent / 'editor_data/export_templates/4.7.2.stable'
VERSION = '0.23.0'
BUILD = 2026111601
ANDROID_VERSION_CODE = 23
FEED_URL = ''

def configure_release(version, build_number, android_version_code):
    global VERSION, BUILD, ANDROID_VERSION_CODE, WORK, PROJECT, OUTPUT
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Use a three-part numeric release version')
    if build_number <= 0 or not 0 < android_version_code <= 2100000000:
        raise ValueError('Build numbers must be positive and valid for Android')
    VERSION, BUILD, ANDROID_VERSION_CODE = version, build_number, android_version_code
    WORK = ROOT.parent / '原始人大作战_发行准备' / ('v' + VERSION)
    PROJECT = WORK / 'project'
    OUTPUT = ROOT.parent / '原始人大作战_发行版' / ('v' + VERSION)
    # DEPS and KEYS deliberately retain the existing shared toolchain/identity.

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def setting(value):
    return json.dumps(str(value).replace('\\', '/'), ensure_ascii=False)

def sdk_setup():
    sdk = DEPS / 'android_sdk'
    parts = [
        (DEPS / 'sdk_platforms-android-35/android-35', sdk / 'platforms/android-35'),
        (DEPS / 'sdk_build-tools-35.0.1/android-15', sdk / 'build-tools/35.0.1'),
        (DEPS / 'sdk_platform-tools/platform-tools', sdk / 'platform-tools'),
    ]
    for source, target in parts:
        if not target.exists():
            assert target.resolve().is_relative_to(DEPS.resolve())
            shutil.copytree(source, target)
    jdk = next((DEPS / 'jdk17').glob('jdk-*'))
    settings = ENGINE.parent / 'editor_data/editor_settings-4.7.tres'
    backup = WORK / 'editor_settings.before_android.tres'
    if not backup.exists():
        shutil.copy2(settings, backup)
    text = settings.read_text('utf-8')
    for name, path in [('java_sdk_path', jdk), ('android_sdk_path', sdk)]:
        line = 'export/android/' + name + ' = ' + setting(path)
        text, count = re.subn(r'^export/android/' + name + r' = .*$', lambda _: line, text, flags=re.M)
        assert count == 1, name
    settings.write_text(text, encoding='utf-8')
    KEYS.mkdir(parents=True, exist_ok=True)
    password_path = KEYS / 'android_signing_password.txt'
    keystore = KEYS / 'wildfrontier.keystore'
    if not password_path.exists():
        assert not keystore.exists(), 'Preserve an existing signing identity'
        password_path.write_text(secrets.token_hex(24), encoding='utf-8')
    password = password_path.read_text('utf-8').strip()
    env = os.environ.copy()
    env['WILDFRONTIER_SIGN_PASS'] = password
    env['JAVA_HOME'] = str(jdk)
    if not keystore.exists():
        args = [str(jdk / 'bin/keytool.exe'), '-genkeypair', '-keystore', str(keystore),
                '-storetype', 'PKCS12', '-alias', 'wildfrontier', '-keyalg', 'RSA',
                '-keysize', '2048', '-validity', '10000',
                '-dname', 'CN=Wildfrontier Local Release',
                '-storepass:env', 'WILDFRONTIER_SIGN_PASS', '-keypass:env', 'WILDFRONTIER_SIGN_PASS']
        result = subprocess.run(args, env=env, capture_output=True, text=True)
        assert result.returncode == 0, 'Android key generation failed'
    env['GODOT_ANDROID_KEYSTORE_RELEASE_PATH'] = str(keystore)
    env['GODOT_ANDROID_KEYSTORE_RELEASE_USER'] = 'wildfrontier'
    env['GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD'] = password
    return env

def presets():
    common = '\n'.join([
        'runnable=false', 'advanced_options=false', 'dedicated_server=false',
        'custom_features=""', 'export_filter="all_resources"',
        'include_filter="assets/*.json,assets/**/*.json,release/*.json,release/*.pem,assets/fonts/OFL.txt,assets/licenses/*.txt"',
        'exclude_filter=""', 'export_path=""', 'patches=PackedStringArray()',
        'encrypt_pck=false', 'encrypt_directory=false', 'script_export_mode=2',
    ])
    targets = [
        ('Windows', 'Windows Desktop', [
            'custom_template/release=' + setting(TEMPLATES / 'windows_release_x86_64.exe'),
            'debug/export_console_wrapper=0', 'binary_format/architecture="x86_64"',
            'binary_format/embed_pck=false', 'application/modify_resources=true',
            'application/icon="res://release/icon.ico"',
            f'application/file_version="{VERSION}.0"', f'application/product_version="{VERSION}.0"',
            'application/product_name="原始人大作战 · 荒野交锋"',
            'application/file_description="原始人大作战 · 荒野交锋"',
        ]),
        ('Linux', 'Linux', [
            'custom_template/release=' + setting(TEMPLATES / 'linux_release.x86_64'),
            'debug/export_console_wrapper=0', 'binary_format/architecture="x86_64"',
            'binary_format/embed_pck=false',
        ]),
        ('Android', 'Android', [
            'custom_template/release=' + setting(TEMPLATES / 'android_release.apk'),
            'gradle_build/use_gradle_build=false',
            'architectures/armeabi-v7a=true', 'architectures/arm64-v8a=true',
            'architectures/x86=false', 'architectures/x86_64=false',
            f'version/code={ANDROID_VERSION_CODE}', f'version/name="{VERSION}"',
            'package/unique_name="org.cavebattle.wildfrontier"',
            'package/name="原始人大作战 · 荒野交锋"', 'package/signed=true',
            'keystore/release=' + setting(KEYS / 'wildfrontier.keystore'),
            'keystore/release_user="wildfrontier"', 'keystore/release_password=""',
            'launcher_icons/main_192x192="res://release/icon.png"',
            'launcher_icons/adaptive_foreground_432x432="res://release/icon.png"',
            'permissions/internet=true', 'screen/immersive_mode=true',
        ]),
    ]
    sections = []
    for i, (name, platform, options) in enumerate(targets):
        sections.append(f'[preset.{i}]\nname={setting(name)}\nplatform={setting(platform)}\n{common}\n\n[preset.{i}.options]\n' + '\n'.join(options))
    return '\n\n'.join(sections) + '\n'

def prepare():
    PROJECT.mkdir(parents=True, exist_ok=True)
    def _release_ignore(directory, names):
        skipped = []
        folder = Path(directory)
        for name in names:
            low = name.lower()
            if "preview" in low and low.endswith((".wav", ".mp3", ".ogg", ".avi")):
                skipped.append(name)
            if name == "ui_v08" or (folder.name == "sfx" and name == "ui_v08"):
                skipped.append(name)
        return skipped
    for folder in ("src", "assets", "release"):
        shutil.copytree(ROOT / folder, PROJECT / folder, dirs_exist_ok=True, ignore=_release_ignore)

    shutil.copy2(ROOT / 'main.tscn', PROJECT / 'main.tscn')
    update_config = json.loads((PROJECT / 'release/update_config.json').read_text('utf-8'))
    update_config['version'] = VERSION
    update_config['build'] = BUILD
    update_config['feed_url'] = FEED_URL
    (PROJECT / 'release/update_config.json').write_text(json.dumps(update_config, ensure_ascii=False, indent=2), encoding='utf-8')
    config = (ROOT / 'project.godot').read_text('utf-8')
    config = config.replace('run/main_scene="res://main.tscn"', 'run/main_scene="res://release/bootstrap.tscn"')
    config = config.replace('[application]', f'[application]\nconfig/version="{VERSION}"\nconfig/icon="res://release/icon.png"\nboot_splash/show_image=false')
    config = config.replace('[display]', '[display]\nwindow/handheld/orientation=0')
    if 'window/stretch/aspect=' not in config:
        config = config.replace('[display]', '[display]\nwindow/stretch/aspect="keep"')
    config = config.replace('[rendering]', '[rendering]\ntextures/vram_compression/import_etc2_astc=true\ntextures/vram_compression/import_s3tc_bptc=true')
    (PROJECT / 'project.godot').write_text(config, encoding='utf-8')
    shutil.copy2(ROOT / 'assets/characters/v14/caveman_portrait.png', PROJECT / 'release/icon.png')
    with Image.open(PROJECT / 'release/icon.png') as image:
        image.save(PROJECT / 'release/icon.ico', sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    (PROJECT / 'export_presets.cfg').write_text(presets(), encoding='utf-8')
    assert not any((PROJECT / name).exists() for name in ['runtime', 'tests', 'previews', 'tools'])
    print('Prepared runtime-only source copy', flush=True)

def engine_run(args, name, env):
    logs = WORK / 'logs'; logs.mkdir(exist_ok=True)
    env = env.copy(); env['APPDATA'] = str(WORK / 'export_userdata'); env['LOCALAPPDATA'] = str(WORK / 'export_userdata/local')
    temporary = WORK / 'temporary'
    temporary.mkdir(exist_ok=True)
    env['TEMP'] = env['TMP'] = str(temporary)
    path = logs / (name + '.log')
    with path.open('wb') as log:
        result = subprocess.run([str(ENGINE), '--headless', '--path', str(PROJECT), *args], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=600)
    text = path.read_text('utf-8', errors='replace')
    if result.returncode != 0 or re.search(r'ERROR:|SCRIPT ERROR|Parse Error', text):
        raise RuntimeError(f'{name} failed, exit={result.returncode}; inspect {path}')
    print(name + ': OK', flush=True)

def package(target):
    folder = OUTPUT / target
    common = f'原始人大作战 · 荒野交锋 v{VERSION}\n\n'
    if target == 'Windows':
        instructions = '将整个文件夹解压到任意位置，双击 PrimitiveWildfrontier.exe 游玩。请保留旁边的 PCK 文件。\n'
    else:
        instructions = '解压后运行 ./启动游戏.sh，或直接运行 PrimitiveWildfrontier.x86_64。\n如果解压软件没有保留执行权限，运行 chmod +x PrimitiveWildfrontier.x86_64 启动游戏.sh。\n'
    controls = '\nWASD / 方向键移动，自动攻击；Shift 闪避；Esc 暂停；B 属性；空格切换阵型；Q 联动；E 目标优先；F5 保存。\n存档保存在个人用户目录，更新游戏文件时保留存档。首次发行版无需联网。\n'
    (folder / '开始游玩.txt').write_text(common + instructions + controls, encoding='utf-8')
    (folder / 'updates.json').write_text(json.dumps({'feed_url': FEED_URL}) + '\n', encoding='utf-8')
    shutil.copy2(ROOT / 'assets/fonts/OFL.txt', folder / 'Noto字体许可.txt')
    shutil.copy2(ROOT / 'assets/licenses/Godot-third-party.txt', folder / 'Godot与第三方许可.txt')
    if target == 'Linux':
        (folder / '启动游戏.sh').write_text('#!/bin/sh\ncd -- "$(dirname -- "$0")" || exit 1\nexec ./PrimitiveWildfrontier.x86_64 "$@"\n', encoding='utf-8', newline='\n')
        artifact = OUTPUT / f'PrimitiveWildfrontier-v{VERSION}-Linux-x86_64.tar.gz'
        with tarfile.open(artifact, 'w:gz', compresslevel=6) as tar:
            for file in sorted(folder.iterdir()):
                info = tar.gettarinfo(str(file), arcname='PrimitiveWildfrontier/' + file.name)
                info.mode = 0o755 if file.suffix in ('.x86_64', '.sh') else 0o644
                with file.open('rb') as data: tar.addfile(info, data)
    else:
        artifact = OUTPUT / f'PrimitiveWildfrontier-v{VERSION}-Windows-x64.zip'
        with zipfile.ZipFile(artifact, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zip:
            for file in sorted(folder.iterdir()): zip.write(file, 'PrimitiveWildfrontier/' + file.name)
    print('Packaged:', artifact.name, artifact.stat().st_size, flush=True)
    return artifact

def main():
    global FEED_URL
    parser = argparse.ArgumentParser(); parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--feed-url', default='', help='Optional real HTTPS manifest URL; empty keeps offline mode')
    parser.add_argument('--version', default=VERSION)
    parser.add_argument('--build', type=int, default=BUILD)
    parser.add_argument('--android-version-code', type=int, default=ANDROID_VERSION_CODE)
    parser.add_argument('--targets', nargs='+', default=['Windows', 'Linux', 'Android'], choices=['Windows', 'Linux', 'Android'])
    options = parser.parse_args()
    configure_release(options.version, options.build, options.android_version_code)
    WORK.mkdir(parents=True, exist_ok=True)
    FEED_URL = options.feed_url
    if FEED_URL:
        from urllib.parse import urlsplit
        feed = urlsplit(FEED_URL)
        assert feed.scheme == 'https' and feed.hostname and not feed.username and not feed.password, 'A real HTTPS manifest URL is required'
    env = sdk_setup(); prepare()
    if options.prepare_only: return
    OUTPUT.mkdir(parents=True, exist_ok=True)
    engine_run(['--import'], 'import', env)
    artifacts = []
    for target in options.targets:
        folder = OUTPUT / target; folder.mkdir(exist_ok=True)
        binary = folder / ('PrimitiveWildfrontier.exe' if target == 'Windows' else ('PrimitiveWildfrontier.x86_64' if target == 'Linux' else f'PrimitiveWildfrontier-v{VERSION}-Android.apk'))
        engine_run(['--export-release', target, str(binary)], 'export_' + target, env)
        assert binary.is_file() and binary.stat().st_size > 1000000
        if target == 'Android':
            artifact = OUTPUT / binary.name; shutil.copy2(binary, artifact)
        else:
            artifact = package(target)
        artifacts.append({'platform': target, 'file': artifact.name, 'bytes': artifact.stat().st_size, 'sha256': digest(artifact)})
    report = {'version': VERSION, 'build': BUILD, 'engine': '4.7.2', 'source_project': str(ROOT),
              'output': str(OUTPUT), 'artifacts': artifacts, 'network_updates_enabled': bool(FEED_URL),
              'source_sha256': {file.relative_to(ROOT).as_posix(): digest(file) for folder in ('src', 'release') for file in (ROOT / folder).rglob('*') if file.is_file()}}
    (OUTPUT / 'build_manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Release files ready; runtime verification is still required.', flush=True)

if __name__ == '__main__': main()
