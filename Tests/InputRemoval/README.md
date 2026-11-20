# Never-registered node removal

An actual Gnomes speed8 slowdown sample followed timer-label teardown through
MRNode.detachFromEnvironment into MRInput.removeReceiver. Every glyph scanned
all registered weak receivers even though it had never accepted input.

MRInput now keeps a weak, pointer-identity history of receivers added to that
input instance. Never-registered nodes return immediately. Positive lookups use
the original ordered-array/capture removal path without modification. History
is not removed on unregister: cancellation callbacks can re-register receivers,
and retaining the weak history preserves that reentrant behavior. Receivers and
scenes remain unowned. Equal-but-distinct objects remain distinct weak keys.

Validation: `swift test --filter NativeInputTests` passes seven tests covering
priority/stable ties, swallowing, independent pointers, focus cancellation,
callback mutation, weak lifetime, never-registered removal and equal-object
identity. The fixed benchmark (10,000 negative removals / 200 registered
receivers) measured 43.740ms before and 3.194ms after in Debug on this host.
These are illustrative timings, not a test threshold or whole-game FPS claim.

Scene callback scheduling was audited: MRNodeScheduling already traverses only
its own registered callbacks when detaching. No scheduler behavior was changed.
