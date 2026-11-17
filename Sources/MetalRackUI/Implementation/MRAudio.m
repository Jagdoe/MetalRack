#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  AudioManager.m
//  Zombie
//
//  Created by Michael Scandizzo on 6/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

//#import "MRSceneConfiguration.h"
#import "MRAudio.h"
#import "MRDefinitions.h"
#import <AVFoundation/AVAudioSession.h>

#import "MRUtilities.h"

// Player preparation/playback can synchronously activate AVAudioSession. Keep
// native player mutations and category changes ordered off the UI thread.
@interface MRAudio () {
    dispatch_queue_t m_playbackQueue;
    BOOL m_musicPlaybackRequested;
}
- (void)handleFinishedPlayer:(AVAudioPlayer *)player successfully:(BOOL)flag;
@end

static void MRConfigureAudioCategory(NSString *category) {
    NSError *error=nil;
    if(![AVAudioSession.sharedInstance setCategory:category error:&error])
        NSLog(@"Unable to configure audio category %@: %@",category,error);
}

@implementation MRAudio

#define INITIAL_ARRAY_CAPACITY	(64)

static MRAudio     *m_sSingleton = nil;

+ (id)sharedAudioManager
{
    if (m_sSingleton == nil)
    {
        m_sSingleton = [[MRAudio alloc] init];
    }
    return m_sSingleton;
}

- (id)init
{
	NSLog(@"  AM: Beginning init.");

    self=[super init];if(!self)return nil;
    m_playbackQueue=dispatch_queue_create("com.metalrack.audio-playback",DISPATCH_QUEUE_SERIAL);
    [self performPlayback:^{MRConfigureAudioCategory(AVAudioSessionCategoryAmbient);}];

	m_audioVoice = nil;
    m_strCurrentSong = nil;
	m_flSoundsVolume = 1.0f;
	m_flMusicVolume = 0.25f;
	NSLog(@"  AM: Done with super init.");
	[self soundsInit];
	NSLog(@"  AM: Done with soundsInit.");
	[self musicInit];
	NSLog(@"  AM: Done with musicInit.");
	return self;
}

- (void)performPlayback:(void (^)(void))operation
{
    if(!operation)return;
    dispatch_async(m_playbackQueue,^{@autoreleasepool{operation();}});
}

- (BOOL)musicPlaybackRequested { return m_musicPlaybackRequested; }

- (void)dealloc
{
	[self soundsDestroy];
	[self musicDestroy];
	(void)0;
}

#pragma mark -
#pragma mark Sounds

