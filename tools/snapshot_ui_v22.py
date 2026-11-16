from pathlib import Path
from datetime import datetime
import hashlib,json
root=Path(__file__).resolve().parents[1]
assert not (root/'docs/ui_v22_baseline.json').exists(),'Preserve the existing baseline'
old=json.loads((root/'docs/v16_verification.json').read_text('utf-8'))
changed=[p for p,s in old['source_sha256'].items() if hashlib.sha256((root/p).read_bytes()).hexdigest()!=s]
target=root.parent/'原始人大作战_快照'/datetime.now().strftime('ui_v22_before_%Y%m%d_%H%M%S')
target.mkdir(parents=True)
files=[]
for directory in ('src','assets','tests','docs'):
    files.extend(p for p in (root/directory).rglob('*') if p.is_file())
files.extend(p for p in (root/'tools').iterdir() if p.is_file())
files.extend(p for p in root.iterdir() if p.is_file())
files.extend(p for p in (root/'runtime/Godot/app_userdata').rglob('*.json') if 'saves' in p.parts)
manifest={}
for path in files:
    rel=path.relative_to(root);dest=target/rel;dest.parent.mkdir(parents=True,exist_ok=True)
    data=path.read_bytes();dest.write_bytes(data)
    manifest[rel.as_posix()]={'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
(target/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(root/'docs/ui_v22_baseline.json').write_text(json.dumps({'snapshot':str(target),'user_source_changes_since_v16':changed},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'snapshot':str(target),'files':len(files),'preserved_latest_user_sources':changed},ensure_ascii=True))
