#pragma once
#import "MRNode.h"
/// Axis-aligned device clipping of this node's transformed logical bounds,
/// intersected with every enclosing clip. Scene hierarchy remains unchanged.
@interface MRClipNode : MRNode
@end
