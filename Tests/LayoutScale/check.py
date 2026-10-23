"""Compile actual native utility method against both device idioms/options."""
from pathlib import Path
import tempfile,subprocess
r=Path(__file__).resolve().parents[2];s=(r/'Sources/MetalRackUI/Implementation/MRUtilities.m').read_text();a=s.index('+ (float)getDeviceScaleAdjustment');b=s.index('+ (BOOL)isIPad1',a)
code='''#import <Foundation/Foundation.h>
#include <math.h>
static int idiom;static NSString*setting;
#define UI_USER_INTERFACE_IDIOM() idiom
#define UIUserInterfaceIdiomPad 1
@interface MRSceneHost:NSObject
+(NSString*)option:(NSString*)key fallback:(NSString*)fallback;
@end
@implementation MRSceneHost
+(NSString*)option:(NSString*)key fallback:(NSString*)fallback{return setting?:fallback;}
@end
@interface MRUtilities:NSObject
+(float)getDeviceScaleAdjustment;
@end
@implementation MRUtilities
'''+s[a:b]+'''\n@end
int main(){@autoreleasepool{
 for(idiom=0;idiom<=1;idiom++){
  setting=nil;float legacy=idiom?2:1;NSCAssert([MRUtilities getDeviceScaleAdjustment]==legacy,@"Preserve omitted-option behavior");
  for(NSString*v in @[@"0",@"-1",@"nan",@"inf",@"nonsense"]){setting=v;NSCAssert([MRUtilities getDeviceScaleAdjustment]==legacy,@"Invalid values preserve default");}
  setting=@"1";NSCAssert([MRUtilities getDeviceScaleAdjustment]==1,@"Canonical points on either idiom");
  setting=@"1.5";NSCAssert([MRUtilities getDeviceScaleAdjustment]==1.5,@"Positive fractional client preference");
 }
 puts("LAYOUT_SCALE_PASS both-idioms legacy-default canonical fractional invalid-values");
}}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d);(p/'check.m').write_text(code);subprocess.run(['xcrun','clang','-Werror','-framework','Foundation',str(p/'check.m'),'-o',str(p/'check')],check=True);subprocess.run([str(p/'check')],check=True)
