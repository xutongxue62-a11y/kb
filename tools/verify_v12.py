"""Record final v12 evidence; keep the latest player data, never restore baseline."""
from pathlib import Path
import hashlib
import json
import re
from datetime import datetime

root=Path(__file__).resolve().parents[1]
baseline=json.loads((root/'docs/v12_baseline.json').read_text(encoding='utf-8-sig'))
manifest=json.loads((Path(baseline['snapshot'])/'manifest.json').read_text(encoding='utf-8-sig'))
groups='rules scene controls attack_links growth feedback impact progression armory save_store hud_navigation campaign frontend ui_motion ui_audio home_v09 chest_pickup sprite_edges dodge music world_camera battle_ui_v10 map_chunks terrain_physics growth_v11 supports_v11 ui_v11 resources_v12 rounds_v12 weapons_v12 enemies_v12 battle_visuals_v12'.split()
report={'version':'0.12','recorded_at':datetime.now().astimezone().isoformat(),'baseline':baseline['snapshot'],'groups':[]}
for name in groups:
    path=root/'logs'/('v06_'+name+'.log')
    log=path.read_text(encoding='utf-8-sig')
    result=re.search(r'RESULT: (\d+) checks, (\d+) failures',log)
    assert result and int(result[2])==0 and not re.search(r'ERROR:|SCRIPT ERROR|FAIL:',log),name
    report['groups'].append({'group':name,'checks':int(result[1]),'failures':0,'log':str(path.relative_to(root))})
report['total_checks']=sum(item['checks'] for item in report['groups'])
report['native']=json.loads((root/'previews/v12_native_v2/timeline.json').read_text(encoding='utf-8'))
log=(root/'logs/v12_native_v2.log').read_text(encoding='utf-8')
assert report['native']['failures']==0 and not re.search(r'ERROR:|SCRIPT ERROR|WARNING:|FAIL:',log)
report['native']['clean_log']=True
report['media']=json.loads((root/'previews/v12_native_v2_metadata.json').read_text(encoding='utf-8'))
report['listening_verified']=False
report['player_acceptance_verified']=False
report['preservation']={'assets':[],'ui_source':[],'latest_player_data':[]}
save_backup=Path(baseline['snapshot']).parent/datetime.now().strftime('%Y%m%d_latest_player_before_v12_%H%M%S')
save_backup.mkdir()
for relative,old in manifest.items():
    current=root/relative
    if relative.startswith('assets\\') or (relative.startswith('src\\') and current.suffix=='.gd' and (current.name=='hud.gd' or current.name.startswith('ui_'))):
        data=current.read_bytes()
        digest=hashlib.sha256(data).hexdigest()
        assert digest==old['sha256'],'Preservation mismatch: '+relative
        group='assets' if relative.startswith('assets\\') else 'ui_source'
        report['preservation'][group].append({'file':relative,'sha256':digest})
    elif relative.startswith('runtime\\'):
        data=current.read_bytes()
        digest=hashlib.sha256(data).hexdigest()
        destination=save_backup/current.name
        destination.write_bytes(data)
        assert hashlib.sha256(destination.read_bytes()).hexdigest()==digest
        report['preservation']['latest_player_data'].append({'file':relative,'sha256':digest,'same_as_initial_baseline':digest==old['sha256'],'backup':str(destination)})
report['preservation']['latest_player_backup']=str(save_backup)
report['preservation']['player_note']='The normal v11 game remained open and player progress changed during development. Latest files were backed up verbatim, never replaced with the earlier baseline.'
(save_backup/'manifest.json').write_text(json.dumps(report['preservation']['latest_player_data'],ensure_ascii=False,indent=2),encoding='utf-8')
report['source_sha256']={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted((root/'src').glob('*.gd'))}
report['review']={'independent_read_only':True,'fixed_p2':['protect normal save before trial terrain reset','settle pending chain recipe on round reset'],'additional_fixed_edge':'bonebow selects within actual mount range','final_incremental_p1_p2':0}
(root/'docs/v12_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'groups':len(groups),'checks':report['total_checks'],'native_checks':report['native']['checks'],'assets_unchanged':len(report['preservation']['assets']),'ui_scripts_unchanged':len(report['preservation']['ui_source']),'latest_player_files_backed_up':len(report['preservation']['latest_player_data']),'backup':str(save_backup)},ensure_ascii=True))
