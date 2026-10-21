# Native MetalRack integration

MetalRackScene and MetalRackUI implement the scene path consumed by Gnomes.
There is no Cocos library, Cocos class tree, OpenGL import, legacy draw bridge,
legacy state emulator or MetalRackSceneSupport product in this package.
The original snapshot/quad rendering products remain source compatible.

## Ownership and API boundary

- MetalRackScene: scene hierarchy/lifecycle, affine geometry, stable z ordering,
  sprites/trim/rotation/density, atlas/resource ownership, actions, scheduling,
  Core Text glyph layout, pointer capture, clipping, geometric primitives,
  snapshots, outlines and material-region drawing.
- MetalRack: SceneRenderer converts native y-up scene points once at the GPU
  boundary and submits through QuadRenderer. SceneView owns the native-density
  drawable, display clock and UIKit pointer conversion.
- MetalRackUI (iOS): definition construction, native controls/panels/scrolling,
  system/painted text, transitions, Particle Designer simulation, audio and the
  service utilities consumed by Gnomes. Existing network/social adapters retain
  their SDK declarations; applications using those adapters supply the SDK
  implementations. No application artwork or content tables ship here.
- Application: launch/save/pause choices, UI design, fonts and atlas density,
  simulation, terrain/excavation rules, lighting formulas and material selection.

CPU action formulas and service/definition algorithms retain their original
licenses and provenance. Rendering is implemented with native MRNode/MRSprite,
MRRenderContext and Metal APIs. Merely copying or renaming Cocos is not used as a
rendering strategy. Native-Action-Provenance.json and Native-UI-Provenance.json
record the reusable inputs.

## Coordinates, resources and drawing

Scene geometry is y-up logical points. PNG pixels remain premultiplied RGBA with
top-row-first storage, without padding, filename-suffix probing or canvas resizing.
Callers provide pixelsPerPoint explicitly. Format-2 and format-3 TexturePacker
frames retain packed rotation, trim offset and original logical canvas geometry.
An explicit image URL supports manifests that do not name their texture.
Native frame crops operate in the untrimmed logical canvas.

Scene resources own named atlas frames and textures. Unloading an atlas removes
only its currently owned names; externally retained frames and explicit aliases
remain valid. Texture replacement versions backend images and regenerates opted-in
mipmaps. Deferred batches retain the texture version they sampled.

Snapshots preserve surrounding transforms, clips, targets and graph ownership.
Generic outline/halo operations operate on captured alpha. Material-region drawing
partitions one complete texture into disjoint regions; the application decides
which regions go before/after a prop. The renderer exposes native material hooks
for application lighting without embedding game formulas.

Core Text positions painted atlas glyphs using the supplied real font face,
reference em and finite glyph repertoire. Spaces retain advances, unsupported
fallback font runs remain unpainted, and bounds include complete painted canvases.
System text uses native font rasterization. Font/artwork choices stay with callers.

## Lifecycle, time and input

MRSceneDriver attaches a scene and optional overlay to an environment containing
the render context, scheduler and input router. Children inherit attachment.
Callbacks use weak node relays, suspend on exit and resume with timer accumulation
on reentry. Timers accept MRTime or no arguments; object callback ABIs are rejected.
Actions advance at priority zero before ordinary game timers. First action ticks,
sequence/instant boundaries, delay units and original-frame restoration are
preserved. Invisible nodes still advance actions.

Root adoption/promotion preserves lifecycle when wrapping/unwrapping transitions.
Transitions can complete safely before a new stack operation interrupts them.
The input router uses weak receivers, stable priorities, per-pointer capture and
conditional swallowing. Removal, disable, focus loss and scene changes cancel
captures without invoking an end activation. UIKit touch identity is converted
once into a stable native identifier. Standard drag layers track one pointer;
controls preserve selection, cancellation and disabled appearance.

SceneView has a weak clock proxy and the renderer has a weak view link. Hosts
explicitly start/stop the display clock; applications retain save and lifecycle
policy. MRSceneRuntime provides stack transitions, resources and optional FPS
presentation using the native overlay.

## Validation

The package suite passes 41 tests with actual Metal GPU readback: transforms,
painter order, trim/rotation/flips/crops, clips, premultiplied blending, outlines,
nested capture and texture versions, mipmaps/replacement, atlas transactions,
action/easing/frame timing, scheduler ordering, lifecycle/root adoption, timer
ownership, overlays, Core Text layout, pointer capture and callback cancellation.

Gnomes' separate native-asset suite passes four tests against installed artwork:
13 atlases / 529 frames, explicit-image manifests and format-2 fonts, exact rotated
cloud pixels (990×218, zero RGBA difference), and 102 Cooper layout cases.
The iOS game links only native scene/UI APIs. Simulator validation covers visible
actor galleries, text, lighting/particles, contact shadows, ladder travel and
ingredient delivery/save restoration. Application-specific acceptance evidence
and baseline comparisons are retained with the Gnomes migration review.
