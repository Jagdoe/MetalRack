#import "MRClipNode.h"
@implementation MRClipNode
- (void)visit:(MRRenderContext *)context {
    if(!self.visible || self.contentSize.width<=0 || self.contentSize.height<=0)return;
    [context pushTransform];[context multiplyTransform:self.nodeToParentTransform];
    [context pushClipRect:(CGRect){CGPointZero,self.contentSize}];[context popTransform];
    if(!CGRectIsEmpty(context.clipRect))[super visit:context];
    [context popClipRect];
}
@end
