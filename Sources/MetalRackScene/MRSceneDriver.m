#import "MRSceneDriver.h"
@interface MRNode (SceneRootAdoption)
- (void)mrRemoveChildPreservingAttachment:(MRNode *)child;
@end
@interface MRSceneActionClock : NSObject
@property(nonatomic, weak) MRNode *scene;
@property(nonatomic, weak) MRNode *overlay;
- (void)update:(MRTime)seconds;
@end
@implementation MRSceneActionClock
- (void)update:(MRTime)seconds { [_scene advanceTime:seconds]; [_overlay advanceTime:seconds]; }
@end
@implementation MRSceneDriver {
    MRSceneActionClock *_actionClock;
}
- (instancetype)initWithContext:(MRRenderContext *)context scheduler:(MRScheduler *)scheduler {
    return [self initWithContext:context scheduler:scheduler input:[MRInput new]];
}
- (instancetype)initWithContext:(MRRenderContext *)context scheduler:(MRScheduler *)scheduler input:(MRInput *)input {
    NSParameterAssert(context && scheduler && input);
    if ((self=[super init])) {
        _context=context; _scheduler=scheduler; _environment=[[MRSceneEnvironment alloc] initWithContext:context scheduler:scheduler input:input]; _actionClock=[MRSceneActionClock new];
        // Registered before game callbacks at priority zero, as the original
        // action tick was. Negative-priority updates still run before actions.
        [_scheduler scheduleUpdateForTarget:_actionClock priority:0 paused:NO];
    }
    return self;
}
- (void)dealloc { [_overlay detachFromEnvironment]; [_scene detachFromEnvironment]; [_scheduler unscheduleAllForTarget:_actionClock]; }
- (void)setOverlay:(MRNode *)overlay {
    if(_overlay==overlay)return;[_overlay detachFromEnvironment];_overlay=overlay;_actionClock.overlay=overlay;
    if(overlay)[overlay attachToEnvironment:_environment];
}
- (void)setScene:(MRNode *)scene {
    if(_scene==scene)return;
    MRNode *next=scene,*previous=_scene;
    BOOL adoptingPrevious=NO;
    for(MRNode *ancestor=previous.parent;ancestor;ancestor=ancestor.parent)if(ancestor==next){adoptingPrevious=YES;break;}
    BOOL promotingChild=NO;
    for(MRNode *ancestor=next.parent;ancestor;ancestor=ancestor.parent)if(ancestor==previous){promotingChild=YES;break;}
    if(promotingChild)[next.parent mrRemoveChildPreservingAttachment:next];
    if(!adoptingPrevious)[previous detachFromEnvironment];
    [_environment.input cancelAllPointers];_scene=next;_actionClock.scene=next;
    if(next)[next attachToEnvironment:_environment];
}
- (void)step:(MRTime)seconds {
    if (_paused) return;
    [_scheduler tick:seconds]; [self draw];
}
- (void)draw {
    [_context beginFrameWithSize:_logicalSize];
    [_scene visit:_context]; [_overlay visit:_context]; [_context present];
}
@end
