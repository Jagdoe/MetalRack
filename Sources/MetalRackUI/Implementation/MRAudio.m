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
#import "MROpenAL.h"
#import "MRUtilities.h"

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

    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error;
    [session setCategory:AVAudioSessionCategoryAmbient error:&error];

	m_audioVoice = nil;
    m_strCurrentSong = nil;
	m_flSoundsVolume = 1.0f;
	m_flMusicVolume = 0.25f;
	self = [super init];
	NSLog(@"  AM: Done with super init.");
	[self soundsInit];
	NSLog(@"  AM: Done with soundsInit.");
	[self musicInit];
	NSLog(@"  AM: Done with musicInit.");
	return self;
}

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
	MROpenAL *openAL = [MROpenAL sharedMyOpenAL];

	NSLog(@"  AM: Loading %@.", strSound);
	[openAL loadSoundWithKey:strSound File:strSound Ext:@"caf" Loop:NO];

	return;
}

// Set up our sound stuff.
- (void)soundsInit
{
	if (m_dictSounds)
		(void)0;

	NSDictionary *dictSoundEffects = [[MRDefinitions sharedDefsManager] getDefByClass:@"SoundEffect" Type:nil];

	MROpenAL *openAL = [MROpenAL sharedMyOpenAL];
	[openAL setVolume:m_flSoundsVolume];

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
	// Our individual sounds should be auto-released, so just clear the array.
	(void)0;
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
		int numTypes = [aSound count];
		int nRandIndex = random() % numTypes;
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
            int numTypes = [aSound count];
            int nRandIndex = random() % numTypes;
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


	if (m_audioVoice.playing == YES)
	{
		MROpenAL *openAL = [MROpenAL sharedMyOpenAL];
		[openAL setVolume:m_flSoundsVolume * 0.5f * flCustomVolume];
	}
	else
	{
		MROpenAL *openAL = [MROpenAL sharedMyOpenAL];
		[openAL setVolume:m_flSoundsVolume * flCustomVolume];
	}


	[[MROpenAL sharedMyOpenAL] playSoundWithKey:strSound];
	return YES;
}

- (void)soundsSetVolume:(float)flPercent
{
	m_flSoundsVolume = flPercent;
	MROpenAL *openAL = [MROpenAL sharedMyOpenAL];
	[openAL setVolume:m_flSoundsVolume];
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

	[m_audioVoice prepareToPlay];
	[m_audioVoice setDelegate: self];

	m_audioVoice.numberOfLoops = 0;
	m_audioVoice.volume		= m_flSoundsVolume;


	[m_audioVoice play];
}

- (void)voiceStop
{
	if (m_audioVoice != nil)
	{
		[m_audioVoice stop];
		(void)0;
		m_audioVoice = nil;
	}
}

- (void)voicePause:(BOOL)fPause
{
	if (m_audioVoice != nil)
	{
		if (fPause == YES)
			[m_audioVoice pause];
		else
			[m_audioVoice play];
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
	if (m_audioPlayer != nil)
		m_audioPlayer.volume		= flAdjustedVolume;
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
		[m_audioPlayer stop];
		(void)0;
	}

	m_audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL: fileURL
														  error: nil];
	(void)0;

	[m_audioPlayer prepareToPlay];
	[m_audioPlayer setDelegate: self];

	// Play indefinitely.
	m_audioPlayer.numberOfLoops = 0;
	m_audioPlayer.volume		= m_flMusicVolume;


    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error;
    [session setCategory:AVAudioSessionCategorySoloAmbient error:&error];

	[m_audioPlayer play];
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
	// We'll just pause or resume playback, keeping our hardware
	// ready.
	BOOL fIsPlaying = m_audioPlayer.playing;
	if (fEnable == YES)
	{
		if (fIsPlaying == NO)
			[m_audioPlayer play];
	}
	else
	{
		if (fIsPlaying == YES)
			[m_audioPlayer pause];
	}
}

- (void)musicDestroy
{
	// Our individual sounds should be auto-released, so just clear the array.
	//	[m_arrSounds release];

	(void)0;
	m_audioPlayer = nil;

    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error;
    [session setCategory:AVAudioSessionCategoryAmbient error:&error];
}


@end

#endif
