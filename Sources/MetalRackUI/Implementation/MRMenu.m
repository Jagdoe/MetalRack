#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import "MRUIKit.h"
@interface MRMenuItem ()
@property(nonatomic, weak) id target;
@property(nonatomic) SEL selector;
@property(nonatomic, strong) MRSystemText *label;
@property(nonatomic) CGFloat selectionScale;
@property(nonatomic) BOOL selected;
- (void)selectItem:(BOOL)selected;
@end
@implementation MRMenuItem
- (instancetype)init {if((self=[super init])){_isEnabled=YES;_color=MRRGB(255,255,255);_opacity=255;self.anchorPoint=CGPointMake(.5,.5);}return self;}
- (void)activate {id target=_target; if(_isEnabled && [target respondsToSelector:_selector]){void(*call)(id,SEL,id)=(void *)[target methodForSelector:_selector];call(target,_selector,self);}}
- (void)setColor:(MRColor3B)color {_color=color;_label.color=_isEnabled?color:MRRGB(128,128,128);}
- (void)setIsEnabled:(BOOL)enabled {_isEnabled=enabled;_label.color=enabled?_color:MRRGB(128,128,128);if(!enabled)[self selectItem:NO];}
- (void)selectItem:(BOOL)selected {
    if(_selected==selected)return;
    if(selected)_selectionScale=self.scale;
    _selected=selected;[self stopActionByTag:NSIntegerMax];
    MRAction *action=[MRScaleTo actionWithDuration:.1 scale:_selectionScale*(selected?1.2:1)];action.tag=NSIntegerMax;[self runAction:action];
}
- (void)setOpacity:(uint8_t)opacity {_opacity=opacity;_label.opacity=opacity;}
@end
@implementation MRMenuItemText
static NSString *MRMenuFont=@"Marker Felt";
static CGFloat MRMenuFontSize=32;
+ (void)setFontName:(NSString *)name {MRMenuFont=[name copy];}
+ (void)setFontSize:(CGFloat)size {MRMenuFontSize=size;}
+ (instancetype)itemFromString:(NSString *)text target:(id)target selector:(SEL)selector {
    MRMenuItemText *item=[self new];item.target=target;item.selector=selector;
    item.label=[MRSystemText labelWithString:text fontName:MRMenuFont fontSize:MRMenuFontSize];
    item.contentSize=item.label.contentSize;item.label.anchorPoint=CGPointZero;[item addChild:item.label];return item;
}
@end
@implementation MRMenu {
    __weak MRMenuItem *_selected;
    NSUInteger _pointer;
    BOOL _tracking;
}
+ (instancetype)menuWithItems:(MRMenuItem *)first,... {
    MRMenu *menu=[self new];va_list args;va_start(args,first);
    for(MRMenuItem *item=first;item;item=va_arg(args,MRMenuItem *))[menu addChild:item];va_end(args);return menu;
}
- (instancetype)init {
    if((self=[super init])){self.isTouchEnabled=YES;self.inputPriority=-128;self.swallowsPointers=YES;
        CGSize size=[MRSceneRuntime sharedRuntime].winSize;self.position=CGPointMake(size.width*.5,size.height*.5);}
    return self;
}
- (void)alignItemsVertically {[self alignItemsVerticallyWithPadding:5];}
- (void)alignItemsVerticallyWithPadding:(CGFloat)padding {
    CGFloat height=-padding;for(MRNode *item in self.children)height+=item.contentSize.height*fabs(item.scaleY)+padding;
    CGFloat y=height*.5;for(MRNode *item in self.children){CGFloat h=item.contentSize.height*fabs(item.scaleY);item.position=CGPointMake(0,y-h*.5);y-=h+padding;}
}
- (void)alignItemsHorizontally {[self alignItemsHorizontallyWithPadding:5];}
- (void)alignItemsHorizontallyWithPadding:(CGFloat)padding {
    CGFloat width=-padding;for(MRNode *item in self.children)width+=item.contentSize.width*fabs(item.scaleX)+padding;
    CGFloat x=-width*.5;for(MRNode *item in self.children){CGFloat w=item.contentSize.width*fabs(item.scaleX);item.position=CGPointMake(x+w*.5,0);x+=w+padding;}
}
- (MRMenuItem *)itemAt:(MRPointerEvent *)event {
    if(!self.visible)return nil;
    for(MRNode *ancestor=self.parent;ancestor;ancestor=ancestor.parent)if(!ancestor.visible)return nil;
    for(MRMenuItem *item in [self.children reverseObjectEnumerator])if([item isKindOfClass:[MRMenuItem class]] && item.isEnabled && item.visible && CGRectContainsPoint((CGRect){CGPointZero,item.contentSize},[event locationInNode:item]))return item;
    return nil;
}
- (BOOL)pointerBegan:(MRPointerEvent *)event {
    if(_tracking)return NO;_selected=[self itemAt:event];if(!_selected)return NO;
    _tracking=YES;_pointer=event.identifier;[_selected selectItem:YES];return YES;
}
- (void)pointerMoved:(MRPointerEvent *)event {
    if(!_tracking || event.identifier!=_pointer)return;
    MRMenuItem *next=[self itemAt:event];if(next==_selected)return;
    [_selected selectItem:NO];_selected=next;[_selected selectItem:YES];
}
- (void)pointerEnded:(MRPointerEvent *)event {
    if(!_tracking || event.identifier!=_pointer)return;
    MRMenuItem *selected=_selected;[_selected selectItem:NO];_selected=nil;_tracking=NO;
    if(selected==[self itemAt:event])[selected activate];
}
- (void)pointerCancelled:(MRPointerEvent *)event {
    if(!_tracking || event.identifier!=_pointer)return;[_selected selectItem:NO];_selected=nil;_tracking=NO;
}
@end
#endif
