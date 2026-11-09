# Native sprite submission — November 8, 2026

`SceneRenderer.enqueueNative` appends converted vertices directly to the last
compatible batch when adjacent coalescing is enabled. It avoids constructing a
transient vertex array and Batch for every sprite. When a new batch is needed,
its array is initialized once. Destination storage remains Swift-owned and
retained Batch snapshots preserve array value semantics. Empty and non-triangle
submissions preserve the existing enqueue boundaries.

Native samplers are cached by the four binary filter/address choices and the
effective mipmapping flag. The 32-entry cache uses exactly the previous mapping
(nearest versus linear, repeat versus clamp, linear mipmapping only when the
texture has mip levels and the min filter is linear). Public sampler lookup and
arbitrary Metal sampling configurations remain unchanged.

Painter order, material/attribute, texture identity, both blend factors, sampler,
clip and logical-size boundaries are unchanged. No game policy or lighting rule
moves into the renderer. No new public API is required.

`NativeSubmissionTests` verifies all native sampler combinations on first and
cached lookup, retained Batch value semantics, triangle boundaries, each render
state boundary, exact vertex conversion and exact GPU readback parity with
uncoalesced submission. The package suite passes 53 tests on Apple Silicon.

Matched Debug simulator captures in Gnomes show sampler and Collection.map
hot-path samples disappear, with native enqueue falling from 43.85% to 27.79% of
all CPU samples. Average process CPU fell from 49.26% to 42.27% of one core. These
are simulator observations, not physical-device benchmarks or wall-clock timing
per function. Separate off-page recipe artwork allocation remained a UI opening
cost and is addressed in Gnomes rather than in this shared package.
