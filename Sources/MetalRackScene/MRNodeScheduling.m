#import "MRNodeScheduling.h"
#import "MRSceneEnvironment.h"
#import <objc/runtime.h>
@interface MRNodeCallback : NSObject
@property(nonatomic, weak) MRNode *node;
@property(nonatomic, weak) MRScheduler *scheduler;
@property(nonatomic) SEL selector;
@property(nonatomic) MRTime interval;
@property(nonatomic) BOOL updateCallback;
@property(nonatomic) BOOL takesElapsed;
@property(nonatomic) NSInteger priority;
- (void)fire:(MRTime)seconds;
- (void)update:(MRTime)seconds;
@end
@implementation MRNodeCallback
- (void)dealloc { [_scheduler unscheduleAllForTarget:self]; }
- (void)fire:(MRTime)seconds {
    MRNode *node=_node;
    if (!node) return;
    IMP implementation=[node methodForSelector:_selector];
    if(_takesElapsed){void (*callback)(id,SEL,MRTime)=(void *)implementation;callback(node,_selector,seconds);}
    else {void (*callback)(id,SEL)=(void *)implementation;callback(node,_selector);}
}
- (void)update:(MRTime)seconds { [self fire:seconds]; }
@end
static char MRNodeCallbacksKey;
@implementation MRNode (Scheduling)
- (NSMutableDictionary<NSString *,MRNodeCallback *> *)sceneCallbacks {
    NSMutableDictionary *callbacks=objc_getAssociatedObject(self,&MRNodeCallbacksKey);
    if (!callbacks) {
        callbacks=[NSMutableDictionary dictionary];
        objc_setAssociatedObject(self,&MRNodeCallbacksKey,callbacks,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return callbacks;
}
- (void)bindSceneCallback:(MRNodeCallback *)callback {
    MRScheduler *scheduler=self.environment.scheduler;
    if (!scheduler) return;
    if (callback.scheduler==scheduler) { [scheduler resumeTarget:callback]; return; }
    [callback.scheduler unscheduleAllForTarget:callback]; callback.scheduler=scheduler;
    if (callback.updateCallback) [scheduler scheduleUpdateForTarget:callback priority:callback.priority paused:NO];
    else [scheduler scheduleSelector:@selector(fire:) forTarget:callback interval:callback.interval paused:NO];
}
- (void)schedule:(SEL)selector { [self schedule:selector interval:0]; }
- (void)schedule:(SEL)selector interval:(MRTime)interval {
    NSParameterAssert(selector && [self respondsToSelector:selector] && isfinite(interval) && interval>=0);
    NSMethodSignature *signature=[self methodSignatureForSelector:selector];
    NSAssert(signature.numberOfArguments==2 || (signature.numberOfArguments==3 && strcmp([signature getArgumentTypeAtIndex:2],@encode(MRTime))==0),@"Scheduled methods must accept MRTime or no argument: %@",NSStringFromSelector(selector));
    NSAssert(strcmp(signature.methodReturnType,@encode(void))==0,@"Scheduled methods must return void");
    NSString *key=NSStringFromSelector(selector);
    MRNodeCallback *existing=[self sceneCallbacks][key];
    if (existing) [existing.scheduler unscheduleAllForTarget:existing];
    MRNodeCallback *callback=[MRNodeCallback new]; callback.node=self; callback.selector=selector; callback.interval=interval;callback.takesElapsed=signature.numberOfArguments==3;
    [self sceneCallbacks][key]=callback;
    if (self.inScene) [self bindSceneCallback:callback];
}
- (void)unschedule:(SEL)selector {
    NSString *key=NSStringFromSelector(selector);
    MRNodeCallback *callback=[self sceneCallbacks][key];
    [callback.scheduler unscheduleAllForTarget:callback]; [[self sceneCallbacks] removeObjectForKey:key];
}
- (void)scheduleUpdate { [self scheduleUpdateWithPriority:0]; }
- (void)scheduleUpdateWithPriority:(NSInteger)priority {
    [self unscheduleUpdate];
    MRNodeCallback *callback=[MRNodeCallback new]; callback.node=self; callback.selector=@selector(update:);
    callback.updateCallback=YES; callback.priority=priority;callback.takesElapsed=YES;
    [self sceneCallbacks][@"$update"]=callback;
    if (self.inScene) [self bindSceneCallback:callback];
}
- (void)unscheduleUpdate {
    MRNodeCallback *callback=[self sceneCallbacks][@"$update"];
    [callback.scheduler unscheduleAllForTarget:callback]; [[self sceneCallbacks] removeObjectForKey:@"$update"];
}
- (void)unscheduleAllSelectors {
    NSMutableDictionary *callbacks=objc_getAssociatedObject(self,&MRNodeCallbacksKey);
    for (MRNodeCallback *callback in [callbacks.allValues copy]) [callback.scheduler unscheduleAllForTarget:callback];
    [callbacks removeAllObjects];
}
- (void)pauseSceneCallbacks { for (MRNodeCallback *callback in [self sceneCallbacks].allValues) [callback.scheduler pauseTarget:callback]; }
- (void)resumeSceneCallbacks { for (MRNodeCallback *callback in [self sceneCallbacks].allValues) [self bindSceneCallback:callback]; }
- (void)update:(MRTime)seconds {}
@end
