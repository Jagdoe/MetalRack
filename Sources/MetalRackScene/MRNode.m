#import "MRNode.h"
#import "MRAction.h"
#import "MRSceneEnvironment.h"
#import "MRNodeScheduling.h"
#include <math.h>
#import <objc/runtime.h>

@interface MRNode () {
    NSMutableArray<MRNode *> *_children;
    NSMutableArray<MRAction *> *_actions;
    __weak MRNode *_parent;
    BOOL _leavingEnvironment;
    NSArray<MRNode *> *_childSnapshot, *_orderedChildren;
    CGAffineTransform _cachedLocalTransform, _cachedWorldTransform;
    BOOL _localTransformValid, _worldTransformValid;
    NSUInteger _timeWork; // Actions plus nodes with a custom advanceTime implementation, throughout this subtree.
}
@end
@implementation MRNode
- (instancetype)init {
    if ((self=[super init])) { _children=[NSMutableArray new]; _actions=[NSMutableArray new]; _scaleX=1; _scaleY=1; _visible=YES; _tag=-1;
        // Preserve subclass clocks even when they do not own actions.
        _timeWork=class_getMethodImplementation(object_getClass(self),@selector(advanceTime:))!=class_getMethodImplementation(MRNode.class,@selector(advanceTime:));
    }
    return self;
}
+ (instancetype)node { return [[self alloc] init]; }
- (void)dealloc {
    [self unscheduleAllSelectors];
    for (MRNode *child in _children) { child->_parent=nil; [child invalidateWorldTransform]; }
    [self stopAllActions];

}
// Update only on action/tree mutations; idle nodes do no per-frame bookkeeping.
- (void)mrAdjustTimeWork:(NSInteger)delta {
    if (!delta) return;
    for (MRNode *node=self;node;node=node->_parent) {
        NSAssert(delta>=0 || node->_timeWork>=(NSUInteger)(-delta),@"Unbalanced subtree action work");
        if (delta<0) node->_timeWork-=(NSUInteger)(-delta);
        else node->_timeWork+=(NSUInteger)delta;
    }
}
- (BOOL)isInScene { return _environment!=nil && !_leavingEnvironment; }
- (void)attachToEnvironment:(MRSceneEnvironment *)environment {
    NSParameterAssert(environment);
    if (_environment==environment) return;
    NSAssert(!_leavingEnvironment,@"Cannot attach during scene exit");
    if (_environment) [self detachFromEnvironment];
    _environment=environment;
    [self resumeSceneCallbacks];
    for (MRNode *child in [_children copy]) if (child.parent==self) [child attachToEnvironment:environment];
    [self didEnterScene];
}
- (void)detachFromEnvironment {
    if (!_environment || _leavingEnvironment) return;
    _leavingEnvironment=YES;
    [self willExitScene];
    [_environment.input removeReceiver:(id)self];
    [self pauseSceneCallbacks];
    for (MRNode *child in [_children copy]) if (child.parent==self) [child detachFromEnvironment];
    _environment=nil; _leavingEnvironment=NO;
}
- (void)didEnterScene {}
- (void)willExitScene {}
- (void)willBeginSceneTransition {for(MRNode *child in [_children copy])if(child.parent==self)[child willBeginSceneTransition];}
- (void)didFinishSceneTransition {for(MRNode *child in [_children copy])if(child.parent==self)[child didFinishSceneTransition];}
- (void)cleanup {
    [self stopAllActions]; [self unscheduleAllSelectors];
    for (MRNode *child in [_children copy]) if (child.parent==self) [child cleanup];
}
- (CGFloat)scale { NSAssert(_scaleX==_scaleY,@"Node has independent axis scales"); return _scaleX; }
- (void)invalidateWorldTransform {
    if (!_worldTransformValid) return;
    _worldTransformValid=NO;
    for (MRNode *child in _children) [child invalidateWorldTransform];
}
- (void)invalidateLocalTransform {
    _localTransformValid=NO; [self invalidateWorldTransform];
}
- (void)setPosition:(CGPoint)value { if (CGPointEqualToPoint(_position,value)) return; _position=value; [self invalidateLocalTransform]; }
- (void)setAnchorPoint:(CGPoint)value { if (CGPointEqualToPoint(_anchorPoint,value)) return; _anchorPoint=value; [self invalidateLocalTransform]; }
- (void)setContentSize:(CGSize)value { if (CGSizeEqualToSize(_contentSize,value)) return; _contentSize=value; [self invalidateLocalTransform]; }
- (void)setRotation:(CGFloat)value { if (_rotation==value) return; _rotation=value; [self invalidateLocalTransform]; }
- (void)setScaleX:(CGFloat)value { if (_scaleX==value) return; _scaleX=value; [self invalidateLocalTransform]; }
- (void)setScaleY:(CGFloat)value { if (_scaleY==value) return; _scaleY=value; [self invalidateLocalTransform]; }
- (void)setSkewX:(CGFloat)value { if (_skewX==value) return; _skewX=value; [self invalidateLocalTransform]; }
- (void)setSkewY:(CGFloat)value { if (_skewY==value) return; _skewY=value; [self invalidateLocalTransform]; }
- (void)setIgnoresAnchorPointForPosition:(BOOL)value { if (_ignoresAnchorPointForPosition==value) return; _ignoresAnchorPointForPosition=value; [self invalidateLocalTransform]; }
- (void)setScale:(CGFloat)scale { if (_scaleX==scale && _scaleY==scale) return; _scaleX=scale; _scaleY=scale; [self invalidateLocalTransform]; }
- (CGRect)boundingBox { return CGRectApplyAffineTransform((CGRect){CGPointZero,_contentSize},self.nodeToParentTransform); }
- (MRNode *)getChildByTag:(NSInteger)tag { for (MRNode *child in _children) if (child.tag==tag) return child; return nil; }
- (void)reorderChild:(MRNode *)child z:(NSInteger)z { NSParameterAssert(child.parent==self); child.zOrder=z; }
- (MRNode *)parent { return _parent; }
- (NSArray *)children {
    if (!_childSnapshot) _childSnapshot=[_children copy];
    return _childSnapshot;
}
- (void)setZOrder:(NSInteger)zOrder {
    if (_zOrder==zOrder) return;
    _zOrder=zOrder; MRNode *parent=_parent; if (parent) parent->_orderedChildren=nil;
}
- (void)addChild:(MRNode *)child { [self addChild:child z:child.zOrder]; }
- (void)addChild:(MRNode *)child z:(NSInteger)z { [self addChild:child z:z tag:child.tag]; }
- (void)addChild:(MRNode *)child z:(NSInteger)z tag:(NSInteger)tag {
    NSParameterAssert(child);
    NSAssert(!child->_parent,@"Detach a node before reparenting it");
    for (MRNode *ancestor=self; ancestor; ancestor=ancestor.parent)
        NSAssert(ancestor!=child,@"A scene tree cannot contain cycles");
    child.zOrder=z; child.tag=tag; [_children addObject:child]; child->_parent=self;
    [self mrAdjustTimeWork:(NSInteger)child->_timeWork];
    [child invalidateWorldTransform];
    _childSnapshot=nil; _orderedChildren=nil;
    if (self.inScene) [child attachToEnvironment:_environment];
}
// Internal scene-root adoption keeps lifecycle/callback state continuous.
- (void)mrRemoveChildPreservingAttachment:(MRNode *)child {
    if(child->_parent!=self)return;[self mrAdjustTimeWork:-(NSInteger)child->_timeWork];child->_parent=nil;[child invalidateWorldTransform];[_children removeObjectIdenticalTo:child];
    _childSnapshot=nil; _orderedChildren=nil;
}
- (void)removeChild:(MRNode *)child {
    if (child->_parent!=self) return;
    [child detachFromEnvironment];
    [self mrAdjustTimeWork:-(NSInteger)child->_timeWork];
    child->_parent=nil; [child invalidateWorldTransform]; [_children removeObjectIdenticalTo:child];
    _childSnapshot=nil; _orderedChildren=nil;
}
- (void)removeChild:(MRNode *)child cleanup:(BOOL)cleanup {
    if (child.parent!=self) return;
    [self removeChild:child]; if (cleanup) [child cleanup];
}
- (void)removeAllChildrenWithCleanup:(BOOL)cleanup {
    for (MRNode *child in [_children copy]) if (child.parent==self) [self removeChild:child cleanup:cleanup];
}
- (void)removeFromParentAndCleanup:(BOOL)cleanup { [_parent removeChild:self cleanup:cleanup]; }
- (void)removeFromParent {  [_parent removeChild:self]; }
- (CGRect)localDrawBounds {return CGRectNull;}
- (CGRect)paintedBounds {
    CGRect bounds=self.localDrawBounds;
    for(MRNode *child in _children){CGRect b=child.paintedBounds;if(CGRectIsNull(b))continue;b=CGRectApplyAffineTransform(b,child.nodeToParentTransform);bounds=CGRectIsNull(bounds)?b:CGRectUnion(bounds,b);}
    return bounds;
}
- (CGRect)subtreeBounds {
    CGRect bounds=(CGRect){CGPointZero,_contentSize};
    for (MRNode *child in _children) if (child.visible)
        bounds=CGRectUnion(bounds,CGRectApplyAffineTransform(child.subtreeBounds,child.nodeToParentTransform));
    return bounds;
}
- (CGAffineTransform)nodeToParentTransform {
    if (_localTransformValid) return _cachedLocalTransform;
    CGFloat ax=_anchorPoint.x*_contentSize.width, ay=_anchorPoint.y*_contentSize.height;
    CGFloat x=_position.x, y=_position.y;
    if (_ignoresAnchorPointForPosition) { x+=ax; y+=ay; }
    CGFloat radians=-_rotation*(M_PI/180), c=cos(radians), s=sin(radians);
    CGAffineTransform t=CGAffineTransformMake(c*_scaleX,s*_scaleX,-s*_scaleY,c*_scaleY,x,y);
    if (_skewX || _skewY) {
        CGAffineTransform skew=CGAffineTransformMake(1,tan(_skewY*M_PI/180),tan(_skewX*M_PI/180),1,0,0);
        t=CGAffineTransformConcat(skew,t);
    }
    _cachedLocalTransform=CGAffineTransformTranslate(t,-ax,-ay); _localTransformValid=YES;
    return _cachedLocalTransform;
}
- (CGAffineTransform)nodeToWorldTransform {
    if (_worldTransformValid) return _cachedWorldTransform;
    CGAffineTransform t=self.nodeToParentTransform;
    MRNode *parent=_parent;
    if (parent) t=CGAffineTransformConcat(t,parent.nodeToWorldTransform);
    _cachedWorldTransform=t; _worldTransformValid=YES;
    return t;
}
- (CGAffineTransform)worldToNodeTransform {return CGAffineTransformInvert(self.nodeToWorldTransform);}
- (CGPoint)convertToWorldSpace:(CGPoint)point { return CGPointApplyAffineTransform(point,self.nodeToWorldTransform); }
- (CGPoint)convertToNodeSpace:(CGPoint)point { return CGPointApplyAffineTransform(point,CGAffineTransformInvert(self.nodeToWorldTransform)); }
- (NSUInteger)numberOfRunningActions { return _actions.count; }
- (NSArray *)runningActions { return [_actions copy]; }
- (MRAction *)runAction:(MRAction *)action {
    NSParameterAssert(action);
    NSAssert(!action.target,@"An action instance can only run on one node at a time");
    [_actions addObject:action]; [self mrAdjustTimeWork:1]; [action startWithTarget:self]; return action;
}
- (void)stopAction:(MRAction *)action {
    if (![_actions containsObject:action]) return;
     [_actions removeObjectIdenticalTo:action]; [self mrAdjustTimeWork:-1]; [action stop];
}
- (MRAction *)actionByTag:(NSInteger)tag {
    for (MRAction *action in _actions) if (action.tag==tag) return action;
    return nil;
}
- (void)stopActionByTag:(NSInteger)tag { MRAction *action=[self actionByTag:tag]; if (action) [self stopAction:action]; }
- (void)stopAllActions {
    NSArray *saved=([_actions copy]); [_actions removeAllObjects];
    [self mrAdjustTimeWork:-(NSInteger)saved.count];
    for (MRAction *action in saved) [action stop];
}
- (void)advanceTime:(float)seconds {
    NSParameterAssert(isfinite(seconds) && seconds>=0);
    if (!_timeWork) return;
    if (!_actionsPaused && _actions.count) {
        NSArray *saved=([_actions copy]);
        for (MRAction *action in saved) {
            if (![_actions containsObject:action]) continue;
            [action step:seconds];
            if ([_actions containsObject:action] && action.isDone) [self stopAction:action];
        }
    }
    NSArray *children=self.children;
    // Read live work counts in the original snapshot order: an earlier callback
    // may start an action on a previously dormant later sibling in this tick.
    for (MRNode *child in children) if (child->_timeWork && child.parent==self) [child advanceTime:seconds];
}
- (void)visit:(MRRenderContext *)context {
    if (!_visible) return;
    [context pushTransform]; [context multiplyTransform:self.nodeToParentTransform];
    // Sorting a snapshot keeps visit safe when drawing detaches or reparents nodes.
    if (!_orderedChildren) _orderedChildren=[_children sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(MRNode *a,MRNode *b) {
        return a.zOrder<b.zOrder ? NSOrderedAscending : a.zOrder>b.zOrder ? NSOrderedDescending : NSOrderedSame;
    }];
    NSArray *ordered=_orderedChildren;
    NSUInteger i=0;
    for (;i<ordered.count;i++) { MRNode *child=ordered[i]; if (child.zOrder>=0) break; if (child.parent==self) [child visit:context]; }
    [self draw:context];
    for (;i<ordered.count;i++) { MRNode *child=ordered[i]; if (child.parent==self) [child visit:context]; }
    [context popTransform];
}
- (void)draw:(MRRenderContext *)context {}
@end
