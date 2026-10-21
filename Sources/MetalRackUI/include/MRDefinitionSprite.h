//
//  C2DSprite.h
//  Zombie
//
//  Created by Michael Scandizzo on 6/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRUIKit.h"

// C2DSprite Defs options:
// -----------------------
// image                    .png or reference to another entry
// icon definition          reference to another entry to use as a sprite
// anchor                   { <0.0-1.0>, <0.0-1.0> }
// color                    color name from colors.plist
// scale
// phone scale              Alternate scale to us on phone
// flip x
// can flip x
// particle                 name for particle system file
// particle only            sprite requires no image
// particle anchor
// particle z offest
// particle rotation
// attachment
// decal                    Array of simple, attached sub-objects
// ignore parent color
// color children
// Color Tags               Dictionary of colors for each child tag
// Parameters               Dictionary of user-defined values

// animation                Array of animation frame files
// motion                   Dictionary entry:
//      motion                   "rock", "wiggle", or "wobble"
//      motion amount            used by "rock", "wiggle", or "wobble"
//      motion speed             used by "rock", "wiggle", or "wobble"
// rock from                angle, used by "rock"
// rock to                  angle, used by "rock"
// rock time                used by "rock"
// hop height               used by "hop"
// hop time                 used by "hop"
// interval time            used by animation

// C2DSprite SUB-OBJECT Defs options:
// ----------------------------------
// tag
// rotation
// rotation range
// type                     class to use if image is a .png.


#ifndef __IPHONE_OS_VERSION_MAX_ALLOWED

typedef enum {
    UISRTextAlignmentLeft = 0,
    UISRTextAlignmentCenter,
    UISRTextAlignmentRight,                   // could add justified in future
} UISRTextAlignment;

#endif

@class MRTextLabel;
@interface MRDefinitionSprite : MRSprite
{
	NSString		*tagString;

	// Lists of attached sub-objects
	NSMutableArray	*m_aAttachments;
	NSMutableArray	*m_aDecals;

    // Keep track of our default scale.
    float           m_flScaleDefault;

	// Optional "playable" animation
	NSMutableArray	*m_aAnimationFrames;

	CGSize			m_sizeHitTestOverride;
	NSDictionary	*m_dictDef;
	NSDictionary	*m_dictDisplayDef;

	// Should we color our children when we get colored?
	BOOL			m_fColorChidren;
	BOOL			m_fIgnoreParentColor;
    MRColor3B               m_colorBase;
    NSMutableDictionary     *m_dictColorTints;

	// Text / labels.
	MRTextLabel			*m_label;
	MRColor3B		m_colorText;
	BOOL			labelVisible;

	// Definition stuff -- keep a reference to our def name.
	NSString		*m_strDefinition;
	BOOL			m_fIconOnly;		// Descendents should only be C2DSprites
	BOOL			m_fHidden;

	// Normal particles for visuals
	MRParticles * m_particleSystem;
	float m_flParticleRotation;
	MRColor3B  m_colorDefault;

    // Tag to identify this object to its parent
    NSString        *m_strSubObjectTag;

    // Assorted parameters.
    NSMutableDictionary *m_dictParams;

    // Allow aliasing of texture
    BOOL            m_fAliasTexture;

    CGPoint         m_positionInWorldCached;
    BOOL            m_fUseCulling;
}

@property (readonly)            float           flScaleDefault;
@property (readonly)			NSMutableArray	*m_aAttachments;
@property (readonly)			NSMutableArray	*m_aDecals;
@property (readonly, strong)	NSDictionary	*m_dictDef;
@property (readonly)            NSDictionary    *m_dictDisplayDef;
@property (readonly)			NSString		*m_strDefinition;
@property (readwrite)			BOOL			m_fIconOnly;
@property (readwrite)			BOOL			m_fHidden;
@property (readonly)			MRParticles *m_particleSystem;
@property(nonatomic, setter=setLabelVisible:)	BOOL	labelVisible;
@property (readonly)            NSString        *m_strSubObjectTag;
@property (assign, setter=allowAliasing:)       BOOL            m_fAliasTexture;
@property (assign, setter=useCulling:)          BOOL            m_fUseCulling;
@property(nonatomic, copy, setter=setTagText:)	NSString	*tagString;
@property (assign, setter=setIgnoreParentColor:) BOOL m_fIgnoreParentColor;

// Static functions

