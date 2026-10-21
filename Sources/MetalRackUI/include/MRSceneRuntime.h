#pragma once
#import <UIKit/UIKit.h>
#import "MetalRackScene.h"
/// One application scene session, configured with the native platform host.
/// Owns resources/scene stack; it never creates or emulates a graphics context.
@interface MRSceneRuntime : NSObject
@property(nonatomic, readonly) MRSceneDriver *driver;
@property(nonatomic, readonly) MRRenderContext *context;
@property(nonatomic, readonly) MRSceneResources *resources;
@property(nonatomic, readonly) MRScheduler *scheduler;
@property(nonatomic, readonly) MRInput *input;
@property(nonatomic, readonly) CGSize winSize;
@property(nonatomic) CGFloat pixelsPerPoint;
@property(nonatomic) BOOL displayFPS;
@property(nonatomic, readonly, getter=isPaused) BOOL paused;
@property(nonatomic, copy) CGFloat (^atlasDensity)(NSString *name,NSDictionary *manifest);
- (void)registerTextAtlas:(MRTextAtlas *)atlas fontName:(NSString *)name horizontalInsetRatio:(CGFloat)ratio;
- (MRTextAtlas *)textAtlasNamed:(NSString *)name;
- (CGFloat)textInsetRatioForFont:(NSString *)name;
- (MRTexture *)loadAtlasNamed:(NSString *)name;
- (MRTexture *)loadAtlasNamed:(NSString *)name imageNamed:(NSString *)image pixelsPerPoint:(CGFloat)density;
- (MRTexture *)textureNamed:(NSString *)name;
- (void)removeImageNamed:(NSString *)name;
- (void)cacheImage:(UIImage *)image named:(NSString *)name;
@property(nonatomic, readonly) UIView *view;
@property(nonatomic, readonly) MRNode *runningScene;
@property(nonatomic, readonly, copy) NSArray<MRNode *> *sceneStack;
@property(nonatomic, copy) void (^runningChanged)(BOOL running);
+ (instancetype)sharedRuntime;
- (void)configureWithView:(UIView *)view driver:(MRSceneDriver *)driver baseURL:(NSURL *)baseURL pixelsPerPoint:(CGFloat)density;
- (void)runWithScene:(MRNode *)scene;
- (void)pushScene:(MRNode *)scene;
- (void)replaceScene:(MRNode *)scene;
- (void)popScene;
- (void)popSceneWithTransition:(Class)type duration:(MRTime)duration;
- (NSArray *)getSceneStack;
- (void)pause;
- (void)resume;
- (void)startAnimation;
- (void)stopAnimation;
- (void)end;
@end
