#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DLayerCull.m
//  Fingerzilla
//
//  Created by Michael Scandizzo on 7/6/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MRCullLayer.h"
#import "MRDefinitionSprite.h"

@implementation MRCullLayer

- (void)addChild:(MRNode *)node z:(NSInteger)z tag:(NSInteger)tag
{
    [super addChild:node z:z tag:tag];
    if ([node isKindOfClass:[MRDefinitionSprite class]] == YES)
    {
        MRDefinitionSprite *sprNode = (MRDefinitionSprite *)node;
        [sprNode useCulling:YES];
        [sprNode updateWorldPositionCache];
    }
}

- (void)removeChild:(MRNode *)node cleanup:(BOOL)cleanup
{
    if ([node isKindOfClass:[MRDefinitionSprite class]] == YES)
    {
        MRDefinitionSprite *sprNode = (MRDefinitionSprite *)node;
        [sprNode useCulling:NO];
    }
    [super removeChild:node cleanup:cleanup];
}

- (void)visit:(MRRenderContext *)context {
    for (MRDefinitionSprite *child in self.children)
        if ([child isKindOfClass:[MRDefinitionSprite class]]) [child updateWorldPositionCache];
    [super visit:context];
}

@end

#endif
