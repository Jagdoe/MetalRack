#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import "MRUIKit.h"
#import <zlib.h>
// Particle Designer numeric integration follows the original engine's Euler
// order, lifetime, variances and radius formulas. Rendering is native scene
// triangles: no batch-node, GL buffer or graphics-state dependency.
typedef struct {
    CGPoint position,origin,velocity;
    float ttl,size,sizeDelta,rotation,rotationDelta,radial,tangential;
    float radius,radiusDelta,angle,angular,elapsed;
    NSUInteger frame;
    MRColor4F color,colorDelta;
} MRLiveParticle;
static float MRPVar(float value,float variance) {return value+variance*MRRandomSigned();}
static float MRPClamp(float v) {return MAX(0,MIN(1,v));}
static MRColor4F MRPColor(MRColor4F c,MRColor4F v) {return MRRGBAFloat(MRPClamp(MRPVar(c.r,v.r)),MRPClamp(MRPVar(c.g,v.g)),MRPClamp(MRPVar(c.b,v.b)),MRPClamp(MRPVar(c.a,v.a)));}
static MRBlendFactor MRPBlend(NSInteger factor) {
    switch(factor){case 0:return MRBlendZero;case 1:return MRBlendOne;
        case 768:return MRBlendSourceColor;case 769:return MRBlendOneMinusSourceColor;
        case 770:return MRBlendSourceAlpha;case 771:return MRBlendOneMinusSourceAlpha;
        case 772:return MRBlendDestinationAlpha;case 773:return MRBlendOneMinusDestinationAlpha;
        case 774:return MRBlendDestinationColor;case 775:return MRBlendOneMinusDestinationColor;
        case 776:return MRBlendSourceAlphaSaturated;default:NSCAssert(NO,@"Unsupported particle blend factor %ld",(long)factor);return MRBlendOne;}
}
@implementation MRParticles {
    NSMutableData *_particles;
    float _elapsed,_emitCounter;
    MRSprite *_drawSprite;
}
+ (instancetype)particleWithFile:(NSString *)file {return [[self alloc]initWithFile:file];}
- (instancetype)initWithFile:(NSString *)file {
    NSDictionary *dictionary=[NSDictionary dictionaryWithContentsOfFile:[MRBundleResources pathForResource:file]];
    NSAssert(dictionary,@"Missing particle definition %@",file);return [self initWithDictionary:dictionary];
}
- (instancetype)initWithTotalParticles:(NSUInteger)count {
    if((self=[super init])){
        _totalParticles=count;_particles=[NSMutableData dataWithLength:count*sizeof(MRLiveParticle)];
        _active=YES;_duration=-1;_positionType=MRParticlePositionFree;
        _startScale=_endScale=1;_blendFunc=(MRBlendFunction){MRBlendOne,MRBlendOneMinusSourceAlpha};
        _drawSprite=[MRSprite new];[self scheduleUpdateWithPriority:1];
    }return self;
}
- (instancetype)initWithDictionary:(NSDictionary *)d {
    if((self=[self initWithTotalParticles:[d[@"maxParticles"] unsignedIntegerValue]])){
#define MRP_READ(property,key) self.property=[d[@key] floatValue]
        MRP_READ(angle,"angle");MRP_READ(angleVar,"angleVariance");MRP_READ(duration,"duration");
        MRP_READ(startSize,"startParticleSize");MRP_READ(startSizeVar,"startParticleSizeVariance");MRP_READ(endSize,"finishParticleSize");MRP_READ(endSizeVar,"finishParticleSizeVariance");
        MRP_READ(startSpin,"rotationStart");MRP_READ(startSpinVar,"rotationStartVariance");MRP_READ(endSpin,"rotationEnd");MRP_READ(endSpinVar,"rotationEndVariance");
        MRP_READ(speed,"speed");MRP_READ(speedVar,"speedVariance");MRP_READ(radialAccel,"radialAcceleration");MRP_READ(radialAccelVar,"radialAccelVariance");MRP_READ(tangentialAccel,"tangentialAcceleration");MRP_READ(tangentialAccelVar,"tangentialAccelVariance");
        MRP_READ(startRadius,"maxRadius");MRP_READ(startRadiusVar,"maxRadiusVariance");MRP_READ(endRadius,"minRadius");MRP_READ(rotatePerSecond,"rotatePerSecond");MRP_READ(rotatePerSecondVar,"rotatePerSecondVariance");
        MRP_READ(life,"particleLifespan");MRP_READ(lifeVar,"particleLifespanVariance");
        if([d[@"version"] intValue]==2){MRP_READ(startScale,"startScale");MRP_READ(startScaleVar,"startScaleVar");MRP_READ(endScale,"endScale");MRP_READ(endScaleVar,"endScaleVar");}
#undef MRP_READ
        _emitterMode=[d[@"emitterType"] integerValue];NSAssert(_emitterMode==MRParticleModeGravity||_emitterMode==MRParticleModeRadius,@"Invalid particle mode");
        self.position=MRPoint([d[@"sourcePositionx"] doubleValue],[d[@"sourcePositiony"] doubleValue]);
        _posVar=MRPoint([d[@"sourcePositionVariancex"] doubleValue],[d[@"sourcePositionVariancey"] doubleValue]);
        _gravity=MRPoint([d[@"gravityx"] doubleValue],[d[@"gravityy"] doubleValue]);
        MRColor4F *colors[]={&_startColor,&_startColorVar,&_endColor,&_endColorVar};
        NSArray *prefixes=@[@"startColor",@"startColorVariance",@"finishColor",@"finishColorVariance"];
        for(NSUInteger i=0;i<4;i++){NSString *prefix=prefixes[i];*colors[i]=MRRGBAFloat([d[[prefix stringByAppendingString:@"Red"]] floatValue],[d[[prefix stringByAppendingString:@"Green"]] floatValue],[d[[prefix stringByAppendingString:@"Blue"]] floatValue],[d[[prefix stringByAppendingString:@"Alpha"]] floatValue]);}
        _emissionRate=_totalParticles/_life; // A zero lifespan intentionally produces an immediate burst.
        _blendFunc=(MRBlendFunction){MRPBlend([d[@"blendFuncSource"] integerValue]),MRPBlend([d[@"blendFuncDestination"] integerValue])};
        NSString *name=d[@"textureFileName"];NSError *error=nil;
        _texture=[[MRSceneRuntime sharedRuntime].resources textureAtURL:[NSURL fileURLWithPath:[MRBundleResources pathForResource:name]] error:&error];
        if(!_texture){
            NSData *packed=[[NSData alloc]initWithBase64EncodedString:d[@"textureImageData"] ?: @"" options:NSDataBase64DecodingIgnoreUnknownCharacters];
            z_stream stream={0};stream.next_in=(Bytef *)packed.bytes;stream.avail_in=(uInt)packed.length;
            int status=inflateInit2(&stream,15+32);NSMutableData *decoded=[NSMutableData data];
            if(status==Z_OK){do{uint8_t block[16384];stream.next_out=block;stream.avail_out=sizeof(block);status=inflate(&stream,Z_NO_FLUSH);[decoded appendBytes:block length:sizeof(block)-stream.avail_out];}while(status==Z_OK);inflateEnd(&stream);}
            UIImage *image=status==Z_STREAM_END ? [UIImage imageWithData:decoded] : nil;
            NSAssert(image,@"Cannot decode particle image %@",name);
            _texture=[[MRTexture alloc]initWithContext:[MRSceneRuntime sharedRuntime].context image:image.CGImage error:&error];
            if(_texture)[[MRSceneRuntime sharedRuntime].resources cacheTexture:_texture atURL:[NSURL fileURLWithPath:[MRBundleResources pathForResource:name]]];
        }
        NSAssert(_texture,@"Missing native particle texture %@: %@",name,error);
    }return self;
}
- (void)setTotalParticles:(NSUInteger)count {if(count*sizeof(MRLiveParticle)>_particles.length)[_particles setLength:count*sizeof(MRLiveParticle)];_totalParticles=count;}
- (BOOL)isFull {return _particleCount>=_totalParticles;}
- (void)setBlendAdditive:(BOOL)additive {_blendFunc=additive?(MRBlendFunction){MRBlendSourceAlpha,MRBlendOne}:(MRBlendFunction){MRBlendOne,MRBlendOneMinusSourceAlpha};}
- (BOOL)blendAdditive {return _blendFunc.dst==MRBlendOne;}
- (void)stopSystem {_active=NO;_elapsed=_duration;_emitCounter=0;}
- (void)resetSystem {_active=YES;_elapsed=0;MRLiveParticle *p=_particles.mutableBytes;for(NSUInteger i=0;i<_particleCount;i++)p[i].ttl=0;}
- (void)updateWithNoTime {[self update:0];}
- (void)spawn:(MRLiveParticle *)p {
    *p=(MRLiveParticle){0};p->ttl=MAX(0,MRPVar(_life,_lifeVar));
    p->position=MRPoint(MRPVar(_sourcePosition.x,_posVar.x),MRPVar(_sourcePosition.y,_posVar.y));
    p->origin=_positionType==MRParticlePositionFree?[self convertToWorldSpace:CGPointZero]:self.position;
    p->color=MRPColor(_startColor,_startColorVar);MRColor4F end=MRPColor(_endColor,_endColorVar);
    float inv=p->ttl>0?1/p->ttl:0;
    p->colorDelta=MRRGBAFloat((end.r-p->color.r)*inv,(end.g-p->color.g)*inv,(end.b-p->color.b)*inv,(end.a-p->color.a)*inv);
    BOOL animated=_animation.frames.count>0;
    p->size=MAX(0,MRPVar(animated?_startScale:_startSize,animated?_startScaleVar:_startSizeVar));
    float target=animated?_endScale:_endSize;
    p->sizeDelta=target==-1?0:(MAX(0,MRPVar(target,animated?_endScaleVar:_endSizeVar))-p->size)*inv;
    p->rotation=MRPVar(_startSpin,_startSpinVar);p->rotationDelta=(MRPVar(_endSpin,_endSpinVar)-p->rotation)*inv;
    float a=MRDegreesToRadians(MRPVar(_angle,_angleVar));
    p->velocity=MRPointScale(MRPointForAngle(a),MRPVar(_speed,_speedVar));
    p->radial=MRPVar(_radialAccel,_radialAccelVar);p->tangential=MRPVar(_tangentialAccel,_tangentialAccelVar);
    p->radius=MRPVar(_startRadius,_startRadiusVar);p->radiusDelta=_endRadius==-1?0:(MRPVar(_endRadius,_endRadiusVar)-p->radius)*inv;
    p->angle=a;p->angular=MRDegreesToRadians(MRPVar(_rotatePerSecond,_rotatePerSecondVar));
    if(animated && (_animationType==MRParticleAnimationRandomStart||_animationType==MRParticleAnimationRandomFrame))p->frame=roundf(MRRandomUnit()*(_animation.frames.count-1));
}
- (void)update:(MRTime)dt {
    NSParameterAssert(isfinite(dt)&&dt>=0);
    if(_active && _emissionRate){float interval=1/_emissionRate;_emitCounter+=dt;
        while(_particleCount<_totalParticles && _emitCounter>interval){MRLiveParticle *p=_particles.mutableBytes;[self spawn:&p[_particleCount++]];_emitCounter-=interval;}
        _elapsed+=dt;if(_duration!=-1 && _duration<_elapsed)[self stopSystem];}
    if(!self.visible)return;
    MRLiveParticle *p=_particles.mutableBytes;
    for(NSUInteger i=0;i<_particleCount;){MRLiveParticle *v=&p[i];v->ttl-=dt;
        if(v->ttl<=0){p[i]=p[--_particleCount];continue;}
        if(_emitterMode==MRParticleModeGravity){CGPoint radial=MRPointScale(MRPointNormalize(v->position),v->radial);CGPoint tangent=MRPointNormalize(v->position);tangent=MRPointScale(MRPoint(-tangent.y,tangent.x),v->tangential);v->velocity=MRPointAdd(v->velocity,MRPointScale(MRPointAdd(_gravity,MRPointAdd(radial,tangent)),dt));v->position=MRPointAdd(v->position,MRPointScale(v->velocity,dt));}
        else{v->angle+=v->angular*dt;v->radius+=v->radiusDelta*dt;v->position=MRPoint(-cos(v->angle)*v->radius,-sin(v->angle)*v->radius);}
        v->color.r+=v->colorDelta.r*dt;v->color.g+=v->colorDelta.g*dt;v->color.b+=v->colorDelta.b*dt;v->color.a+=v->colorDelta.a*dt;
        v->size=MAX(0,v->size+v->sizeDelta*dt);v->rotation+=v->rotationDelta*dt;
        if(_animation.frames.count && _animationType!=MRParticleAnimationRandomFrame){v->elapsed+=dt;float frameTime=_animation.frames[v->frame].delayUnits*_animation.delayPerUnit;
            if(v->elapsed>=frameTime){v->elapsed-=frameTime;if(v->frame+1<_animation.frames.count)v->frame++;else if(_animationType!=MRParticleAnimationOnce)v->frame=0;}}
        i++;
    }
    if(!_particleCount && _autoRemoveOnFinish && !_active)[self removeFromParentAndCleanup:YES];
}
- (void)draw:(MRRenderContext *)context {
    if(!_particleCount || (!_texture&&!_animation.frames.count))return;
    MRLiveParticle *particles=_particles.mutableBytes;NSMutableData *data=[NSMutableData dataWithCapacity:_particleCount*6*sizeof(MRRenderVertex)];
    MRTexture *texture=nil;
    CGPoint current=_positionType==MRParticlePositionFree?[self convertToWorldSpace:CGPointZero]:self.position;
    for(NSUInteger i=0;i<_particleCount;i++){
        MRLiveParticle *p=&particles[i];MRSpriteFrame *frame=_animation.frames.count?_animation.frames[p->frame].spriteFrame:nil;
        if(!frame)frame=[[MRSpriteFrame alloc]initWithTexture:_texture pixelRect:(CGRect){CGPointZero,_texture.pixelSize} originalSize:_texture.pixelSize trimOffset:CGPointZero pixelsPerPoint:1 rotated:NO];
        if(texture && texture!=frame.texture){[context drawVertices:data.bytes count:data.length/sizeof(MRRenderVertex) texture:texture.identifier blend:_blendFunc sampling:_drawSprite.sampling];[data setLength:0];}
        texture=frame.texture;_drawSprite.frame=frame;
        _drawSprite.position=_positionType==MRParticlePositionGrouped?p->position:MRPointSub(p->position,MRPointSub(current,p->origin));
        _drawSprite.scaleX=_animation.frames.count?p->size:p->size/frame.originalSize.width;
        _drawSprite.scaleY=_animation.frames.count?p->size:p->size/frame.originalSize.height;
        _drawSprite.rotation=p->rotation;_drawSprite.color=MRRGB(MRPClamp(p->color.r)*255,MRPClamp(p->color.g)*255,MRPClamp(p->color.b)*255);_drawSprite.opacity=MRPClamp(p->color.a)*255;
        MRRenderVertex vertices[6];NSUInteger count=[_drawSprite writeLocalVertices:vertices];CGAffineTransform transform=_drawSprite.nodeToParentTransform;
        for(NSUInteger j=0;j<count;j++){CGPoint point=CGPointApplyAffineTransform(MRPoint(vertices[j].x,vertices[j].y),transform);vertices[j].x=point.x;vertices[j].y=point.y;}[data appendBytes:vertices length:count*sizeof(MRRenderVertex)];
    }
    if(data.length)[context drawVertices:data.bytes count:data.length/sizeof(MRRenderVertex) texture:texture.identifier blend:_blendFunc sampling:_drawSprite.sampling];
}
@end
#endif
