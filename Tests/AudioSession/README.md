# Native audio thread regression

`run.py --device EXISTING_SIMULATOR --output OUTPUT` compiles the production
MRAudio.m into a small native simulator host. Definition lookup and preference
storage are doubles; AVAudioPlayer, AVAudioSession, file decoding, timers and EOF
callbacks are real. Generated quarter-second tones are test-only resources.

The host records calls to preparation, playback, seek, volume, pause, explicit
stop, category and session activation. Every app-initiated native mutation must
execute off the main thread. It separately records AVAudioPlayer's own automatic
`finishedPlaying:` stop on its delegate run loop; no application frame may occur
in that excluded cleanup stack. Session activation calls are never excluded.

Six effects must reach real EOF, the playlist must naturally advance/wrap, voice
pause/resume/stop must preserve order, temporary gain must not alter stored gain,
effects mute must work, rapid play/pause/stop must not resurrect playback, and the
main run loop must remain responsive. `--baseline` records the former main-thread
path for comparison. The ordinary Swift package tests also remain applicable.

Playback requests return without waiting for native activation. `soundsPlay:`
continues to report acceptance, not native completion. Public selection, cache,
playlist and preference state retains its existing caller/main-thread ownership;
native player mutations run FIFO on `performPlayback:`. Playlist EOF handling is
marshaled back to the main run loop. `musicPlaybackRequested` exposes intent so
clients pausing music do not race a queued start/resume. Clients of the executor
must snapshot UI/game inputs first and return results to the main queue before
changing that state. No category/mixing policy, format, gain formula, or asset is
changed by this executor.

Requires Xcode simulator tools, afconvert, ffmpeg, and an existing compatible
simulator. It installs only com.metalrack.AudioThreadHost; it never opens or resets
another app's saved game. Reuse an idle simulator and shut it down afterward.
