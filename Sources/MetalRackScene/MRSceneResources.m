#import "MRSceneResources.h"
#import <ImageIO/ImageIO.h>
NSString *const MRSceneResourceErrorDomain=@"MetalRack.Scene.Resources";
static void MRResourceError(NSError **error,NSInteger code,NSString *message) {
    if (error) *error=[NSError errorWithDomain:MRSceneResourceErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:message}];
}
@implementation MRSceneResources {
    NSMutableDictionary<NSURL *,MRTexture *> *_textures;
    MRAtlas *_atlas;
    NSMutableDictionary *_atlasRecords;
}
- (void)removeCachedTexture:(MRTexture *)texture { for(NSURL *key in [_textures.allKeys copy])if(_textures[key]==texture)[_textures removeObjectForKey:key]; }
- (void)removeAtlasAtURL:(NSURL *)url {
    NSURL *key=url.URLByStandardizingPath.absoluteURL;NSDictionary *frames=_atlasRecords[key];
    for(NSString *name in frames)if([_atlas frameNamed:name]==frames[name])[_atlas removeFrameNamed:name];
    [_atlasRecords removeObjectForKey:key];
}
- (void)setFrame:(MRSpriteFrame *)frame named:(NSString *)name { [_atlas setFrame:frame named:name]; }
- (void)cacheTexture:(MRTexture *)texture atURL:(NSURL *)url { NSParameterAssert(texture.context==_context && url.isFileURL); _textures[url.URLByStandardizingPath.absoluteURL]=texture; }
- (void)removeCachedImageAtURL:(NSURL *)url { [_textures removeObjectForKey:url.URLByStandardizingPath.absoluteURL]; }
- (instancetype)initWithContext:(MRRenderContext *)context baseURL:(NSURL *)baseURL {
    NSParameterAssert(context && baseURL.isFileURL);
    if ((self=[super init])) {
        _context=context; _baseURL=[baseURL copy];
        _textures=[NSMutableDictionary new]; _atlas=[MRAtlas new];_atlasRecords=[NSMutableDictionary new];
    }
    return self;
}
- (MRTexture *)textureAtURL:(NSURL *)url error:(NSError **)error {
    if (!url.isFileURL) { MRResourceError(error,1,@"Scene textures require a file URL"); return nil; }
    NSURL *key=url.URLByStandardizingPath.absoluteURL;
    MRTexture *texture=_textures[key];
    if (texture) return texture;
    CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)key,NULL);
    CGImageRef image=source ? CGImageSourceCreateImageAtIndex(source,0,NULL) : NULL;
    if (source) CFRelease(source);
    if (!image) { MRResourceError(error,2,[NSString stringWithFormat:@"Cannot decode scene image %@",key.path]); return nil; }
    texture=[[MRTexture alloc] initWithContext:_context image:image error:error];
    CGImageRelease(image);
    if (texture) _textures[key]=texture;
    return texture;
}
- (MRTexture *)textureNamed:(NSString *)name error:(NSError **)error {
    return [self textureAtURL:[_baseURL URLByAppendingPathComponent:name] error:error];
}
- (BOOL)addAtlasAtURL:(NSURL *)url pixelsPerPoint:(CGFloat)density error:(NSError **)error {
    return [self addAtlasAtURL:url imageURL:nil pixelsPerPoint:density error:error];
}
- (BOOL)addAtlasAtURL:(NSURL *)url imageURL:(NSURL *)explicitImageURL pixelsPerPoint:(CGFloat)density error:(NSError **)error {
    if (!url.isFileURL) { MRResourceError(error,1,@"Scene atlases require a file URL"); return NO; }
    NSData *data=[NSData dataWithContentsOfURL:url options:0 error:error];
    if (!data) return NO;
    id value=[NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:error];
    if (!value) return NO;
    NSDictionary *manifest=[value isKindOfClass:[NSDictionary class]] ? value : nil;
    NSDictionary *metadata=[manifest[@"metadata"] isKindOfClass:[NSDictionary class]] ? manifest[@"metadata"] : nil;
    NSString *filename=metadata[@"textureFileName"];
    if (!explicitImageURL && (![filename isKindOfClass:[NSString class]] || !filename.length)) {
        MRResourceError(error,3,@"Atlas metadata must name its texture file"); return NO;
    }
    NSURL *imageURL=explicitImageURL ?: [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:filename].URLByStandardizingPath.absoluteURL;
    imageURL=imageURL.URLByStandardizingPath.absoluteURL;
    BOOL cached=_textures[imageURL]!=nil;
    MRTexture *texture=[self textureAtURL:imageURL error:error];
    if (!texture) return NO;
    if (![_atlas addFramesFromDictionary:manifest texture:texture pixelsPerPoint:density error:error]) {
        if (!cached) [_textures removeObjectForKey:imageURL];
        return NO;
    }
    [self removeAtlasAtURL:url];NSMutableDictionary *frames=[NSMutableDictionary new];
    for(NSString *name in manifest[@"frames"]){MRSpriteFrame *frame=[_atlas frameNamed:name];if(frame)frames[name]=frame;
        for(NSString *alias in manifest[@"frames"][name][@"aliases"]){MRSpriteFrame *a=[_atlas frameNamed:alias];if(a)frames[alias]=a;}}
    _atlasRecords[url.URLByStandardizingPath.absoluteURL]=frames;
    return YES;
}
- (BOOL)addAtlasNamed:(NSString *)name pixelsPerPoint:(CGFloat)density error:(NSError **)error {
    return [self addAtlasAtURL:[_baseURL URLByAppendingPathComponent:name] pixelsPerPoint:density error:error];
}
- (MRSpriteFrame *)frameNamed:(NSString *)name { return [_atlas frameNamed:name]; }
- (void)removeAllResources { [_atlasRecords removeAllObjects];[_atlas removeAllFrames]; [_textures removeAllObjects]; }
@end
