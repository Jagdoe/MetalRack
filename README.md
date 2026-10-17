# MetalRack

Read the [architecture and project-agnostic usage analysis](Docs/Architecture_and_Usage.md) for the rendering flow, API contracts, integration examples, ownership boundaries and current limitations.

Local Swift package shared by ZombieSwift and Rocket. Requires iOS 17+ or macOS 14+, and a Metal device. Add `.package(path: "../MetalRack")` and depend on the `MetalRack` product, or add the local package in Xcode.

## Ownership

The package contains no game assets, gameplay types, HUD layout, room/printer/robot rules, or application launch policy.

- `QuadRenderer` is the single textured triangle rendering core. Its shader, premultiplied blending, inline uploads, aligned reusable triple buffers, capacity growth and GPU completion synchronization serve both games. The allocator and pipeline were extracted from ZombieSwift; synchronization and sprite/atlas facilities incorporate Rocket's improvements.
- `SpriteRenderer` builds stable, ordered batches from `SpriteSnapshot`, performs conservative culling, aspect-fit placement and aspect-fill backgrounds, then submits through `QuadRenderer`. Its DEBUG macOS capture path uses that same core.
- `SpriteTextureLibrary` caches textures and resolves optional caller-selected atlases and additional namespaced atlases. Pass the artwork bundle explicitly when resources are outside the main app bundle. `TextureUpload` handles decoded CGImage upload for either platform.
- `SceneViewport` is the shared top-left coordinate transform for rendering and hit testing. It does not decide which objects are clickable.
- `LineRenderer` retains the original animated Bezier tick algorithm. Its platform-neutral API accepts a texture resolver and tick size. `LineRenderer+UIKit` adapts an injected UIImage loader. Tick asset names are supplied by the client.
- `PreviewRenderer` retains the diagnostic triangle scene on either platform. UIKit-gated `ImageLibrary`, `SpriteImage` and `EffectSprite` retain reusable SwiftUI image/effect integration. Application controls and their artwork stay in the game.

ZombieSwift's `ZombieSwiftApp/Rendering` owns its gameplay snapshot, world/HUD geometry, sprite/effect selection, text and Cooper atlas policy, debug measurements, legacy controls, interaction layers and view configuration. Its `GameplayRenderer` is a command adapter to `QuadRenderer`; it has no independent sprite shader or GPU vertex allocator. The adapter retains existing batching and texture/text caches and calls the package's shared image uploader. Its line wrapper supplies the game image loader.

Rocket owns `RocketScene`, native input views, window/orientation configuration, art, atlas preparation scripts, room reconstruction/tint/shadows, printer animation and robot behavior. It uses `SpriteRenderer` directly. There is no Rocket renderer copy or vendored Legacy directory.

## Usage

```swift
import MetalRack
let renderer = try SpriteRenderer(bundle: .main, atlasResource: "Atlas")
renderer.makeSnapshot = { delta in
    // Advance the application's simulation and return its generic frame.
    scene.snapshot(advancingBy: delta)
}
metalView.device = renderer.device
metalView.delegate = renderer
```

For custom game geometry, create `QuadRenderer(device:)`, call `beginFrame(commandBuffer:)` once, then `encode(texture:vertices:viewportSize:encoder:)` for each ordered batch. Vertex colors and texture pixels must be premultiplied. Use one renderer serially with one command queue, and commit every command buffer passed to `beginFrame`; the completion handler releases the frame slot. `TextureUpload` produces compatible textures. Clients retain responsibility for device identity, render-pass configuration, encoder lifetime and presentation.

## Shader resources

`Resources/QuadShaders.txt` is copied individually to the SwiftPM resource bundle root and read through `Bundle.module`, then compiled with `MTLDevice.makeLibrary(source:)` at runtime. It intentionally is not an automatically compiled `.metal` resource: the offline Metal compiler toolchain is absent in the validation environment. App artwork is loaded from the caller's bundle, independently of the package shader bundle. The diagnostic preview shader is also compiled at runtime.

## Validation

Run `swift test --package-path ../MetalRack` from either game. The tests cover aspect-fit round trips, empty viewports and real GPU readback of premultiplied blending with inline uploads, frame-ring reuse and uploads that grow buffers beyond the initial capacity. Metal must be available; GPU tests fail rather than silently skipping renderer verification.

Run `Tools/verify_rendering.sh` from Rocket for application-scene GPU captures and interaction/animation checks. It links against the actual built package object and supplies SwiftPM's resource bundle directory to the standalone executable. Application builds automatically embed the package resource bundle.

See `../ZombieSwift/Docs/Shared_MetalRack_Migration.md` for the verified build/run matrix and remaining platform limitations.

The shader is copied as a file rather than as a folder named `Resources`, avoiding
an ambiguous bundle layout that fails Xcode iOS code signing. The loader also
accepts the older nested location. This packaging fix changes no rendering APIs,
shader contents or application policy.
