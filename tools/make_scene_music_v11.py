"""Four original scene scores. Analytic instruments, authored motifs; no samples.
Circular accumulation wraps release tails/room reflections across loop boundaries.
"""
from pathlib import Path
import hashlib, json, math, wave
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/music/v11'
RATE = 44100
SCORES = {
 'title': dict(title='Embers and Footprints', bpm=72, meter='4/4', beats=32,
   chords=[(48,[60,64,67,69]),(43,[59,62,67,69]),(45,[60,64,69,72]),(41,[60,65,69,72])],
   motif=[(0.5,72,1),(2,76,.7),(3,79,.7),(4.5,81,1.3),(6.5,79,.7),(8.5,76,1),(10,74,1.4),(12.5,72,1.1),(14,69,1.3),
          (16.5,72,.8),(18,76,.7),(19,79,.8),(20.5,84,1.4),(22.5,81,.6),(24.5,79,1),(26,76,1),(28,74,1),(30,72,1.4)],
   lead='flute', description='Warm C major campfire flute call/response over spaced wooden plucks and a gentle two-step drum'),
 'battle': dict(title='Hunters on the Trail', bpm=80, meter='4/4', beats=32,
   chords=[(38,[62,65,69,72]),(46,[62,65,70,74]),(41,[60,65,69,72]),(36,[60,64,67,70])],
   motif=[(0,74,.4),(.75,77,.4),(1.5,81,.6),(2.5,77,.4),(3.25,74,.4),(4,72,.6),(5,74,.4),(5.75,77,.4),(6.5,79,.7),
          (8,81,.7),(9,84,.4),(9.75,81,.4),(10.5,77,.7),(12,79,.5),(13,77,.5),(14,74,1.2),
          (16,74,.4),(16.75,77,.4),(17.5,81,.6),(18.5,84,.4),(19.25,81,.4),(20,79,.6),(21,77,.4),(21.75,74,.4),(22.5,72,.7),
          (24,74,.7),(25,77,.4),(25.75,79,.4),(26.5,81,.7),(28,77,.5),(29,76,.5),(30,74,1.2)],
   lead='marimba',description='D dorian syncopated mallet melody, alternating bass fifths, interlocking hand drums and short flute answers'),
 'grove': dict(title='Leaves Above the River', bpm=54, meter='3/4', beats=24,
   chords=[(52,[64,67,71,74]),(48,[64,67,72,76]),(43,[62,67,71,74]),(50,[62,66,69,74])],
   motif=[(.25,83,1.2),(2,79,.7),(3.5,78,1.1),(5,76,.6),(6.5,79,1.3),(8.2,83,.5),(9.5,86,1.2),(11,83,.7),
          (12.5,81,1.2),(14,79,.6),(15.5,78,1.2),(17,74,.6),(18.5,76,1.5),(20.5,79,.8),(22,76,1.4)],
   lead='flute',description='Airy E minor woodland waltz, high breathy flute, rippling thumb piano, soft sustained strings; sparse percussion'),
 'volcano': dict(title='Under the Ember Mountain', bpm=76, meter='4/4', beats=32,
   chords=[(33,[57,60,64,71]),(41,[56,60,65,69]),(38,[57,62,65,69]),(40,[56,59,64,68])],
   motif=[(0,69,1.3),(2,72,.6),(3,71,.6),(4.5,68,1),(6,64,1.4),(8,65,.7),(9.5,69,.7),(11,72,.7),(12,71,1.5),(14,68,1.3),
          (16,69,.7),(17.5,72,.6),(18.5,76,1),(20,77,1),(21.5,76,.7),(23,72,.6),(24,74,1),(25.5,72,.6),(27,71,.6),(28,68,1),(30,69,1.4)],
   lead='reed',description='A harmonic minor low reed melody, 3+3+2 ritual drum accents, low bowed pedal and stone mallet ostinato')}

def hz(m): return 440 * 2 ** ((m - 69) / 12)

