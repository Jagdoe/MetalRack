#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import "MRSceneRuntime.h"
#import "MRUIKit.h"
@interface MRFPSDisplay : MRNode
@end
@implementation MRFPSDisplay {
    MRSystemText *_label;
    MRTime _elapsed;
    NSUInteger _frames;
}
- (instancetype)init {if((self=[super init])){_label=[MRSystemText labelWithString:@"FPS" fontName:@"Helvetica" fontSize:12];_label.anchorPoint=CGPointZero;_label.position=CGPointMake(4,4);[self addChild:_label];[self schedule:@selector(countFrame:)];}return self;}
- (void)countFrame:(MRTime)seconds {_elapsed+=seconds;_frames++;if(_elapsed>=.5){_label.string=[NSString stringWithFormat:@"%.1f FPS",_frames/_elapsed];_elapsed=0;_frames=0;}}
@end
@implementation MRSceneRuntime {
    NSMutableArray<MRNode *> *_stack;
    MRScheduler *_sessionScheduler;
    MRInput *_sessionInput;
    NSMutableDictionary *_textAtlases;
    NSMutableDictionary *_textInsets;
}
+ (instancetype)sharedRuntime { static MRSceneRuntime *runtime; static dispatch_once_t once; dispatch_once(&once,^{runtime=[self new];}); return runtime; }
- (instancetype)init { if ((self=[super init])) { _stack=[NSMutableArray array]; _pixelsPerPoint=1;_sessionScheduler=[MRScheduler new];_sessionInput=[MRInput new]; } return self; }
- (void)configureWithView:(UIView *)view driver:(MRSceneDriver *)driver baseURL:(NSURL *)baseURL pixelsPerPoint:(CGFloat)density {
    NSParameterAssert(view && driver && baseURL && density>0);
    NSAssert(!_driver,@"A native scene runtime is configured once");
    NSAssert(driver.scheduler==_sessionScheduler && driver.environment.input==_sessionInput,@"Host must use this session scheduler and input");
    _view=view; _driver=driver; _pixelsPerPoint=density;
    _resources=[[MRSceneResources alloc] initWithContext:driver.context baseURL:baseURL];
    if(_displayFPS)self.displayFPS=YES;
}
- (void)registerTextAtlas:(MRTextAtlas *)atlas fontName:(NSString *)name horizontalInsetRatio:(CGFloat)ratio {
    if(!_textAtlases){_textAtlases=[NSMutableDictionary new];_textInsets=[NSMutableDictionary new];}
    _textAtlases[name]=atlas;_textInsets[name]=@(ratio);
}
- (MRTextAtlas *)textAtlasNamed:(NSString *)name {return _textAtlases[name];}
- (CGFloat)textInsetRatioForFont:(NSString *)name {return [_textInsets[name] doubleValue];}
- (void)setDisplayFPS:(BOOL)enabled {_displayFPS=enabled;_driver.overlay=enabled?[MRFPSDisplay new]:nil;}
- (BOOL)isPaused { return _driver.paused; }
- (MRTexture *)loadAtlasNamed:(NSString *)name {
    NSURL *url=[NSURL fileURLWithPath:[MRBundleResources pathForResource:name]];
    NSDictionary *manifest=[NSDictionary dictionaryWithContentsOfURL:url];
    CGFloat density=_atlasDensity ? _atlasDensity(name,manifest) : 1;
    NSError *error=nil; BOOL loaded=[_resources addAtlasAtURL:url pixelsPerPoint:density error:&error];
    NSAssert(loaded,@"Cannot load native atlas %@: %@",name,error); return loaded ? [_resources textureAtURL:[[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:manifest[@"metadata"][@"textureFileName"]] error:&error] : nil;
}
- (MRTexture *)loadAtlasNamed:(NSString *)name imageNamed:(NSString *)image pixelsPerPoint:(CGFloat)density {
    NSURL *url=[NSURL fileURLWithPath:[MRBundleResources pathForResource:name]],*imageURL=[NSURL fileURLWithPath:[MRBundleResources pathForResource:image]];
    NSError *error=nil;BOOL loaded=[_resources addAtlasAtURL:url imageURL:imageURL pixelsPerPoint:density error:&error];
    NSAssert(loaded,@"Cannot load native atlas %@: %@",name,error);return loaded?[_resources textureAtURL:imageURL error:&error]:nil;
}
- (MRTexture *)textureNamed:(NSString *)name {
    NSError *error=nil; MRTexture *texture=[_resources textureAtURL:[NSURL fileURLWithPath:[MRBundleResources pathForResource:name]] error:&error];
    NSAssert(texture,@"Cannot load native image %@: %@",name,error); return texture;
}
- (void)removeImageNamed:(NSString *)name { [_resources removeCachedImageAtURL:[NSURL fileURLWithPath:[MRBundleResources pathForResource:name]]]; }
- (void)cacheImage:(UIImage *)image named:(NSString *)name {
    NSError *error=nil;MRTexture *texture=[[MRTexture alloc]initWithContext:self.context image:image.CGImage error:&error];
    if(texture)[_resources cacheTexture:texture atURL:[NSURL fileURLWithPath:[MRBundleResources pathForResource:name]]];
}
- (MRRenderContext *)context { return _driver.context; }
- (MRScheduler *)scheduler { return _sessionScheduler; }
- (MRInput *)input { return _sessionInput; }
- (CGSize)winSize { return _view.bounds.size; }
- (MRNode *)runningScene { return _driver.scene; }
- (NSArray *)sceneStack { return [_stack copy]; }
- (void)runWithScene:(MRNode *)scene { NSAssert(!_stack.count,@"A scene is already running"); [self pushScene:scene]; }
- (void)presentNode:(MRNode *)node previous:(MRNode *)previous cleanup:(BOOL)cleanup {
    if([node isKindOfClass:[MRSceneTransition class]]) {
        MRSceneTransition *transition=(id)node;[previous willBeginSceneTransition];self.input.enabled=NO;
        __weak MRSceneRuntime *owner=self;
        __weak MRSceneTransition *weakTransition=transition;
        [transition prepareOutgoing:previous completion:^{
            MRSceneRuntime *runtime=owner;MRSceneTransition *current=weakTransition;
            runtime.driver.scene=current.incomingScene;[previous removeFromParent];[current.incomingScene didFinishSceneTransition];
            if(cleanup)[previous cleanup];runtime.input.enabled=!runtime.isPaused;
        }];_driver.scene=transition;
    } else {[previous willBeginSceneTransition];_driver.scene=node;[node didFinishSceneTransition];if(cleanup)[previous cleanup];}
}
- (void)pushScene:(MRNode *)scene {
    if([_driver.scene isKindOfClass:[MRSceneTransition class]])[(MRSceneTransition *)_driver.scene completeTransition];
    NSParameterAssert(scene);MRNode *previous=_driver.scene;
    [_stack addObject:[scene isKindOfClass:[MRSceneTransition class]]?[(MRSceneTransition *)scene incomingScene]:scene];
    [self presentNode:scene previous:previous cleanup:NO];
}
- (void)replaceScene:(MRNode *)scene {
    if([_driver.scene isKindOfClass:[MRSceneTransition class]])[(MRSceneTransition *)_driver.scene completeTransition];
    NSParameterAssert(scene);MRNode *previous=_driver.scene;
    if(_stack.count)[_stack removeLastObject];
    [_stack addObject:[scene isKindOfClass:[MRSceneTransition class]]?[(MRSceneTransition *)scene incomingScene]:scene];
    [self presentNode:scene previous:previous cleanup:YES];
}
- (NSArray *)getSceneStack {return self.sceneStack;}
- (void)popSceneWithTransition:(Class)type duration:(MRTime)duration {
    if([_driver.scene isKindOfClass:[MRSceneTransition class]])[(MRSceneTransition *)_driver.scene completeTransition];
    if(_stack.count<2){[self popScene];return;}
    MRNode *previous=_driver.scene;[_stack removeLastObject];
    MRSceneTransition *transition=[type transitionWithDuration:duration scene:_stack.lastObject];
    [self presentNode:transition previous:previous cleanup:YES];
}
- (void)popScene {
    if([_driver.scene isKindOfClass:[MRSceneTransition class]])[(MRSceneTransition *)_driver.scene completeTransition];
    MRNode *previous=_stack.lastObject; _driver.scene=nil; [previous cleanup];
    if (_stack.count) [_stack removeLastObject]; _driver.scene=_stack.lastObject;[_driver.scene didFinishSceneTransition];
    if (!_stack.count) [self stopAnimation];
}
- (void)pause { _driver.paused=YES; _driver.environment.input.enabled=NO; }
- (void)resume { _driver.paused=NO; _driver.environment.input.enabled=YES; }
- (void)startAnimation { if (_runningChanged) _runningChanged(YES); }
- (void)stopAnimation { if (_runningChanged) _runningChanged(NO); }
- (void)end { if([_driver.scene isKindOfClass:[MRSceneTransition class]])[(MRSceneTransition *)_driver.scene completeTransition]; [self stopAnimation]; _driver.scene=nil; for (MRNode *scene in _stack) [scene cleanup]; [_stack removeAllObjects]; }
@end
#endif
