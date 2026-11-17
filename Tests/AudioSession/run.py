#!/usr/bin/env python3
"""Compile the unchanged production MRAudio into a native simulator test host.
Only definition lookup/preferences are doubles; AVAudioPlayer and AVAudioSession are real.
"""
import argparse,subprocess,plistlib,math,struct,wave,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--device',required=True);p.add_argument('--output',required=True);p.add_argument('--baseline',action='store_true');a=p.parse_args();root=Path(__file__).resolve().parents[2];out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=True);app=out/'AudioThreadHost.app';app.mkdir(exist_ok=True)
with wave.open(str(out/'tone.wav'),'wb') as w:
 w.setparams((1,2,22050,0,'NONE','not compressed'));w.writeframes(b''.join(struct.pack('<h',int(1800*math.sin(i*2*math.pi*440/22050))) for i in range(5512)))
subprocess.run(['afconvert','-f','caff','-d','LEI16',str(out/'tone.wav'),str(app/'tick.caf')],check=True,capture_output=True)
for name in ['song-a','song-b']:subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(out/'tone.wav'),str(app/(name+'.mp3'))],check=True)
plist={'CFBundleIdentifier':'com.metalrack.AudioThreadHost','CFBundleExecutable':'AudioThreadHost','CFBundleName':'AudioThreadHost','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1','MinimumOSVersion':'17.0','UIDeviceFamily':[1,2],'UILaunchScreen':{},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait']};(app/'Info.plist').write_bytes(plistlib.dumps(plist))
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
cmd=['xcrun','clang','-fobjc-arc','-fblocks','-target','arm64-apple-ios17.0-simulator','-isysroot',sdk,'-I',str(root/'Tests/AudioSession/Stubs'),'-I',str(root/'Sources/MetalRackUI/include'),str(root/'Sources/MetalRackUI/Implementation/MRAudio.m'),str(root/'Tests/AudioSession/Host.m'),'-framework','UIKit','-framework','AVFoundation','-framework','Foundation','-o',str(app/'AudioThreadHost')]
with (out/'compile.log').open('w') as f:subprocess.run(cmd,check=True,stdout=f,stderr=subprocess.STDOUT)
subprocess.run(['codesign','--force','--sign','-',str(app)],check=True,capture_output=True);subprocess.run(['xcrun','simctl','install',a.device,str(app)],check=True)
log=out/'native.log';marker='AUDIO_THREAD_BASELINE' if a.baseline else 'AUDIO_THREAD_PASS'
with log.open('w') as f:
 proc=subprocess.Popen(['xcrun','simctl','launch','--terminate-running-process','--console-pty',a.device,plist['CFBundleIdentifier']]+(['--baseline'] if a.baseline else []),stdout=f,stderr=subprocess.STDOUT)
 try:
  until=time.monotonic()+45
  while time.monotonic()<until:
   text=log.read_text(errors='replace')
   if 'Assertion failure' in text or 'Terminating app' in text:raise RuntimeError(next(l for l in text.splitlines() if 'reason:' in l or 'Assertion failure' in l))
   if marker in text:print(next(l for l in text.splitlines() if marker in l),flush=True);break
   if proc.poll() is not None:raise RuntimeError('Launch ended: '+text[-1500:])
   time.sleep(.1)
  else:raise RuntimeError('Timeout; see '+str(log))
 finally:
  subprocess.run(['xcrun','simctl','terminate',a.device,plist['CFBundleIdentifier']],capture_output=True)
  try:proc.wait(timeout=5)
  except subprocess.TimeoutExpired:proc.terminate()
