"""Check the art/performance release, then back up current real saves without restoring them."""
from pathlib import Path
from datetime import datetime
import hashlib, json, re

root=Path(__file__).resolve().parents[1]
baseline=Path(json.loads((root/'docs/v16_baseline.json').read_text('utf-8'))['snapshot'])
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
runner=(root/'tools/run_tests.ps1').read_text('utf-8-sig')
names=re.findall(r"'([a-z0-9_]+)'",runner.split('foreach ($testName in @(')[1].split('))')[0])
assert len(names)==42 and len(set(names))==42
groups=[]
for name in names:
    path=root/'logs'/('v06_'+name+'.log');log=path.read_text('utf-8-sig')
    result=re.search(r'RESULT: (\d+) checks, (\d+) failures',log)
    assert result and int(result[2])==0 and not re.search(r'ERROR:|SCRIPT ERROR|FAIL:',log),name
    groups.append({'group':name,'checks':int(result[1]),'failures':0,'sha256':sha(path)})
stem='v16_native_v4'
folder=root/'previews'/stem
native=json.loads((folder/'timeline.json').read_text('utf-8'))
assert native['checks']==14 and native['failures']==0 and len(native['screenshots'])==6
assert native['real_player_storage_used'] is False
for suffix in ('.log','_console.log'):
    assert not re.search(r'ERROR:|SCRIPT ERROR|FAIL:|WARNING:',(root/'logs'/(stem+suffix)).read_text('utf-8-sig')),suffix
mm_log=(root/'logs/v16_pickup_renderer_native_console.log').read_text('utf-8-sig')
assert '6 checks, 0 failures' in mm_log and not re.search(r'ERROR:|SCRIPT ERROR|FAIL:|WARNING:',mm_log)
images=[folder/(shot['name']+'.png') for shot in native['screenshots']]
images += [folder/(name+'.png') for name in ('effect_families','support_motion_phases','monster_materials_before_after','weapon_growth_sheet')]
assert all(p.is_file() and p.stat().st_size>1000 for p in images)
movie=root/'previews'/(stem+'.mp4')
video=json.loads((root/'previews'/(stem+'_metadata.json')).read_text('utf-8'))
assert movie.is_file() and video['frames']>=590 and video['fps']=='60/1'
assert abs(video['seconds']-video['audio_seconds'])<.04
before=json.loads((root/'previews/v16_benchmark_before/performance.json').read_text('utf-8'))
after=json.loads((root/'previews/v16_benchmark_final/performance.json').read_text('utf-8'))
for data in (before,after):
    assert data['seed']==160016 and data['frames']==180 and data['enemies']==42
    assert data['pickups']>=1500 and data['coins']==0 and data['xp']==0 and data['isolated_player_storage']
assert after['simulation_ms']['median']<before['simulation_ms']['median']
assert after['native_frame_ms']['median']<before['native_frame_ms']['median']
performance={'before':before,'after':after,'simulation_median_reduction_pct':100*(1-after['simulation_ms']['median']/before['simulation_ms']['median']),
             'native_frame_median_reduction_pct':100*(1-after['native_frame_ms']['median']/before['native_frame_ms']['median']),
             'limits':'Local same initial fixture and seed. Support motion intentionally changed; frame timings include OS scheduling. No promise for other hardware or all future scenes.'}
assets=[p for p in (baseline/'assets').rglob('*') if p.is_file()]
assert all(sha(p)==sha(root/p.relative_to(baseline)) for p in assets),'An earlier asset changed'
allowed={'src/main.gd','src/effects.gd','src/expanded_weapons.gd','src/weapon_art.gd','src/companions.gd','src/support_art.gd','src/enemy_art.gd','src/dino_view.gd','src/world_map.gd'}
old_files=[p for p in (baseline/'src').rglob('*') if p.is_file()]
changed={p.relative_to(baseline).as_posix() for p in old_files if sha(p)!=sha(root/p.relative_to(baseline))}
assert changed==allowed,changed
protected=[p.relative_to(baseline).as_posix() for p in old_files if p.relative_to(baseline).as_posix() not in allowed]
latest=baseline.parent/datetime.now().strftime('v16_latest_player_%Y%m%d_%H%M%S')
latest.mkdir()
player=[]
for path in (root/'runtime/Godot/app_userdata').rglob('*.json'):
    if 'saves' not in path.parts: continue
    data=path.read_bytes();rel=path.relative_to(root);target=latest/rel
    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    digest=hashlib.sha256(data).hexdigest();assert sha(target)==digest
    player.append({'path':str(rel),'sha256':digest,'backup':str(target),'same_as_initial':(baseline/rel).is_file() and sha(baseline/rel)==digest})
assert len(player)>=4
report={'verified_at':datetime.now().astimezone().isoformat(),'baseline':str(baseline),'groups':groups,'checks':sum(g['checks'] for g in groups),
        'native':native,'native_multimesh_checks':6,'native_multimesh_log_sha256':sha(root/'logs/v16_pickup_renderer_native_console.log'),
        'video':video,'preview_sha256':{p.name:sha(p) for p in images+[movie]},'performance':performance,
        'old_asset_files_unchanged':len(assets),'changed_source_files':sorted(changed),'protected_source_files':protected,
        'new_source_files':['src/combat_art.gd','src/support_rig.gd','src/pickup_renderer.gd'],
        'source_sha256':{p.relative_to(root).as_posix():sha(p) for p in (root/'src').rglob('*.gd')},'latest_player_files':player,
        'review':{'remaining_p1_p2':0,'fixed':['support contact point at leash boundary','max-speed follower regroup and actual drone range','embedded two-stone recovery uses legacy full neighbourhood']},
        'visual_checks':['14 distinct cached effect families','14 weapons at level 1/3/5','8 monster surface comparisons','articulated ground feet and flying wings','native melee/ranged/fire-drum combat'],
        'test_storage_isolated':True,'user_acceptance_verified':False,'subjective_listening_verified':False}
assert report['checks']>=7000
(root/'docs/v16_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(latest/'manifest.json').write_text(json.dumps(player,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'groups':len(groups),'checks':report['checks'],'native_checks':native['checks'],'native_multimesh_checks':6,'old_assets_unchanged':len(assets),'protected_source':len(protected),'player_files':len(player),'player_unchanged':all(p['same_as_initial'] for p in player),'simulation_ms_before':before['simulation_ms'],'simulation_ms_after':after['simulation_ms'],'frame_ms_before':before['native_frame_ms'],'frame_ms_after':after['native_frame_ms']},ensure_ascii=True))
