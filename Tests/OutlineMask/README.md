# Exact outline performance

`python3 Tests/OutlineMask/check.py [--report result.json]` compiles the current
C implementation and the published pre-change implementation, then compares
5,700 byte-exact cases across Debug and optimized builds. Cases cover all 3×3
silhouettes, alpha 127/128, empty/solid rows, single-row/column canvases, radii
larger than the canvas, internal holes and a large furniture-like silhouette.
The final case also benchmarks median thread CPU time over nine calls.

The production algorithm computes the nearest horizontal solid pixel for each
row using left/right sweeps. A transparent output pixel belongs to the ring iff
some source row has `horizontalDistance² + verticalDistance² <= radius²`.
This is the same integer disk and alpha threshold as the original two-dimensional
neighborhood search, with no blur, averaging, changed padding or approximation.
Empty rows have an explicit sentinel and cannot create spurious seeds. Empty,
solid and zero-radius canvases return the already-cleared output immediately.
Temporary storage is one integer per source pixel, released before returning;
allocation failure retains the original exact calculation.

The existing Swift `OutlineTests` independently compare every output pixel with
nearest Euclidean silhouette distance and check internal-hole contours:
`swift test --filter OutlineTests`.
