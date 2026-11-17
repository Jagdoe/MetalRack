#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import "MRAudio.h"
#import "MRDefinitions.h"
#import "MRUtilities.h"
static int mainCalls=0,workerCalls=0,frameworkEOFStops=0,effectsFinished=0,musicFinished=0;
static BOOL baseline;
static void Record(NSString *method) {
    // AVAudioPlayer itself stops at natural EOF on its delegate run loop.
    // This is not an application-requested mutation. Keep recording it, while
    // every explicit app stop and every session activation remain checked.
    NSString *stack=[NSThread.callStackSymbols componentsJoinedByString:@"\n"];
    if(NSThread.isMainThread && [method isEqual:@"stop"] &&
       [stack containsString:@"AVAudioPlayerPriv) finishedPlaying:"] && ![stack containsString:@"MRAudio"]) {
        frameworkEOFStops++;return;
    }
    if(NSThread.isMainThread){mainCalls++;if(mainCalls<=3)NSLog(@"AUDIO_MAIN_CALL %@ stack=%@",method,NSThread.callStackSymbols);}
    else workerCalls++;
}
static void Swap(Class cls,SEL a,SEL b){method_exchangeImplementations(class_getInstanceMethod(cls,a),class_getInstanceMethod(cls,b));}
@interface AVAudioPlayer (ThreadReview) @end
@implementation AVAudioPlayer (ThreadReview)
- (BOOL)reviewPrepare{Record(@"prepareToPlay");return [self reviewPrepare];}
- (BOOL)reviewPlay{Record(@"play");return [self reviewPlay];}
- (void)reviewPause{Record(@"pause");[self reviewPause];}
- (void)reviewStop{Record(@"stop");[self reviewStop];}
- (void)reviewTime:(NSTimeInterval)t{Record(@"currentTime");[self reviewTime:t];}
- (void)reviewVolume:(float)v{Record(@"volume");[self reviewVolume:v];}
@end
@interface AVAudioSession (ThreadReview) @end
@implementation AVAudioSession (ThreadReview)
- (BOOL)reviewCategory:(NSString *)s error:(NSError **)e{Record(@"setCategory");return [self reviewCategory:s error:e];}
- (BOOL)reviewActive:(BOOL)b error:(NSError **)e{Record(@"setActive");return [self reviewActive:b error:e];}
- (BOOL)reviewActive:(BOOL)b withOptions:(AVAudioSessionSetActiveOptions)o error:(NSError **)e{Record(@"setActiveOptions");return [self reviewActive:b withOptions:o error:e];}
@end
@interface MRAudio (ThreadReview) @end
@implementation MRAudio (ThreadReview)
- (void)reviewFinished:(AVAudioPlayer *)p successfully:(BOOL)b {
    NSCAssert(b,@"Real native playback completes successfully");
    if(p==[self valueForKey:@"m_audioPlayer"])musicFinished++;
    [self reviewFinished:p successfully:b];
}
@end
@implementation MRDefinitions
+ (instancetype)sharedDefsManager {static id d;static dispatch_once_t once;dispatch_once(&once,^{d=[self new];});return d;}
- (NSDictionary *)getDefByClass:(NSString *)name Type:(NSString *)type{return @{@"effect":@"tick"};}
@end
@implementation MRUtilities
+ (NSString *)getContentStringForKey:(NSString *)key{return [NSUserDefaults.standardUserDefaults stringForKey:key];}
+ (void)setContentStringForKey:(NSString *)key withString:(NSString *)value{[NSUserDefaults.standardUserDefaults setObject:value forKey:key];}
@end
@interface AudioHost:NSObject<UIApplicationDelegate,AVAudioPlayerDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(strong) MRAudio *audio;
@property(strong) AVAudioPlayer *effect;
@property(strong) AVAudioPlayer *music;
@property(strong) AVAudioPlayer *voice;
@property int tick,plays,heartbeats;
@end
@implementation AudioHost
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    baseline=[NSProcessInfo.processInfo.arguments containsObject:@"--baseline"];
    Swap(AVAudioPlayer.class,@selector(prepareToPlay),@selector(reviewPrepare));Swap(AVAudioPlayer.class,@selector(play),@selector(reviewPlay));
    Swap(AVAudioPlayer.class,@selector(pause),@selector(reviewPause));Swap(AVAudioPlayer.class,@selector(stop),@selector(reviewStop));
    Swap(AVAudioPlayer.class,@selector(setCurrentTime:),@selector(reviewTime:));Swap(AVAudioPlayer.class,@selector(setVolume:),@selector(reviewVolume:));
    Swap(AVAudioSession.class,@selector(setCategory:error:),@selector(reviewCategory:error:));
    Swap(AVAudioSession.class,@selector(setActive:error:),@selector(reviewActive:error:));Swap(AVAudioSession.class,@selector(setActive:withOptions:error:),@selector(reviewActive:withOptions:error:));
    Swap(MRAudio.class,@selector(audioPlayerDidFinishPlaying:successfully:),@selector(reviewFinished:successfully:));
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[UIViewController new];[self.window makeKeyAndVisible];
    self.audio=MRAudio.sharedAudioManager;self.effect=[self.audio valueForKey:@"m_dictSounds"][@"tick"];NSAssert(self.effect,@"Real CAF cached by production addSound");self.effect.delegate=self;
    [self.audio musicPlayList:@[@"song-a",@"song-b"]];
    [NSTimer scheduledTimerWithTimeInterval:.02 repeats:YES block:^(NSTimer *timer){self.heartbeats++;}];
    [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(step:) userInfo:nil repeats:YES];return YES;
}
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)p successfully:(BOOL)b{NSAssert(b,@"Effect completes");effectsFinished++;}
- (void)step:(NSTimer *)timer {
    self.tick++;
    if(self.tick<=24 && self.tick%4==1){NSAssert([self.audio soundsPlay:@"effect"],@"Effect accepted");self.plays++;}
    if(self.tick==5){[self.audio voicePlay:@"tick"];self.voice=[self.audio valueForKey:@"m_audioVoice"];}
    if(self.tick==6){[self.audio voicePause:YES];[self.audio voicePause:NO];[self.audio voiceStop];}
    if(self.tick==26){NSAssert(effectsFinished==6 && musicFinished>=4,@"Natural EOF callbacks survive: effects=%d music=%d",effectsFinished,musicFinished);[self.audio musicEnable:NO];[self.audio musicSetVolume:.4];NSAssert(fabs(self.audio.musicGetVolume-.4)<.001,@"Stored music volume keeps synchronous API semantics");}
    if(self.tick==29){self.music=[self.audio valueForKey:@"m_audioPlayer"];NSAssert(!self.music.playing && fabs(self.music.volume-.1)<.001,@"Pause and gain applied in order");[self.audio musicEnable:YES];[self.audio musicSetVolume:0 andStore:NO];}
    if(self.tick==32){NSAssert(fabs(self.audio.musicGetVolume-.4)<.001,@"Temporary gain never changes saved volume");[self.audio soundsSetVolume:0];[self.audio soundsPlay:@"effect"];}
    if(self.tick==36){NSAssert(effectsFinished==7 && self.effect.volume==0,@"Muted effect remains silent and completes");[self.audio voicePlay:@"tick"];self.voice=[self.audio valueForKey:@"m_audioVoice"];[self.audio voicePause:YES];[self.audio voicePause:NO];[self.audio voiceStop];[self.audio soundsDestroy];[self.audio musicEnable:NO];[self.audio musicDestroy];}
    if(self.tick==40){
        NSAssert(!self.effect.playing && !self.voice.playing && !self.music.playing,@"Rapid play/pause/stop leaves no stale playback");
        NSAssert(self.heartbeats>80,@"Main run loop continues while native audio runs");
        NSAssert(baseline?mainCalls>0:(mainCalls==0 && workerCalls>0),@"Activation-sensitive player/session calls off main: main=%d worker=%d",mainCalls,workerCalls);
        NSLog(@"AUDIO_THREAD_%@ mainCalls=%d workerCalls=%d effectsEOF=%d musicEOF=%d heartbeat=%d frameworkEOFStops=%d ordering=1 gains=1 mute=1",baseline?@"BASELINE":@"PASS",mainCalls,workerCalls,effectsFinished,musicFinished,self.heartbeats,frameworkEOFStops);[timer invalidate];
    }
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(AudioHost.class));}}
