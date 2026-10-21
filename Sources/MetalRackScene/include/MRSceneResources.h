#pragma once
#import "MRAtlas.h"

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString *const MRSceneResourceErrorDomain;
/// File-backed native scene assets. Paths and atlas density are explicit;
/// there is no filename suffix probing or scene-coordinate scale adjustment.
@interface MRSceneResources : NSObject
@property(nonatomic, readonly, strong) MRRenderContext *context;
@property(nonatomic, readonly, copy) NSURL *baseURL;
- (instancetype)initWithContext:(MRRenderContext *)context baseURL:(NSURL *)baseURL;
- (nullable MRTexture *)textureAtURL:(NSURL *)url error:(NSError **)error;
- (nullable MRTexture *)textureNamed:(NSString *)name error:(NSError **)error;
- (BOOL)addAtlasAtURL:(NSURL *)url pixelsPerPoint:(CGFloat)density error:(NSError **)error;
- (BOOL)addAtlasAtURL:(NSURL *)url imageURL:(nullable NSURL *)imageURL pixelsPerPoint:(CGFloat)density error:(NSError **)error;
- (BOOL)addAtlasNamed:(NSString *)name pixelsPerPoint:(CGFloat)density error:(NSError **)error;
- (nullable MRSpriteFrame *)frameNamed:(NSString *)name;
/// Externally retained textures/frames remain valid until their owners release them.
- (void)removeAllResources;
- (void)removeAtlasAtURL:(NSURL *)url;
- (void)removeCachedTexture:(MRTexture *)texture;
- (void)setFrame:(MRSpriteFrame *)frame named:(NSString *)name;
- (void)cacheTexture:(MRTexture *)texture atURL:(NSURL *)url;
- (void)removeCachedImageAtURL:(NSURL *)url;
@end
NS_ASSUME_NONNULL_END