- (void)addSound:(NSString *)strSound
{
    NSURL *url=[NSBundle.mainBundle URLForResource:strSound withExtension:@"caf"];
    if(!url)return;
    NSError *error=nil;
    AVAudioPlayer *player=[[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if(!player){NSLog(@"Unable to load sound %@: %@",strSound,error);return;}
    float volume=m_flSoundsVolume;
    [self performPlayback:^{player.volume=volume;[player prepareToPlay];}];
    m_dictSounds[strSound]=player;
}

// Set up our sound stuff.
- (void)soundsInit
{
	if (m_dictSounds)
		(void)0;

	NSDictionary *dictSoundEffects = [[MRDefinitions sharedDefsManager] getDefByClass:@"SoundEffect" Type:nil];


	m_dictSounds = [[NSMutableDictionary alloc] initWithCapacity:INITIAL_ARRAY_CAPACITY];

	for (NSString *strSoundDef in dictSoundEffects)
	{
		NSString *strSound = nil;
		NSObject *obSound = [dictSoundEffects objectForKey:strSoundDef];
		if ([obSound isKindOfClass:[NSArray class]] == YES)
		{
			NSArray *aSound = (NSArray *)obSound;
			for (strSound in aSound)
			{
				[self addSound:strSound];
			}
		}
		else if ([obSound isKindOfClass:[NSString class]] == YES)
		{
			strSound = (NSString *)obSound;
			[self addSound:strSound];
		}
        else if ([obSound isKindOfClass:[NSDictionary class]] == YES)
        {
            NSDictionary *dictSound = (NSDictionary *)obSound;
            obSound = [dictSound objectForKey:@"sound"];
            if ([obSound isKindOfClass:[NSArray class]] == YES)
            {
                NSArray *aSound = (NSArray *)obSound;
                for (strSound in aSound)
                {
                    [self addSound:strSound];
                }
            }
            else if ([obSound isKindOfClass:[NSString class]] == YES)
            {
                strSound = (NSString *)obSound;
                [self addSound:strSound];
            }
        }

	}

	m_fCachedStatus = YES;
}

- (void)soundsDestroy
{
	// Stop and release all cached effects.
    NSArray *players=m_dictSounds.allValues;
    [self performPlayback:^{for(AVAudioPlayer *sound in players)[sound stop];}];
    [m_dictSounds removeAllObjects];
}

- (void)soundsSetCachedStatus:(BOOL)fSound
{
	m_fCachedStatus = fSound;
}

- (BOOL)soundsPlay:(NSString *)strSoundType
{
	if (strSoundType == nil)
		return FALSE;

	if (m_fCachedStatus != YES)
		return FALSE;

    MRDefinitions *dMan = [MRDefinitions sharedDefsManager];
	NSDictionary *dictSoundEffects = [dMan getDefByClass:@"SoundEffect" Type:nil];
	NSObject *obSound = [dictSoundEffects objectForKey:strSoundType];
    if (obSound == nil)
    {
        NSLog(@"ERROR: Failed to find sound definition for %@", strSoundType);
        return NO;
    }

    float flCustomVolume = 1.0f;
	NSString *strSound;
	if ([obSound isKindOfClass:[NSArray class]] == YES)
	{
		NSArray *aSound = (NSArray *)obSound;
		NSUInteger numTypes = [aSound count];
		NSUInteger nRandIndex = random() % numTypes;
		strSound = [aSound objectAtIndex:nRandIndex];
	}
	else if ([obSound isKindOfClass:[NSString class]] == YES)
	{
		strSound = (NSString *)obSound;
	}
    else if ([obSound isKindOfClass:[NSDictionary class]] == YES)
    {
        NSDictionary *dictSound = (NSDictionary *)obSound;
        obSound = [dictSound objectForKey:@"sound"];
        if ([obSound isKindOfClass:[NSArray class]] == YES)
        {
            NSArray *aSound = (NSArray *)obSound;
            NSUInteger numTypes = [aSound count];
            NSUInteger nRandIndex = random() % numTypes;
            strSound = [aSound objectAtIndex:nRandIndex];
        }
        else
        {
            strSound = (NSString *)obSound;
        }
        id obVolume = [dictSound objectForKey:@"volume"];
        if (obVolume != nil)
            flCustomVolume = [obVolume floatValue];
    }


    float volume=m_flSoundsVolume*flCustomVolume;
    AVAudioPlayer *voice=m_audioVoice,*sound=m_dictSounds[strSound];
    NSArray *players=m_dictSounds.allValues;
    [self performPlayback:^{
        float gain=volume*(voice.playing?.5f:1.f);
        for(AVAudioPlayer *player in players)player.volume=gain;
        sound.currentTime=0;[sound play];
    }];
	return YES;
}

- (void)soundsSetVolume:(float)flPercent
{
	m_flSoundsVolume = flPercent;
    NSArray *players=m_dictSounds.allValues;
    [self performPlayback:^{for(AVAudioPlayer *sound in players)sound.volume=flPercent;}];
}

- (float)soundsGetVolume
{
	return m_flSoundsVolume;
}

#pragma mark -
#pragma mark Music

- (void)voicePlay:(NSString *)strVoiceFile;
{
	if (strVoiceFile == nil || [strVoiceFile length] < 1)
		return;

	// Our music stuff.
	NSString *soundFilePath = [[NSBundle mainBundle] pathForResource: strVoiceFile ofType: @"mp3"];

	NSURL *fileURL;
	if (soundFilePath != nil)
		fileURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
	else
	{
		NSLog(@"ERROR: Cannot find voice file %@ as MP3.", strVoiceFile);
		// Try as a CAF file.
		soundFilePath = [[NSBundle mainBundle] pathForResource: strVoiceFile ofType: @"caf"];
		if (soundFilePath == nil)
		{
			NSLog(@"ERROR L2: Cannot find voice file %@ as CAF.", strVoiceFile);
			return;
		}
		fileURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
	}

	[self voiceStop];

	m_audioVoice = [[AVAudioPlayer alloc] initWithContentsOfURL: fileURL
														   error: nil];
	(void)0;

    AVAudioPlayer *voice=m_audioVoice;voice.delegate=self;
    float volume=m_flSoundsVolume;
    [self performPlayback:^{
        voice.numberOfLoops=0;voice.volume=volume;
        [voice prepareToPlay];[voice play];
    }];
}

- (void)voiceStop
{
	if (m_audioVoice != nil)
	{
        AVAudioPlayer *voice=m_audioVoice;
        [self performPlayback:^{[voice stop];}];
		(void)0;
		m_audioVoice = nil;
	}
}

- (void)voicePause:(BOOL)fPause
{
	if (m_audioVoice != nil)
	{
        AVAudioPlayer *voice=m_audioVoice;
        [self performPlayback:^{if(fPause)[voice pause];else [voice play];}];
	}
}


#pragma mark -
#pragma mark Music

- (void)musicStart
{
	NSString *strMusicFile = [MRUtilities getContentStringForKey:MR_PREFS_KEY_MUSIC];
	if (strMusicFile == nil)
		strMusicFile = @"Attack-Hauser";

	[self musicPlay:strMusicFile];
}

// Set up our sound stuff.
- (void)musicInit
{
	m_flMusicVolume		= 0.25f;
	m_aSongPlayList	= nil;
}

- (void)musicSetVolume:(float)flPercent
{
    [self musicSetVolume:flPercent andStore:YES];
}

- (void)musicSetVolume:(float)flPercent andStore:(BOOL)fStore
{
    // If we're low, treat this as zero.
    if (flPercent <= 0.05f)
        flPercent = 0.0f;

    float flAdjustedVolume = 0.25f * flPercent;
    if (fStore == YES)
        m_flMusicVolume				= flAdjustedVolume;
    AVAudioPlayer *player=m_audioPlayer;
    [self performPlayback:^{player.volume=flAdjustedVolume;}];
}

- (float)musicGetVolume
{
	return m_flMusicVolume	/ 0.25f;
}

- (void)localMusicPlay:(NSString *)strMusicFile
{
    if (m_strCurrentSong != nil)
    {
        (void)0;
        m_strCurrentSong = nil;
    }
	m_strCurrentSong = ([strMusicFile copy]);
	[MRUtilities setContentStringForKey:MR_PREFS_KEY_MUSIC withString:strMusicFile];

	NSString *soundFilePath = [[NSBundle mainBundle] pathForResource: strMusicFile ofType: @"mp3"];

	NSURL *fileURL;
	if (soundFilePath != nil)
		fileURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
	else
	{
		NSLog(@"ERROR: Cannot find music file %@.", strMusicFile);
		return;
	}

	if (m_audioPlayer != nil)
	{
        AVAudioPlayer *previous=m_audioPlayer;
        [self performPlayback:^{[previous stop];}];
		(void)0;
	}

	m_audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL: fileURL
														  error: nil];
	(void)0;

    AVAudioPlayer *player=m_audioPlayer;player.delegate=self;
    float volume=m_flMusicVolume;m_musicPlaybackRequested=YES;
    [self performPlayback:^{
        MRConfigureAudioCategory(AVAudioSessionCategorySoloAmbient);
        player.numberOfLoops=0;player.volume=volume;
        [player prepareToPlay];[player play];
    }];
}

- (void)musicPlay:(NSString *)strMusicFile
{
	// Don't restart the same song.
	if ([m_strCurrentSong isEqualToString:strMusicFile] == YES)
		return;

	if (m_aSongPlayList != nil)
	{
		(void)0;
		m_aSongPlayList = nil;
	}
	[self localMusicPlay:strMusicFile];
}

- (void)musicPlayList:(NSArray *)aMusicFiles
{
	m_aSongPlayList = ([NSArray arrayWithArray:aMusicFiles]);
	m_nSongNumber = 0;

	NSString *strSong = [m_aSongPlayList objectAtIndex:0];
	[self localMusicPlay:strSong];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    // Playlist/request state belongs to the caller's main run loop. Native
    // completion delivery must not race those requests from an audio thread.
    if(!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(),^{[self handleFinishedPlayer:player successfully:flag];});
        return;
    }
    [self handleFinishedPlayer:player successfully:flag];
}

- (void)handleFinishedPlayer:(AVAudioPlayer *)player successfully:(BOOL)flag
{
	// Did our music end?
	if (player == m_audioPlayer)
	{
		if (m_aSongPlayList == nil)
		{
			[self localMusicPlay:m_strCurrentSong];
		}
		else
		{
			m_nSongNumber = (m_nSongNumber + 1) % [m_aSongPlayList count];
			NSString *strSong = [m_aSongPlayList objectAtIndex:m_nSongNumber];
			[self localMusicPlay:strSong];
		}
	}
}

- (void)musicEnable:(BOOL)fEnable
{
    m_musicPlaybackRequested=fEnable;
    AVAudioPlayer *player=m_audioPlayer;
    [self performPlayback:^{
        if(fEnable){if(!player.playing)[player play];}
        else if(player.playing)[player pause];
    }];
}

- (void)musicDestroy
{
	// Our individual sounds should be auto-released, so just clear the array.
	//	[m_arrSounds release];

    AVAudioPlayer *player=m_audioPlayer;
    m_audioPlayer=nil;m_musicPlaybackRequested=NO;
    [self performPlayback:^{[player stop];MRConfigureAudioCategory(AVAudioSessionCategoryAmbient);}];
}


@end

#endif
