from pathlib import Path
from datetime import datetime
import hashlib,json,re,sys,wave
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root.parents[1]/'.audio-tools'))
import numpy as np
import av
from PIL import Image

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
info=json.loads((root/'docs/ui_v22_baseline.json').read_text('utf-8'))
baseline=Path(info['snapshot'])
runner=(root/'tools/run_tests.ps1').read_text('utf-8-sig')
names=re.findall(r"'([a-z0-9_]+)'",runner.split('foreach ($testName in @(')[1].split('))')[0])
assert len(names)==44 and len(set(names))==44
groups=[]
for name in names:
    path=root/'logs'/('v06_'+name+'.log');log=path.read_text('utf-8-sig')
    match=re.search(r'RESULT: (\d+) checks, (\d+) failures',log)
    assert match and int(match[2])==0 and not re.search(r'ERROR:|SCRIPT ERROR|FAIL:',log),name
    groups.append({'group':name,'checks':int(match[1]),'sha256':sha(path)})
stem='ui_v22_final3';folder=root/'previews'/stem
native=json.loads((folder/'timeline.json').read_text('utf-8'))
assert native['checks']==11 and native['failures']==0 and len(native['screenshots'])==9 and not native['real_player_storage_used']
for suffix in ('.log','_console.log'):
    assert not re.search(r'ERROR:|SCRIPT ERROR|FAIL:|WARNING:',(root/'logs'/('ui_v22_native_final3'+suffix)).read_text('utf-8-sig'))
markers={m['name']:m for m in native['screenshots']}

def patch(name,u):
    m=markers[name];x=m['button_position'][0]+m['button_size'][0]*u;y=m['button_position'][1]+m['button_size'][1]*.82
    with Image.open(folder/(name+'.png')) as image:
        return np.asarray(image.convert('RGB').crop((round(x)-2,round(y)-2,round(x)+3,round(y)+3)),dtype=float).mean(axis=(0,1))

pixel=[]
for stage,expected in [('enter_brush_early',[True,False,False]),('enter_brush_mid',[True,True,False]),('enter_brush_complete',[True,True,True])]:
    observed=[]
    for u in [.10,.30,.85]:
        rest=patch('home_rest',u);full=patch('enter_brush_complete',u);value=patch(stage,u)
        observed.append(bool(np.linalg.norm(value-full)<np.linalg.norm(value-rest)))
    assert observed==expected,(stage,observed,markers[stage].get('brush_progress'))
    pixel.append({'stage':stage,'progress':markers[stage]['brush_progress'],'u':[.10,.30,.85],'washed':observed})

# Correlate the recorded hover portions with the existing short WAV at its new pitch.
audio=[]
with av.open(str(root/'previews'/(stem+'.avi'))) as clip:
    rate=clip.streams.audio[0].rate
    for frame in clip.decode(audio=0):
        data=frame.to_ndarray().astype(float)
        if frame.format.is_planar: mono=data.mean(axis=0)
        else: mono=data.reshape(-1,len(frame.layout.channels)).mean(axis=1)
        audio.append(mono/32768.0)
recorded=np.concatenate(audio)
with wave.open(str(root/'assets/sfx/ui_v09/button_press.wav'),'rb') as source:
    source_rate=source.getframerate();samples=np.frombuffer(source.readframes(source.getnframes()),dtype='<i2').astype(float)/32768.0
pitch=1.35
template=np.interp(np.arange(int(len(samples)*rate/source_rate/pitch))*source_rate*pitch/rate,np.arange(len(samples)),samples)
template-=template.mean()
correlations=[]
for name,delay in [('enter_brush_early',2),('ContinueSave_brush',5),('HelpGameplay_brush',5)]:
    center=markers[name]['frame']-delay
    lo=max(0,int((center-3)/60*rate));hi=min(len(recorded),int((center+8)/60*rate))
    segment=recorded[lo:hi]
    numerator=np.correlate(segment,template,mode='valid')
    energy=np.convolve(segment*segment,np.ones(len(template)),mode='valid')
    scores=numerator/np.sqrt(np.maximum(energy*float(template@template),1e-15))
    score=float(scores.max())
    assert score>.65,(name,score)
    correlations.append({'button':name,'recorded_template_correlation':score})

