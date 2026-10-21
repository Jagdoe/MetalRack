#import "MRAtlas.h"
#include <math.h>
NSString *const MRAtlasErrorDomain=@"MetalRack.Scene.Atlas";
static BOOL MRAtlasError(NSError **error,NSString *message) {
    if (error) *error=[NSError errorWithDomain:MRAtlasErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
    return NO;
}
static BOOL MRGeometry(id text,NSUInteger count,CGFloat *numbers) {
    if (![text isKindOfClass:[NSString class]]) return NO;
    NSRegularExpression *expression=[NSRegularExpression regularExpressionWithPattern:@"[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?" options:0 error:NULL];
    NSArray *matches=[expression matchesInString:text options:0 range:NSMakeRange(0,[text length])];
    if (matches.count!=count) return NO;
    for (NSUInteger i=0;i<count;i++) {
        numbers[i]=[[text substringWithRange:[matches[i] range]] doubleValue];
        if (!isfinite(numbers[i])) return NO;
    }
    return YES;
}
@implementation MRAtlas {
    NSMutableDictionary *_frames;
}
- (void)setFrame:(MRSpriteFrame *)frame named:(NSString *)name { NSParameterAssert(frame && name.length); _frames[name]=frame; }
- (instancetype)init { if ((self=[super init])) _frames=[NSMutableDictionary new]; return self; }

- (NSDictionary *)frames { return ([_frames copy]); }
- (MRSpriteFrame *)frameNamed:(NSString *)name { return _frames[name]; }
- (void)removeFrameNamed:(NSString *)name {[_frames removeObjectForKey:name];}
- (void)removeAllFrames { [_frames removeAllObjects]; }
- (BOOL)addFramesFromDictionary:(NSDictionary *)dictionary texture:(MRTexture *)texture pixelsPerPoint:(CGFloat)density error:(NSError **)error {
    if (!texture || !isfinite(density) || density<=0) return MRAtlasError(error,@"Atlas requires a texture and positive density");
    NSDictionary *metadata=dictionary[@"metadata"], *frames=dictionary[@"frames"];
    if (![metadata isKindOfClass:[NSDictionary class]] || ![frames isKindOfClass:[NSDictionary class]])
        return MRAtlasError(error,@"Atlas metadata and frames must be dictionaries");
    NSInteger format=[metadata[@"format"] integerValue];
    if (format!=2 && format!=3)
        return MRAtlasError(error,@"Expected a TexturePacker format-2 or format-3 frame dictionary");
    NSMutableDictionary *pending=[NSMutableDictionary dictionary], *aliases=[NSMutableDictionary dictionary];
    for (id name in frames) {
        NSDictionary *entry=frames[name];
        if (![name isKindOfClass:[NSString class]] || ![entry isKindOfClass:[NSDictionary class]]) return MRAtlasError(error,@"Invalid atlas frame entry");
        CGFloat r[4],s[2],o[2],trimmed[2];
        BOOL rotated=[entry[format==3?@"textureRotated":@"rotated"] boolValue];
        if(format==3) {
            if (!MRGeometry(entry[@"textureRect"],4,r) || !MRGeometry(entry[@"spriteSourceSize"],2,s) ||
                !MRGeometry(entry[@"spriteOffset"],2,o) || !MRGeometry(entry[@"spriteSize"],2,trimmed))
                return MRAtlasError(error,[NSString stringWithFormat:@"Invalid geometry for %@",name]);
        } else {
            if(!MRGeometry(entry[@"frame"],4,r)||!MRGeometry(entry[@"sourceSize"],2,s)||!MRGeometry(entry[@"offset"],2,o))
                return MRAtlasError(error,[NSString stringWithFormat:@"Invalid geometry for %@",name]);
            trimmed[0]=r[2];trimmed[1]=r[3];
            if(rotated){CGFloat width=r[2];r[2]=r[3];r[3]=width;}
        }
        CGRect rect=CGRectMake(r[0],r[1],r[2],r[3]);
        if (r[2]<=0 || r[3]<=0 || s[0]<=0 || s[1]<=0 || !CGRectContainsRect((CGRect){CGPointZero,texture.pixelSize},rect) ||
            trimmed[0]!=(rotated ? r[3]:r[2]) || trimmed[1]!=(rotated ? r[2]:r[3]))
            return MRAtlasError(error,[NSString stringWithFormat:@"Out-of-bounds or inconsistent geometry for %@",name]);
        MRSpriteFrame *frame=([[MRSpriteFrame alloc] initWithTexture:texture pixelRect:rect originalSize:CGSizeMake(s[0]/density,s[1]/density)
            trimOffset:CGPointMake(o[0]/density,o[1]/density) pixelsPerPoint:density rotated:rotated]);
        pending[name]=frame;
        id names=entry[@"aliases"];
        if (names && ![names isKindOfClass:[NSArray class]]) return MRAtlasError(error,@"Frame aliases must be an array");
        for (id alias in names) {
            if (![alias isKindOfClass:[NSString class]]) return MRAtlasError(error,@"Frame aliases must be strings");
            aliases[alias]=frame;
        }
    }
    // Failure above leaves the previously installed atlas untouched.
    [aliases addEntriesFromDictionary:pending]; [_frames addEntriesFromDictionary:aliases];
    return YES;
}
@end
