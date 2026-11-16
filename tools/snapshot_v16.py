from pathlib import Path
from datetime import datetime
import hashlib, json, shutil

root=Path(__file__).resolve().parents[1]
assert not (root/'docs/v16_baseline.json').exists(), 'Keep existing v16 baseline'
report=json.loads((root/'docs/v15_verification.json').read_text('utf-8'))
changed=[p for p,s in report['source_sha256'].items() if hashlib.sha256((root/p).read_bytes()).hexdigest()!=s]
assert not changed, changed
snapshot=root.parent/'原始人大作战_快照'/datetime.now().strftime('v16_before_%Y%m%d_%H%M%S')
snapshot.mkdir(parents=True)
files=[]
for folder in ['src','assets','tests','docs']:
    files.extend(p for p in (root/folder).rglob('*') if p.is_file())
files.extend(p for p in (root/'tools').iterdir() if p.is_file())
files.extend(p for p in root.iterdir() if p.is_file())
files.extend(p for p in (root/'runtime/Godot/app_userdata').rglob('*.json') if 'saves' in p.parts)
manifest={}
for path in files:
    rel=path.relative_to(root);target=snapshot/rel;target.parent.mkdir(parents=True,exist_ok=True)
    data=path.read_bytes();target.write_bytes(data)
    manifest[rel.as_posix()]={'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
(snapshot/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(root/'docs/v16_baseline.json').write_text(json.dumps({'snapshot':str(snapshot),'source_changes_since_v15':changed},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'snapshot':str(snapshot),'files':len(files),'source_changes_since_v15':changed},ensure_ascii=True))
