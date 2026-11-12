# Compiler cleanup and native services — November 12, 2026

This release follows the published native UI lineage at `9de8a79`. It does not
change the canonical MetalRack main checkout or move existing consumers' pins.
Gnomes must validate and publish this release before adopting its revision.

The UI headers use NSTextAlignment and declare actual existing selector APIs
once. Native callback invocation uses method signatures, avoiding ARC's unknown
performSelector return-ownership assumptions. Collection indices and ephemeral
request identities retain their platform width; file sizes use 64-bit values.

MRAudio loads and prepares the same CAF effects with AVAudioPlayer. Replaying an
effect restarts its existing player. The existing global gain, per-definition
multiplier and voice ducking still apply to all active effects; music and voice
continue using their existing AVAudioPlayer paths. The unused OpenAL sources
remain locally preserved and are excluded from this release's target.

MRHTTPRequest replaces the UI service's ASI operations with NSURLSession. It
preserves the server's form representation, including NSData.description for
compressed saves, escaping and Latin-1 fallback when responses omit a charset.
The existing queue remains serial, callbacks return on the main thread, and the
suspension-save path waits synchronously on a private NSURLSession queue.
MRFileCache uses the same request implementation on its existing worker threads.
The service base now uses HTTPS, which the existing host supports, so the native
transport observes ATS without weakening application transport policy.

StoreKit 2 product requests return MRStoreResponse / MRStoreProduct. Existing
in-app callback selectors now receive MRStoreTransaction; consumers read its
productIdentifier directly. Only verified, unrevoked transactions are delivered.
Delivery runs on the main actor, before finish(); pending, failed and cancelled
purchases do not grant content. One singleton owns transaction observation.
Direct results, update events and unfinished replays share delivery tracking.
Verified receipts remain pending in memory when the application is not ready,
and retry when the callback is installed again; StoreKit's unfinished sequence
also recovers transactions across launches. Product/transaction identifiers and
the game's reward quantities are unchanged.

The established MD5 server/device identifier format uses CryptoKit's supported
Insecure.MD5 API. It is not a security check or StoreKit verification. Independent
hash vectors verify byte identity. UIKit alerts, text measurement and Game Center
calls use current platform APIs while retaining the corresponding actions.

Validation: `swift test -j 2`; `python3 Tests/HTTPRequests/run.py`; the app-hosted
StoreKit, WebKit and sound checks described in
[service tests](../Tests/MetalRackServicesTests/README.md); and clean native Gnomes
Debug/Release builds with packaged-sprite validation. External Facebook accounts
and the old service's server-side behavior require their own live configuration;
local tests exercise platform callbacks and the retained wire protocol.

## Clients without cloud or social services

`OPTIONS_USE_CLOUD` defaults to YES, preserving existing clients. A client may
explicitly pass NO to skip cloud initialization and its delayed startup ping.
The cloud request entry points also return before creating or queuing requests
when disabled. Local preferences, StoreKit, reachability, audio and rendering
remain independent. Facebook options retain their existing defaults.

The Facebook implementation is an optional client-supplied provider, resolved
by class name when social login is enabled. Applications that still opt in and
link their SDK retain their existing provider/callback path; applications without
social login no longer need to compile/link the Facebook SDK to use MetalRackUI.
