//
//  C2DDragObject.h
//  Zombie
//
//  Created by Michael Scandizzo on 6/5/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRUIKit.h"
#import "MRDefinitionSprite.h"

@interface MRDragObject : MRDefinitionSprite
{
	NSDictionary *m_dictItem;
	NSString	 *m_strItem;
}

//+ (id)createFromDefinition:(NSDictionary *)dictDef;
- (void)initFromDefinition:(NSDictionary *)dictDef;

- (NSDictionary*)getDefinition;

@end
