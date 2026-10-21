//
//  CGPointOb.h
//  Soap Rack
//
//  Created by Tom Ricket on 11/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

// Note: This cannot be "CGPointObject" or it conflicts with a CCParallax item.

#import <Foundation/Foundation.h>

@interface MRPointValue : NSObject <NSCoding>
{
    CGPoint m_ptPoint;
}

@property   CGPoint     ptPoint;    // with m_

+(MRPointValue*) CGPointObWithPoint:(CGPoint)ptPoint;

-(id)initWithPoint:(CGPoint)ptPoint;

@end
