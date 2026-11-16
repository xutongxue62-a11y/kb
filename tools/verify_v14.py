from pathlib import Path
from datetime import datetime
import hashlib,json,re

root=Path(__file__).resolve().parents[1]
baseline=Path(json.loads((root/'docs/v14_baseline.json').read_text('utf-8'))['snapshot'])
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
runner=(root/'tools/run_tests.ps1').read_text('utf-8-sig')
names=re.findall(r"'([a-z0-9_]+)'",runner.split('foreach ($testName in @(')[1].split('))')[0])
groups=[]
for name in names:
    path=root/'logs'/('v06_'+name+'.log');log=path.read_text('utf-8-sig')
    result=re.search(r'RESULT: (\d+) checks, (\d+) failures',log)
    assert result and int(result[2])==0 and not re.search(r'ERROR:|SCRIPT ERROR|FAIL:',log),name
    groups.append({'group':name,'checks':int(result[1]),'failures':0,'sha256':sha(path)})
native=json.loads((root/'previews/v14_native_v2/timeline.json').read_text('utf-8'))
assert native['failures']==0 and len(native['screenshots'])==15
log=(root/'logs/v14_native_v2.log').read_text('utf-8-sig')
assert not re.search(r'ERROR:|SCRIPT ERROR|FAIL:|WARNING:',log)
old_assets=[p for p in (baseline/'assets').rglob('*') if p.is_file()]
assert all(sha(p)==sha(root/p.relative_to(baseline)) for p in old_assets),'An earlier asset changed'
protected=['rules.gd','dino_view.gd','world_map.gd','music_controller.gd','audio_pool.gd','effects.gd','loot_rules.gd','loot_drops.gd','session_state.gd','ui_frontend.gd','ui_transition.gd','ui_button_fx.gd']
assert all(sha(baseline/'src'/p)==sha(root/'src'/p) for p in protected),'Unrelated source changed'
latest=baseline.parent/datetime.now().strftime('v14_latest_player_%Y%m%d_%H%M%S')
latest.mkdir()
player=[]
for p in (root/'runtime/Godot/app_userdata').rglob('*.json'):
    if 'saves' not in p.parts: continue
    data=p.read_bytes();rel=p.relative_to(root);target=latest/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    digest=hashlib.sha256(data).hexdigest()
    player.append({'path':str(rel),'sha256':digest,'backup':str(target),'same_as_initial':(baseline/rel).exists() and sha(baseline/rel)==digest})
    assert sha(target)==digest
report={'verified_at':datetime.now().astimezone().isoformat(),'baseline':str(baseline),'groups':groups,'checks':sum(g['checks'] for g in groups),'native':native,'old_asset_files_unchanged':len(old_assets),'protected_source_files':protected,'latest_player_files':player,'source_sha256':{str(p.relative_to(root)):sha(p) for p in (root/'src').glob('*.gd')},'review':{'remaining_p1_p2':0,'fixed':['conductive lightning requires actual damage','per-weapon attached upgrade ornaments']},'user_acceptance_verified':False,'subjective_listening_verified':False}
(root/'docs/v14_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(latest/'manifest.json').write_text(json.dumps(player,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'groups':len(groups),'checks':report['checks'],'native_checks':native['checks'],'old_assets_unchanged':len(old_assets),'protected_source':len(protected),'latest_player_files':len(player),'player_unchanged_during_tests':all(p['same_as_initial'] for p in player)},ensure_ascii=True))
