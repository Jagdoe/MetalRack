# Repeating actions after catch-up — November 18, 2026

MRRepeatForever advanced its inner interval, then restarted it only once when
that update crossed the duration. If one update spanned many cycles, the
restarted interval still held elapsed time far beyond its duration. Subsequent
normal frames sampled t=1 repeatedly while slowly subtracting one duration per
frame. Balanced oscillations therefore looked completely frozen; a new action
at an arrival or pose change appeared to repair them.

The repeat now consumes every completed cycle and retains only the partial
cycle. Whole cycles are executed, preserving relative movement and callback
counts rather than dropping them with modulo arithmetic. The interval's initial
zero tick remains unchanged. A callback stopping the repeat ends catch-up
immediately. Zero/epsilon-duration cycles remain bounded to once per update.
There is no new API, timer domain, game state or artwork policy.

NativeActionTests reproduce the former frozen oscillation after two 20-second
steps, verify immediate movement on the next ordinary frame, assert accumulated
relative translation plus fractional remainder, and check callback cancellation
and zero-duration loops. Existing first-tick, pause, reverse/easing, ownership,
node traversal, scheduler and rendering tests remain unchanged.
