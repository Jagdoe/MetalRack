# Modal button ownership

MRButton registers with native input independently of MRLayer. Disabling a
covered layer alone does not disable its buttons. Begin/move/end now enforce the
active MRPlacementScene modal subtree; a captured gesture covered mid-sequence
is canceled. Passive layout/dimmer layers remain valid button containers.
No button enabled state is rewritten, and newly created covered buttons are
also excluded.

Run `python3 Tests/ModalButtonInput/check.py`. This compiles the actual production
ownership predicate and checks ordinary, nested, covered, dynamic and restored
controls. iOS integration in Gnomes used actual native pointer dispatch:
`--excavation-review --wardrobe-cancel-review` reproduced Cancel reopening the
dialog before this fix, then passed repeated swatch/Cancel taps without charge
or unlock. Existing `--cash-confirmation-input-review` also passed real Cancel,
reopen and Buy with one charge.
