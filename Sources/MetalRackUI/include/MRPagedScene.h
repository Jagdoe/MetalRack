//
//  PagedScene.h
//  Befuddled2
//
//  Created by Michael Scandizzo on 3/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRScrollScene.h"

@interface MRPagedScene : MRScrollScene
{
    int     m_nPages;
    float   m_flPageSize;
    MRNode  *m_nodePageDots;
    SEL     m_selOnChanged;
    int     m_nCurrentPage;
}

@property (assign) SEL selOnChanged;

- (void)setPageSize:(float)flPageSize;
- (void)setPageCount:(int)nPages;

- (void)updatePageDots:(int)nPage;
- (void)gotoPage:(int)nPage;
- (int)getCurrentPage;
- (id)createPageDots:(int)nPageCount;

@end
