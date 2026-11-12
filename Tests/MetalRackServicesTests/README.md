# Native service verification

`swift test -j 2` checks the established MD5 identifier format against independent
published vectors, alongside the renderer/scene/action tests. MD5 remains only
for the existing server identifier format; it is not purchase verification.

The StoreKit flow in `StoreTests.swift` is intentionally an **app-hosted** XCTest,
compiled outside SwiftPM. The host must carry `get-task-allow`; unsigned builds
are rejected by StoreKit's local test service as not installed for development.
It uses the bundled `Store.storekit`, disables purchase dialogs and resets the
local test session afterward. No real purchases are made.

The Gnomes consumer provides `Tests/NativeMetal/compiler_services.py` to generate
an ignored, disposable Xcode test project around its existing app. It updates an
existing idle simulator in place. The caller must back up Documents, Preferences
and Library/Application Support/GnomeSave*.plist and restore them afterward.
The same host verifies actual AVAudioPlayer effects and WKWebView callbacks.

The hosted StoreKit checks cover product lookup/invalid IDs, verified delivery,
unfinished delivery while the application is not ready, replay after readiness,
direct-result/update deduplication, pending approval, failed purchases and
cancellation. Pending/failed/cancelled purchases must grant no currency. The
shared service has a single observer owner; independent service instances cannot
race to deliver the same purchase.

`python3 Tests/HTTPRequests/run.py` compiles the actual Foundation request source
with warnings as errors and tests a loopback HTTP server: exact form/save bytes,
UTF-8 escaping, declared and omitted response encodings, redirects, synchronous
completion, queued main-thread callbacks and transport errors.
