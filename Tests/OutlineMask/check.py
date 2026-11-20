#!/usr/bin/env python3
"""Compare the production outline with the original pixel oracle, including Debug cost."""
import ctypes,json,random,statistics,subprocess,tempfile,time,argparse
from pathlib import Path
root=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--report',type=Path);a=p.parse_args()
old=subprocess.check_output(['git','show','7ba9ddbf675e8f959a4b6f412c21e0feea5e34dc:Sources/MetalRackImageProcessing/OutlineMask.c'],cwd=root,text=True).replace('MRCreateOutlineMask(', 'MRCreateOutlineMaskBefore(')
header=root/'Sources/MetalRackImageProcessing/include';rng=random.Random(731);results={};cases=0
with tempfile.TemporaryDirectory() as td:
 t=Path(td);(t/'before.c').write_text(old)
 for optimization in ['-O0','-O2']:
  lib=t/('mask'+optimization+'.dylib')
  subprocess.run(['clang','-std=c11',optimization,'-Wall','-Wextra','-Werror','-dynamiclib','-I',str(header),str(t/'before.c'),str(root/'Sources/MetalRackImageProcessing/OutlineMask.c'),'-o',str(lib)],check=True)
  dll=ctypes.CDLL(str(lib));before=dll.MRCreateOutlineMaskBefore;after=dll.MRCreateOutlineMask
  for f in [before,after]:f.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_void_p]
  def check(data,w,h,r):
   global cases
   source=ctypes.create_string_buffer(bytes(data));x=ctypes.create_string_buffer(w*h*4);y=ctypes.create_string_buffer(w*h*4)
   before(source,w,h,r,x);after(source,w,h,r,y)
   assert x.raw==y.raw,(optimization,w,h,r);cases+=1
  for pattern in range(512):
   data=bytearray(3*3*4)
   for i in range(9):data[i*4+3]=128 if pattern&(1<<i) else 127
   for radius in range(5):check(data,3,3,radius)
  for w,h in [(1,1),(1,31),(37,1),(2,3),(19,23),(67,39)]:
   for mode in range(8):
    data=bytearray(rng.randrange(256) for _ in range(w*h*4))
    for i in range(w*h):data[i*4+3]=0 if mode==0 else 255 if mode==1 else rng.choice([0,1,127,128,254,255])
    for radius in [0,1,2,4,8,17]:check(data,w,h,radius)
  check(bytearray(24),3,2,90)
  # Large furniture-like silhouette with an internal aperture and empty rows.
  w,h,radius=768,512,4;data=bytearray(w*h*4)
  for y in range(80,470):
   for x in range(100,680):
    if not (180<x<590 and 130<y<330):data[(y*w+x)*4+3]=255
  check(data,w,h,radius)
  source=ctypes.create_string_buffer(bytes(data));dest=ctypes.create_string_buffer(len(data));timings={}
  for name,f in [('before',before),('after',after)]:
   samples=[]
   for _ in range(9):
    start=time.thread_time();f(source,w,h,radius,dest);samples.append((time.thread_time()-start)*1000)
   timings[name+'MedianCpuMs']=statistics.median(samples)
  timings['speedup']=timings['beforeMedianCpuMs']/timings['afterMedianCpuMs'];results[optimization]=timings
  assert timings['speedup']>2,results
results['pixelExactCases']=cases
if a.report:a.report.write_text(json.dumps(results,indent=2))
print('OUTLINE_MASK_EQUIVALENCE_PASS',json.dumps(results))
