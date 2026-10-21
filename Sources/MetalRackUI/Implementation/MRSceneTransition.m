#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import "MRSceneTransition.h"
@interface MRSceneTransition ()
@property(nonatomic, strong) MRNode *outgoing;
@property(nonatomic, copy) void (^completion)(void);
@property(nonatomic) MRColor3B fadeColor;
@property(nonatomic, strong) MRColorLayer *overlay;
@property(nonatomic, strong) MRSprite *incomingImage;
@property(nonatomic, strong) MRSprite *outgoingImage;
@end
@implementation MRSceneTransition
+ (instancetype)transitionWithDuration:(MRTime)duration scene:(MRNode *)scene {
    NSParameterAssert(scene && isfinite(duration) && duration>=0);
    MRSceneTransition *transition=[self new];transition->_duration=duration;transition->_incomingScene=scene;return transition;
}
- (void)prepareOutgoing:(MRNode *)scene completion:(void (^)(void))completion {
    _outgoing=scene;_completion=[completion copy];
    if(scene)[self addChild:scene];[self addChild:_incomingScene];
    _overlay=[MRColorLayer layerWithColor:MRRGBA(_fadeColor.r,_fadeColor.g,_fadeColor.b,0)];
    [self addChild:_overlay];
}
- (void)didEnterScene {
    [super didEnterScene];
    if(![self isKindOfClass:[MRCrossFadeTransition class]]) {
        _incomingScene.visible=NO;
        [_overlay runAction:[MRSequence actions:[MRFadeIn actionWithDuration:_duration*.5],
            [MRCallFunc actionWithTarget:self selector:@selector(showIncoming)],
            [MRFadeOut actionWithDuration:_duration*.5],
            [MRCallFunc actionWithTarget:self selector:@selector(finish)],nil]];
    }
}
- (void)showIncoming {_incomingScene.visible=YES;_outgoing.visible=NO;}
- (void)completeTransition {[self finish];}
- (void)finish {
    if(!_completion)return;
    [_overlay stopAllActions];[_outgoingImage stopAllActions];
    void (^completion)(void)=_completion;_completion=nil;
    _incomingScene.visible=YES;_outgoing.visible=YES;
    if(completion)completion();
}
- (void)visit:(MRRenderContext *)context {
    if([self isKindOfClass:[MRCrossFadeTransition class]]) {
        if(!_incomingImage) {
            CGRect bounds=(CGRect){CGPointZero,[MRSceneRuntime sharedRuntime].winSize};CGFloat density=[MRSceneRuntime sharedRuntime].pixelsPerPoint;
            MRTexture *a=MRCaptureNode(_incomingScene,context,bounds,density);
            MRTexture *b=_outgoing?MRCaptureNode(_outgoing,context,bounds,density):nil;
            _incomingImage=[[MRSprite alloc]initWithFrame:[[MRSpriteFrame alloc]initWithTexture:a pixelRect:(CGRect){CGPointZero,a.pixelSize} originalSize:bounds.size trimOffset:CGPointZero pixelsPerPoint:density rotated:NO]];
            _incomingImage.anchorPoint=CGPointZero;_incomingImage.blend=(MRBlendFunction){MRBlendOne,MRBlendOne};[self addChild:_incomingImage];
            if(b){_outgoingImage=[[MRSprite alloc]initWithFrame:[[MRSpriteFrame alloc]initWithTexture:b pixelRect:(CGRect){CGPointZero,b.pixelSize} originalSize:bounds.size trimOffset:CGPointZero pixelsPerPoint:density rotated:NO]];
                _outgoingImage.anchorPoint=CGPointZero;_outgoingImage.blend=(MRBlendFunction){MRBlendSourceAlpha,MRBlendOneMinusSourceAlpha};[self addChild:_outgoingImage];
                [_outgoingImage runAction:[MRSequence actions:[MRFadeTo actionWithDuration:_duration opacity:0],[MRCallFunc actionWithTarget:self selector:@selector(finish)],nil]];
            } else [self finish];
        }
        [_incomingImage visit:context];[_outgoingImage visit:context];
    } else {[_outgoing visit:context];[_incomingScene visit:context];[_overlay visit:context];}
}
@end
@implementation MRFadeTransition
+ (instancetype)transitionWithDuration:(MRTime)duration scene:(MRNode *)scene withColor:(MRColor3B)color {
    MRFadeTransition *transition=[self transitionWithDuration:duration scene:scene];transition.fadeColor=color;return transition;
}
@end
@implementation MRCrossFadeTransition
@end
#endif
