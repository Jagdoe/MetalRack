//
//  AudioManager.h
//  Zombie
//
//  Created by Michael Scandizzo on 6/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVAudioPlayer.h>

@interface MRAudio : NSObject <AVAudioPlayerDelegate>
{
	NSMutableDictionary		*m_dictSounds;
	BOOL					m_fCachedStatus;
	AVAudioPlayer			*m_audioPlayer;
	AVAudioPlayer			*m_audioVoice;
	NSString				*m_strCurrentSong;
	NSArray					*m_aSongPlayList;
	int						m_nSongNumber;
	float					m_flSoundsVolume;
	float					m_flMusicVolume;
}

+ (MRAudio *)sharedAudioManager;

- (id)init;
- (void)dealloc;

- (void)soundsSetCachedStatus:(BOOL)fSound;
- (BOOL)soundsPlay:(NSString *)strSoundType;

- (void)soundsSetVolume:(float)flPercent;
- (float)soundsGetVolume;


- (void)voicePlay:(NSString *)strVoiceFile;
- (void)voiceStop;
- (void)voicePause:(BOOL)fPause;

- (void)musicStart;
- (void)musicPlay:(NSString *)strMusicFile;
- (void)musicPlayList:(NSArray *)aMusicFiles;
- (void)musicEnable:(BOOL)fEnable;
- (void)musicSetVolume:(float)flPercent;
- (void)musicSetVolume:(float)flPercent andStore:(BOOL)fStore;
- (float)musicGetVolume;

// Submit native player mutations without blocking the main thread. Commands
// execute FIFO on the shared serial playback queue. Read game/UI state before
// submission and return results to the main queue before changing that state.
- (void)performPlayback:(void (^)(void))operation;
// Desired music state, including a start/resume command not yet executed.
- (BOOL)musicPlaybackRequested;


- (void)soundsInit;
- (void)soundsDestroy;
- (void)musicInit;
- (void)musicDestroy;



@end
