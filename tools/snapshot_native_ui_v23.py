from pathlib import Path
from datetime import datetime
import hashlib
import json
import shutil
import sys
import re

root = Path(__file__).resolve().parents[1]
version = sys.argv[1] if len(sys.argv) > 1 else 'v23'
assert re.fullmatch(r'v[0-9]+', version), 'Expected a version like v24'
baseline = root / ('docs/native_ui_' + version + '_baseline.json')
assert not baseline.exists(), 'Do not replace an existing baseline'
stamp = datetime.now().strftime('%Y%m%d_%H%M%S')
target = root.parent / '原始人大作战_快照' / ('native_ui_' + version + '_before_' + stamp)
target.mkdir(parents=True, exist_ok=False)
files = []
for directory in ('src', 'assets', 'tests', 'docs'):
    files.extend(p for p in (root / directory).rglob('*') if p.is_file())
files.extend(p for p in (root / 'tools').iterdir() if p.is_file())
files.extend(p for p in root.iterdir() if p.is_file())
files.extend(p for p in (root / 'runtime/Godot/app_userdata').rglob('*.json') if 'saves' in p.parts)
manifest = {}
for path in files:
    rel = path.relative_to(root)
    dest = target / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, dest)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    assert hashlib.sha256(dest.read_bytes()).hexdigest() == digest, str(rel)
    manifest[rel.as_posix()] = {'sha256': digest, 'bytes': path.stat().st_size}
old = json.loads((root / 'docs/ui_v22_verification.json').read_text('utf-8'))
changed = [rel for rel, digest in old['source_sha256'].items()
           if manifest[rel]['sha256'] != digest]
report = {'snapshot': str(target), 'files': manifest,
          'source_changes_since_last_v22_verification': changed}
(target / 'manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
baseline.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'snapshot': str(target), 'files': len(files),
                  'player_saves': sum('saves/' in rel for rel in manifest),
                  'source_changes_since_last_v22_verification': changed}, ensure_ascii=False))
