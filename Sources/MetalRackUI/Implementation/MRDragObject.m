#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DDragObject.m
//  Zombie
//
//  Created by Michael Scandizzo on 6/5/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRDragObject.h"


@implementation MRDragObject

//+ (id)createWithSprite:(CCSprite *)sprOriginal
//{
//	CCTexture2D *texture = [sprOriginal texture];
//	CGRect rect = sprOriginal.textureRect;
//	CGPoint offset = sprOriginal.offsetPosition;
//	CCSpriteFrame *frame = [CCSpriteFrame frameWithTexture:texture rect:rect offset:offset];
//	C2DDragObject *dragOb = [C2DDragObject spriteWithSpriteFrame:frame];
//	dragOb.scale = 1.3f;
//	return dragOb;
//}

//+ (id)createFromDefinition:(NSDictionary *)dictDef
//{
//	NSString *strImage = [dictDef objectForKey:@"image"];
//	CCSpriteFrame *frame = [[MRSceneRuntime sharedRuntime].resources frameNamed:strImage];
//	NSAssert1(frame != nil, @"ERROR: invalid image file %@.", strImage);
//	C2DDragObject *dragNew = [C2DDragObject spriteWithSpriteFrame:frame];
//	[dragNew initFromDefinition:dictDef];
//
//	// Remove animations so we can drag properly
//	[dragNew stopAllActions];
//	return dragNew;
//}

- (void)initFromDefinition:(NSDictionary *)dictDef
{
	m_fIconOnly = YES;
	[super initFromDefinition:dictDef];
	self.scale = 1.3f;
	m_dictItem = dictDef;
}

- (NSDictionary*)getDefinition
{
	return m_dictItem;
}

@end

#endif
