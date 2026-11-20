# Rotation start target

MRRotateTo must read the current rotation after its superclass assigns the new
target. Previously its local target pointer was captured before that assignment;
a newly started or stopped/reused action therefore sampled nil as zero degrees.
This caused nonzero bind angles to snap at the first tick and incorrect blends.

NativeActionTests.testRotateToStartsFromCurrentTargetAngleIncludingReuse fails
four assertions before the change and passes afterward. It checks first tick
and midpoint from +25 degrees, then reuses the stopped action on a second node
starting at -30. The existing shortest-arc formula and other actions are unchanged.
An audit of every startWithTarget override found no other pre-super target reads.

Run: swift test -j 2 --filter NativeActionTests