+ (void)setWindowWidth:(float)flWidth andHeight:(float)flHeight;
+ (MRSpriteFrame *)getSpriteFrameFromName:(NSString*)strName;
+ (MRSpriteFrame *)getSpriteFrameFromDefinition:(NSDictionary *)dictDef;
+ (MRSpriteFrame *)getSpriteFrameFromDefinition:(NSDictionary *)dictDef withVariation:(int)nVariation;
+ (CGSize)getContentSizeFromDefinition:(NSDictionary *)dictDef;
+ (id)createFromDefinition:(NSDictionary *)dictDef;
+ (id)createFromDefName:(NSString*)strDef;
+ (id)createIconFromDefinition:(NSDictionary *)dictDef;
+ (id)createFromDefOrFrameName:(NSString *)strDefOrName;
+ (id)createOutlineFromSprite:(MRSprite *)sprSource;
+ (id)createOutlineFromDef:(NSDictionary *)dictDef;
+ (id)createFromClassDefinition:(NSDictionary *)dictDef;
+ (id)createFromClassDefName:(NSString*)strDef;
+ (id)createFromClassDefOrFrameName:(NSString *)strDefOrName;

// Initiailization
- (void)initFromDefinition:(NSDictionary *)dictDef;
- (void)setDisplayDefinition:(NSDictionary *)dictNew;
- (void)setDefinitionString:(NSString*)strDefinition;
- (void)setDefinition:(NSDictionary*)dictDef;
- (NSString*)getTypeName;

// Animations
- (void)wobble:(NSDictionary *)dictDef;
- (void)spinFast;
- (void)helperParseMotion:(NSDictionary *)dictDef;
- (void)playAnimation;
- (void)playAnimationForever;
- (void)rockAnimation;
- (void)hopAnimation;
- (void)scream:(float)flY;
- (void)scream:(float)flY toScale:(float)flScale withDuration:(float)flDuration withDelay:(float)flDelay;
- (void)screamDiagonally:(float)flY atX:(float)flX;
- (void)animateBubbleIn;

// Sub-objects
- (void)initFromSubObjectDefinition:(NSDictionary *)dictSubObjectDef;
- (void)addSubObject:(MRDefinitionSprite*)sprItem withOffset:(CGPoint)ptOffset withRotation:(float)flRotation withZ:(float)flZ;
- (id)createSubObject:(NSDictionary *)dictDef forList:(NSMutableArray *)aList;
- (id)createAttachment:(NSDictionary *) dictAttachment;
- (id)createDecal:(NSDictionary *) dictDecal;
- (NSArray *)findAllDecalsByTag:(NSString *)strTag;
- (void)addAttachment:(id)bodyAttachment;
- (void)removeAttachment:(id)idAttachment;
- (void)removeDecal:(id)idDecal;
- (id)getAttachmentParent;
- (void)removeAttachmentFromParent;
- (void)intervalAnimateDecals:(MRTime)deltaTime;
- (void)intervalAnimateAttachments:(MRTime)deltaTime;

// Text & labels.
- (void)setTextColor:(MRColor3B)color;
- (MRTextLabel*)setText:(NSString *)strText;
- (MRTextLabel*)setText:(NSString *)strText atPosition:(CGPoint)Position;
- (MRTextLabel*)setText:(NSString *)strText atPosition:(CGPoint)Position withAlignment:(UITextAlignment)alignment;
- (void)setLabelVisible:(BOOL)fVisible;

// Acessors.
- (CGPoint)getWorldPosition;
- (CGPoint)getCenter;
- (float)getWorldRotation;
- (float)getWorldScale;
- (void)setDefaultScale:(float)flScale;
- (MRSpriteFrame *)getSpriteFrame;

// Colors
- (void)setColorTint:(MRColor3B)colorTint forTag:(NSString *)strTag;
- (void)removeColorTintForTag:(NSString *)strTag;
- (void)setColorChildren:(BOOL)fColorChildren;
- (void)setDefaultColor:(MRColor3B)color;
- (void)restoreToDefaultColor;

// ContentSize and Bounding Box
-(void) setHitTestOverrideSize:(CGSize)size;
- (void)constrainToSize:(CGSize)sizeMax;
- (CGPoint)getAdjustedAnchorForAnchor:(CGPoint)ptOriginal;
- (CGSize) transformedSize;
- (CGRect) recursiveBoundingBox;

// Parameter stuff
- (void)addParamValue:(id)idValue forKey:(NSString*)strKey;
- (void)addParamValuesFromDict:(NSDictionary*)dictValues;
- (id)getParamValueForKey:(NSString*)strKey;

// Particle system
- (MRParticles*)setParticleSystem:(NSString*)strParticleSystem;
- (void)removeParticleSystem;
- (void)removeChildParticles;

// Compatibility with C2DCullLayer
- (BOOL)hitTest:(MRPointerEvent *)touch;
- (void)updateWorldPositionCache;

// Clean-up stuff.
- (void)suicide;

@end
