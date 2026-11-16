"""Release metadata must agree across actual prepared projects and archives."""
from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import patch
import zipfile
from PIL import Image
import build_release as build


class ReleaseVersionTests(unittest.TestCase):
    def test_new_version_preserves_shared_dependencies_and_identity(self):
        shared_deps, keys = build.DEPS, build.KEYS
        with patch.multiple(build, WORK=build.WORK, PROJECT=build.PROJECT,
                            OUTPUT=build.OUTPUT, VERSION=build.VERSION,
                            BUILD=build.BUILD, ANDROID_VERSION_CODE=build.ANDROID_VERSION_CODE):
            build.configure_release('0.24.0', 2026111602, 24)
            self.assertEqual(build.WORK.name, 'v0.24.0')
            self.assertEqual(build.OUTPUT.name, 'v0.24.0')
            self.assertEqual(build.DEPS, shared_deps)
            self.assertEqual(build.KEYS, keys)
            presets = build.presets()
            self.assertIn('version/code=24', presets)
            self.assertIn('version/name="0.24.0"', presets)
            self.assertIn('application/product_version="0.24.0.0"', presets)

    def test_prepared_project_and_download_names_match_the_selected_version(self):
        sandbox = build.ROOT / 'runtime/release_build_tests'
        sandbox.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='version_', dir=sandbox) as folder:
            self.assertTrue(Path(folder).resolve().is_relative_to(sandbox.resolve()))
            base = Path(folder)
            source = base / 'source'
            for name in ('src', 'assets/characters/v14', 'assets/fonts', 'assets/licenses', 'release'):
                (source / name).mkdir(parents=True, exist_ok=True)
            (source / 'src/main.gd').write_text('extends Node\n', encoding='utf-8')
            (source / 'main.tscn').write_text('[gd_scene format=3]\n', encoding='utf-8')
            (source / 'project.godot').write_text('config_version=5\n[application]\nrun/main_scene="res://main.tscn"\n[display]\nwindow/stretch/aspect="keep"\n[rendering]\n', encoding='utf-8')
            original = {'version': '0.23.0', 'build': 2026111601, 'feed_url': ''}
            (source / 'release/update_config.json').write_text(json.dumps(original), encoding='utf-8')
            for name in ('assets/fonts/OFL.txt', 'assets/licenses/Godot-third-party.txt'):
                (source / name).write_text('Fixture license', encoding='utf-8')
            Image.new('RGBA', (256, 256), (100, 100, 100, 255)).save(source / 'assets/characters/v14/caveman_portrait.png')
            stage, output = base / 'prepared', base / 'output'
            with patch.multiple(build, ROOT=source, PROJECT=stage, OUTPUT=output,
                                VERSION='0.24.0', BUILD=2026111602, ANDROID_VERSION_CODE=24):
                build.prepare()
                config = json.loads((stage / 'release/update_config.json').read_text('utf-8'))
                self.assertEqual((config['version'], config['build']), ('0.24.0', 2026111602))
                self.assertEqual(json.loads((source / 'release/update_config.json').read_text('utf-8')), original)
                project = (stage / 'project.godot').read_text('utf-8')
                self.assertIn('config/version="0.24.0"', project)
                self.assertEqual(project.count('window/stretch/aspect='), 1)
                target = output / 'Windows'
                target.mkdir(parents=True)
                (target / 'PrimitiveWildfrontier.exe').write_bytes(b'fixture executable')
                (target / 'PrimitiveWildfrontier.pck').write_bytes(b'fixture content')
                archive_path = build.package('Windows')
                self.assertEqual(archive_path.name, 'PrimitiveWildfrontier-v0.24.0-Windows-x64.zip')
                with zipfile.ZipFile(archive_path) as archive:
                    guide = archive.read('PrimitiveWildfrontier/开始游玩.txt').decode('utf-8')
                    self.assertIn('v0.24.0', guide)
                    self.assertEqual(len(archive.namelist()), 6)


if __name__ == '__main__':
    unittest.main()
