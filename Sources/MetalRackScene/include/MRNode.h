#pragma once
#import "MRRenderContext.h"

@class MRAction, MRSceneEnvironment;

/// A painter-ordered, logical-point scene tree. Coordinates are y-up; texture
/// pixels and GPU presentation are handled independently by the backend.
@interface MRNode : NSObject
@property(nonatomic, readonly, weak) MRSceneEnvironment *environment;
@property(nonatomic, readonly, getter=isInScene) BOOL inScene;
/// Driver-owned scene attachment. Children automatically inherit attachment.
- (void)attachToEnvironment:(MRSceneEnvironment *)environment;
- (void)detachFromEnvironment;
- (void)didEnterScene;
- (void)willExitScene;
- (void)willBeginSceneTransition;
- (void)didFinishSceneTransition;
- (void)cleanup;
@property(nonatomic, assign) CGPoint position;
@property(nonatomic, assign) CGPoint anchorPoint;
@property(nonatomic, assign) CGSize contentSize;
@property(nonatomic, assign) CGFloat rotation;
@property(nonatomic, assign) CGFloat scaleX;
@property(nonatomic, assign) CGFloat scaleY;
@property(nonatomic, assign) CGFloat skewX;
@property(nonatomic, assign) CGFloat skewY;
@property(nonatomic, assign) BOOL visible;
@property(nonatomic, assign) BOOL ignoresAnchorPointForPosition;
@property(nonatomic, assign) NSInteger zOrder;
@property(nonatomic, readonly, weak) MRNode *parent;
@property(nonatomic, readonly, copy) NSArray<MRNode *> *children;
@property(nonatomic, readonly) CGRect subtreeBounds;
/// Actual drawable canvases and child geometry in local points, independent of
/// temporary visibility/opacity. Empty containers do not add a phantom canvas.
@property(nonatomic, readonly) CGRect paintedBounds;
@property(nonatomic, readonly) CGRect localDrawBounds;
@property(nonatomic, readonly) CGAffineTransform nodeToParentTransform;
@property(nonatomic, readonly) CGAffineTransform nodeToWorldTransform;
@property(nonatomic, readonly) CGAffineTransform worldToNodeTransform;
- (void)addChild:(MRNode *)child;
- (void)addChild:(MRNode *)child z:(NSInteger)z;
- (void)addChild:(MRNode *)child z:(NSInteger)z tag:(NSInteger)tag;
- (void)removeChild:(MRNode *)child;
- (void)removeChild:(MRNode *)child cleanup:(BOOL)cleanup;
- (void)removeAllChildrenWithCleanup:(BOOL)cleanup;
- (void)removeFromParentAndCleanup:(BOOL)cleanup;
@property(nonatomic, assign) NSInteger tag;
@property(nonatomic, assign) CGFloat scale;
@property(nonatomic, readonly) CGRect boundingBox;
+ (instancetype)node;
- (MRNode *)getChildByTag:(NSInteger)tag;
- (void)reorderChild:(MRNode *)child z:(NSInteger)z;
- (void)removeFromParent;
- (CGPoint)convertToWorldSpace:(CGPoint)point;
- (CGPoint)convertToNodeSpace:(CGPoint)point;
@property(nonatomic, assign) BOOL actionsPaused;
@property(nonatomic, readonly) NSUInteger numberOfRunningActions;
@property(nonatomic, readonly, copy) NSArray<MRAction *> *runningActions;
- (MRAction *)runAction:(MRAction *)action;
- (void)stopAction:(MRAction *)action;
- (void)stopActionByTag:(NSInteger)tag;
- (MRAction *)actionByTag:(NSInteger)tag;
- (void)stopAllActions;
/// Tick this tree once before visiting it. First-tick and sequence boundaries
/// retain the game's existing interval-action timing.
- (void)advanceTime:(float)seconds;
- (void)visit:(MRRenderContext *)context;
/// Subclasses submit local geometry. Negative-z children precede this call;
/// nonnegative-z children follow it, with insertion order resolving equal z.
- (void)draw:(MRRenderContext *)context;
@end
