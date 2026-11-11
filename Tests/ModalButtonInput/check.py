#!/usr/bin/env python3
"""Compile the production modal-ownership predicate against a minimal node tree."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[2]
source=(root/'Sources/MetalRackUI/Implementation/MRButton.m').read_text()
a=source.index('static BOOL MRButtonBelongsToActiveModal(')
b=source.index('\n@implementation MRButton',a)
helper=source[a:b]
code=r'''#import <Foundation/Foundation.h>
@interface MRNode:NSObject
@property(weak) MRNode *parent;
@end
@implementation MRNode @end
@interface MRLayer:MRNode @end
@implementation MRLayer @end
@interface MRPlacementScene:MRNode
@property MRLayer *modal;
-(MRLayer*)getActiveChildModalLayer;
@end
@implementation MRPlacementScene
-(MRLayer*)getActiveChildModalLayer{return self.modal;}
@end
/*PRODUCTION*/
int main(){@autoreleasepool{
 MRPlacementScene *scene=[MRPlacementScene new];MRLayer *wardrobe=[MRLayer new];wardrobe.parent=scene;
 MRNode *card=[MRNode new];card.parent=wardrobe;MRNode *swatch=[MRNode new];swatch.parent=card;
 NSCAssert(MRButtonBelongsToActiveModal(swatch),@"Ordinary buttons work without a modal");
 scene.modal=wardrobe;NSCAssert(MRButtonBelongsToActiveModal(swatch),@"Nested controls in the active modal work");
 MRLayer *dialog=[MRLayer new];dialog.parent=scene;scene.modal=dialog;
 MRLayer *passive=[MRLayer new];passive.parent=dialog;MRNode *cancel=[MRNode new];cancel.parent=passive;
 NSCAssert(!MRButtonBelongsToActiveModal(swatch),@"Covered swatch is rejected");
 NSCAssert(MRButtonBelongsToActiveModal(cancel),@"Confirmation control remains usable through passive layout layers");
 MRNode *dynamic=[MRNode new];dynamic.parent=card;
 NSCAssert(!MRButtonBelongsToActiveModal(dynamic),@"New controls behind a modal are rejected without snapshots");
 MRLayer *nested=[MRLayer new];nested.parent=scene;scene.modal=nested;
 NSCAssert(!MRButtonBelongsToActiveModal(cancel),@"A second modal covers the first");
 scene.modal=dialog;NSCAssert(MRButtonBelongsToActiveModal(cancel),@"Closing nested modal restores previous modal eligibility");
 scene.modal=wardrobe;NSCAssert(MRButtonBelongsToActiveModal(swatch),@"Cancel restores the original wardrobe");
 puts("MODAL_BUTTON_OWNERSHIP_PASS nested=1 covered=1 dynamic=1 passiveContainers=1 restore=1");
}}
'''.replace('/*PRODUCTION*/',helper)
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'main.m').write_text(code)
 subprocess.run(['clang','-fobjc-arc','-framework','Foundation',str(p/'main.m'),'-o',str(p/'check')],check=True)
 subprocess.run([str(p/'check')],check=True)
assert '!MRButtonBelongsToActiveModal(self)' in source[source.index('- (BOOL)pointerBegan:'):]
assert source.count('[self pointerCancelled:touch]; return;')>=2