def render(key, score):
 beat=60/score['bpm']; frames=round(score['beats']*beat*RATE)
 mix=np.zeros((frames,2),np.float64); events=[]
 def add(sound, at, amp, pan=0, room=False):
  gain=np.array([math.cos((pan+1)*math.pi/4),math.sin((pan+1)*math.pi/4)])
  stereo=sound[:,None]*gain*amp; indexes=np.arange(len(sound))+round(at*beat*RATE)
  np.add.at(mix,indexes%frames,stereo)
  if room:
   for delay,g in [(.19,.12),(.37,.075),(.61,.04)]:
    np.add.at(mix,(indexes+round(delay*RATE))%frames,stereo[:,::-1]*g)
 def voice(kind,midi,length,at,amp,pan=0):
  duration=length*beat; t=np.arange(round((duration+.5)*RATE))/RATE; f=hz(midi)
  attack=1-np.exp(-t/(.055 if kind in ['flute','reed','strings'] else .006))
  phase=2*np.pi*f*t+.025*np.sin(2*np.pi*4.6*t)
  release=np.exp(-np.maximum(t-duration,0)/.12)
  if kind=='flute':
   signal=np.sin(phase)+.19*np.sin(phase*2)+.055*np.sin(phase*3)
   env=attack*release*(.88+.12*np.sin(np.minimum(t/duration,1)*np.pi))
  elif kind=='reed':
   signal=sum(np.sin(phase*h)*a for h,a in [(1,1),(2,.27),(3,.21),(4,.08),(5,.05)])
   env=attack*release*(.92+.08*np.sin(t*2*np.pi*3))
  elif kind=='strings':
   signal=sum(np.sin(2*np.pi*f*t*(1+detune))*a for detune,a in [(-.002,.35),(0,.45),(.0025,.3)])
   signal+=.12*np.sin(phase*2); env=attack*release
  elif kind in ['marimba','thumb','stone']:
   modes={'marimba':[(1,1,2),(4,.18,9),(9,.05,16)],'thumb':[(1,1,2.6),(2,.3,5),(3,.1,8)],'stone':[(1,1,3),(2.7,.11,12),(5.4,.04,18)]}[kind]
   signal=sum(np.sin(2*np.pi*f*h*t)*a*np.exp(-t*d) for h,a,d in modes)
   env=attack*release
  else:
   signal=np.sin(phase)+.16*np.sin(phase*2);env=attack*release*np.exp(-t/.9)
  env*=np.clip((t[-1]-t)/.018,0,1)
  add(signal*env,at,amp,pan,kind!='bass')
  events.append(dict(instrument=kind,midi=midi,beat=at,length=length))
 def drum(at,high=False,gain=1):
  t=np.arange(round(.35*RATE))/RATE;f=170 if high else 82
  phase=2*np.pi*(f*t+22*.016*(1-np.exp(-t/.016)))
  sound=np.sin(phase)*np.exp(-t/.075)+.24*np.sin(2*np.pi*f*1.59*t)*np.exp(-t/.032)
  sound*=(1-np.exp(-t/.002))*np.clip((t[-1]-t)/.015,0,1)
  add(sound,at,.12*gain,.25 if high else -.25)
  events.append(dict(instrument='high_drum' if high else 'low_drum',beat=at))
 barbeats=3 if key=='grove' else 4
 for bar in range(8):
  base=bar*barbeats;bass,chord=score['chords'][bar%4]
  voice('bass',bass,barbeats*.85,base,.18)
  if key=='title':
   for step,index in [(0,0),(1,2),(2.5,1),(3.25,3)]: voice('thumb',chord[index],.8,base+step,.095,(-1)**index*.38)
   for step,high,v in [(0,False,.65),(2,False,.45),(3,True,.35)]:drum(base+step,high,v)
  elif key=='battle':
   voice('bass',bass+7,.6,base+2,.12)
   for step,index in [(.5,0),(1.25,2),(2,1),(2.75,3),(3.5,2)]: voice('thumb',chord[index],.45,base+step,.085,(-1)**index*.4)
   for step,high,v in [(0,False,1),(.75,True,.5),(1.5,True,.8),(2,False,.85),(2.75,True,.55),(3.5,True,.8)]: drum(base+step,high,v)
   if bar%2:voice('flute',chord[2]+12,.9,base+2.5,.075,.3)
  elif key=='grove':
   for idx,m in enumerate(chord[:3]):voice('strings',m,2.6,base,.035,(-1)**idx*.45)
   for step,index in [(0,0),(.5,1),(1,2),(1.5,3),(2,2),(2.5,1)]:voice('thumb',chord[index],.55,base+step,.07,(-1)**index*.5)
   if bar%2==0:drum(base,False,.25)
  else:
   voice('strings',bass+12,3.8,base,.065,-.3)
   for step,index in [(0,0),(.75,2),(1.5,1),(2.25,3),(3,2),(3.5,1)]:voice('stone',chord[index],.6,base+step,.095,(-1)**index*.3)
   for step,high,v in [(0,False,1),(.75,True,.6),(1.5,False,.8),(2.25,True,.65),(3,False,.9),(3.5,True,.4)]:drum(base+step,high,v)
 for at,midi,length in score['motif']:voice(score['lead'],midi,length,at,.13 if key!='volcano' else .115,-.08)
 mix-=mix.mean(axis=0);mix*=.72/np.max(np.abs(mix))
 pcm=np.round(mix*32767).astype('<i2')
 path=OUT/(key+'.wav')
 with wave.open(str(path),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(pcm.tobytes())
 data=pcm.astype(float)/32768
 qc=dict(peak=float(np.max(np.abs(data))),rms=float(np.sqrt(np.mean(data**2))),boundary_step=float(np.max(np.abs(data[0]-data[-1]))),max_internal_step=float(np.max(np.abs(np.diff(data,axis=0)))),dc=float(np.max(np.abs(data.mean(axis=0)))),clipped_samples=int(np.count_nonzero(np.abs(data)>=.999)),listening_verified=False)
 assert qc['boundary_step'] < .005 and qc['clipped_samples']==0 and qc['dc']<1e-5
 return dict(context=key,**score,duration_seconds=frames/RATE,frames=frames,sample_rate=RATE,channels=2,bits=16,preview='full-gain source WAV; runtime gain separate',qc=qc,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),arrangement=events),data

def main():
 OUT.mkdir(parents=True,exist_ok=True); records=[];samples=[]
 for key,score in SCORES.items():
  record,data=render(key,score);records.append(record);samples.append(data)
 correlations={}
 for i,a in enumerate(samples):
  for j in range(i+1,len(samples)):
   n=min(len(a),len(samples[j]));correlations[f'{list(SCORES)[i]}:{list(SCORES)[j]}']=float(np.corrcoef(a[:n,0],samples[j][:n,0])[0,1])
 manifest=dict(original=True,samples_or_downloads=False,synthesis='authored pitched acoustic modal instruments and membrane drums, deterministic, no noise generator',loop_method='circular note tails and room reflections',listening_verified=False,tracks=records,pairwise_waveform_correlation=correlations)
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(dict(tracks=[{k:r[k] for k in ['context','title','duration_seconds','qc','sha256']} for r in records],correlations=correlations),indent=2))
if __name__=='__main__':main()
