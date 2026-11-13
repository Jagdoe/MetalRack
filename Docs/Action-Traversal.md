# Dormant action subtree traversal — November 12, 2026

A physical Gnomes trace attributed 58.37% of CPU samples to MRNode.advanceTime,
including branches consisting entirely of static terrain/UI nodes. The old clock
recursed through every node and loaded each weak parent every display tick,
regardless of whether that subtree owned any actions.

MRNode now keeps a subtree work count updated on action additions/removals and
hierarchy changes. The clock skips subtrees with no work and avoids weak-parent
loads for dormant children. Active actions retain their timing, first-tick,
pause, cancellation and iteration order. Custom advanceTime overrides are
recognized during initialization and remain continuously tickable without
requiring an action. No explicit caller registration or public API change.

Children are still read from the original immutable snapshot in insertion order;
work counts are checked live at each child. This deliberately preserves a callback
starting an action on a previously dormant later sibling during the same tick.
New children attached after the snapshot wait until the next parent tick, as
before. Detached children are excluded. Scene-root adoption and promotion update
subtree ownership without interrupting active descendants.

Tests cover same-tick activation, callback mutation, reparenting, stop/restart,
paused ancestors, custom clocks and scene-root transitions, alongside the existing
native action, scheduler, input, geometry and pixel-comparison suite. A synthetic
10,000-dormant-node/one-active-node benchmark logs traversal time; it is not a
whole-application CPU or physical-device thermal measurement. The actual game
still needs native visual and workload profiling after public integration.
