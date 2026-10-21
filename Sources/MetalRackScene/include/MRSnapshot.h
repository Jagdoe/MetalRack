#pragma once
#import "MRSprite.h"

/// Captures a subtree in its parent's logical coordinates without changing its
/// transforms, actions or ownership. Pixel rows use the ordinary top-down order.
FOUNDATION_EXPORT MRTexture *MRCaptureNodes(NSArray<MRNode *> *nodes, MRRenderContext *context, CGRect bounds, CGFloat pixelsPerPoint);
FOUNDATION_EXPORT MRTexture *MRCaptureNode(MRNode *node, MRRenderContext *context, CGRect bounds, CGFloat pixelsPerPoint);
/// Creates a centered binary outside-silhouette ring, including attached sprites
/// and interior holes. Styling belongs to the caller. The node is not mutated.
FOUNDATION_EXPORT MRSprite *MRCreateNodeOutline(MRNode *node, MRRenderContext *context,
                                             CGPoint center, CGFloat pixelsPerPoint, CGFloat thickness);
/// White alpha silhouette and a coverage-weighted outside halo. Both preserve
/// the source graph and use explicit capture density, like ordinary snapshots.
FOUNDATION_EXPORT MRSprite *MRCreateNodeSilhouette(MRNode *node,MRRenderContext *context,CGRect bounds,CGFloat pixelsPerPoint);
FOUNDATION_EXPORT MRSprite *MRCreateNodeHalo(MRNode *node,MRRenderContext *context,CGPoint center,CGFloat pixelsPerPoint,CGFloat thickness,NSUInteger neighborLimit,uint8_t alphaPerNeighbor);