assets=[p for p in (baseline/'assets').rglob('*') if p.is_file()]
assert all(sha(p)==sha(root/p.relative_to(baseline)) for p in assets),'An old asset changed'
allowed={'src/main.gd','src/hud.gd','src/ui_frontend.gd','src/ui_audio.gd','src/ui_home_action.gd','src/ui_ink_button_fx.gd','src/ui_paper.gd'}
old_sources=[p for p in (baseline/'src').rglob('*') if p.is_file()]
changed={p.relative_to(baseline).as_posix() for p in old_sources if sha(p)!=sha(root/p.relative_to(baseline))}
assert changed==allowed,changed
protected=[p.relative_to(baseline).as_posix() for p in old_sources if p.relative_to(baseline).as_posix() not in allowed]
assert (baseline/'src/main.gd').read_text('utf-8').replace('荒野交锋 v0.16','荒野交锋 v0.22')==(root/'src/main.gd').read_text('utf-8')
hud=(root/'src/hud.gd').read_text('utf-8')
binding=re.search(r'(?ms)^func bind_hover_audio\(.*?(?=^func play_ui\()',hud)[0]
expected=(baseline/'src/hud.gd').read_text('utf-8').replace('    button.set_meta("ui_armed", true)\n','    button.set_meta("ui_armed", true)\n    bind_hover_audio(button)\n',1).replace('func play_ui(key: String) -> void:',binding+'func play_ui(key: String) -> void:',1)
assert expected==hud,'Unrelated HUD changes'
latest=baseline.parent/datetime.now().strftime('ui_v22_latest_player_%Y%m%d_%H%M%S');latest.mkdir()
player=[]
for path in (root/'runtime/Godot/app_userdata').rglob('*.json'):
    if 'saves' not in path.parts: continue
    data=path.read_bytes();rel=path.relative_to(root);dest=latest/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
    digest=hashlib.sha256(data).hexdigest();assert sha(dest)==digest
    player.append({'path':str(rel),'backup':str(dest),'sha256':digest,'same_as_baseline':(baseline/rel).exists() and sha(baseline/rel)==digest})
assert len(player)>=4
video=json.loads((root/'previews'/(stem+'_metadata.json')).read_text('utf-8'))
assert video['fps']=='60/1' and video['frames']>=260 and abs(video['seconds']-video['audio_seconds'])<.04
report={'verified_at':datetime.now().astimezone().isoformat(),'baseline':str(baseline),'preserved_user_changes_since_v16':info['user_source_changes_since_v16'],
        'groups':groups,'checks':sum(g['checks'] for g in groups),'native':native,'native_pixel_direction':pixel,'recorded_hover_audio':correlations,'video':video,
        'old_assets_unchanged':len(assets),'protected_source_files':protected,'changed_source_files':sorted(changed),'main_scope':'window title only','hud_scope':'hover binding only',
        'source_sha256':{p.relative_to(root).as_posix():sha(p) for p in (root/'src').rglob('*.gd')},'latest_player_files':player,
        'review':{'remaining_p1_p2':0,'fixed':'deferred paper skin resets and synchronizes hover text before brush arrival'},
        'user_acceptance_verified':False,'manual_listening_verified':False}
(root/'docs/ui_v22_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(latest/'manifest.json').write_text(json.dumps(player,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'groups':len(groups),'checks':report['checks'],'native_checks':native['checks'],'pixel_direction':pixel,'hover_audio':correlations,'old_assets_unchanged':len(assets),'protected_sources':len(protected),'player_files':len(player),'player_unchanged':all(p['same_as_baseline'] for p in player)},ensure_ascii=True))
