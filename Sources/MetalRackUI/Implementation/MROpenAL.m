#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  MyOpenAL.m
//  Zombie
//
//  Created by Michael Scandizzo on 8/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MROpenAL.h"
#import "MyOpenALSupport.h"

@implementation MROpenAL

@synthesize bufferStorageArray;
@synthesize soundDictionary;

static MROpenAL *sharedMyOpenAL = nil;

- (void)shutdownMyOpenAL { [self closeAudio]; @synchronized([MROpenAL class]) { sharedMyOpenAL=nil; } }
+ (MROpenAL *)sharedMyOpenAL {
    @synchronized(self) { if (!sharedMyOpenAL) sharedMyOpenAL=[[self alloc] init]; return sharedMyOpenAL; }
}
- (id)copyWithZone:(NSZone *)zone { return self; }
// seek in audio file for the property 'size'
// return the size in bytes
-(UInt32)audioFileSize:(AudioFileID)fileDescriptor
{
	;
	UInt64 outDataSize = 0;
	UInt32 thePropSize = sizeof(UInt64);
	OSStatus result = AudioFileGetProperty(fileDescriptor, kAudioFilePropertyAudioDataByteCount, &thePropSize, &outDataSize);
	if(result != 0) NSLog(@"cannot find file size");
	return (UInt32)outDataSize;
}

// start up openAL
-(bool) initOpenAL
{
	// Initialization
	mDevice = alcOpenDevice(NULL); // select the "preferred device"
	if (mDevice) {
		// use the device to make a context
		mContext=alcCreateContext(mDevice,NULL);
		// set my context to the currently active one
		alcMakeContextCurrent(mContext);
		return true;
	}
	return false;
}

-(id) init
{
	if ((self = [super init]) )
	{
		if ([self initOpenAL])
		{
			self.bufferStorageArray = [NSMutableArray new];
			self.soundDictionary = [NSMutableDictionary new];
			alListenerf(AL_GAIN, 1.0f);
		}
		return self;
	}
	(void)0;
	return nil;
}

- (void)dealloc { [self closeAudio]; }
- (void)closeAudio
{
	// delete the sources
	for (NSNumber * sourceNumber in [soundDictionary allValues]) {
		ALuint sourceID = [sourceNumber unsignedIntegerValue];
		alDeleteSources(1, &sourceID);
	}

	self.soundDictionary=nil;

	// delete the buffers
	for (NSNumber * bufferNumber in bufferStorageArray) {
		ALuint bufferID = [bufferNumber unsignedIntegerValue];
		alDeleteBuffers(1, &bufferID);
	}
	self.bufferStorageArray=nil;

	// destroy the context
	if (mContext) alcDestroyContext(mContext); mContext=NULL;
	// close the device
	if (mDevice) alcCloseDevice(mDevice); mDevice=NULL;

	(void)0;
}

- (void)setVolume:(float)flPercent
{
	alListenerf(AL_GAIN, flPercent);
}

// the main method: grab the sound ID from the library
// and start the source playing
- (void)playSoundWithKey:(NSString*)soundKey
{
	NSNumber * numVal = [soundDictionary objectForKey:soundKey];
	if (numVal == nil) return;
	ALuint sourceID = [numVal unsignedIntValue];
	alSourcePlay(sourceID);
}

- (void)stopSoundWithKey:(NSString*)soundKey
{
	NSNumber * numVal = [soundDictionary objectForKey:soundKey];
	if (numVal == nil) return;
	ALuint sourceID = [numVal unsignedIntValue];
	alSourceStop(sourceID);
}

-(void) rewindSoundWithKey:(NSString *) soundKey
{

	NSNumber * numVal = [soundDictionary objectForKey:soundKey];
	if (numVal == nil) return;
	ALuint sourceID = [numVal unsignedIntValue];
	alSourceRewind (sourceID);
}

-(bool) isPlayingSoundWithKey:(NSString *) soundKey
{

	NSNumber * numVal = [soundDictionary objectForKey:soundKey];
	if (numVal == nil) return false;
	ALuint sourceID = [numVal unsignedIntValue];

	ALenum state;

    alGetSourcei(sourceID, AL_SOURCE_STATE, &state);

    return (state == AL_PLAYING);
}

-(bool) loadSoundWithKey:(NSString *)_soundKey File:(NSString *)_file Ext:(NSString *) _ext Loop:(bool)loops
{

//	START_TIMER;

	ALvoid * outData;
	ALenum  error = AL_NO_ERROR;
	ALenum  format;
	ALsizei size;
	ALsizei freq;

	NSBundle * bundle = [NSBundle mainBundle];

	// get some audio data from a wave file
	NSURL *fileURL = [NSURL fileURLWithPath:[bundle pathForResource:_file ofType:_ext]];

	if (!fileURL)
	{
//		END_TIMER(@"file not found.");
		return false;
	}

	outData = MyGetOpenALAudioData((__bridge CFURLRef)fileURL, &size, &format, &freq);


	if((error = alGetError()) != AL_NO_ERROR)
	{
		printf("error loading sound: %x for file %s\n", error, [_soundKey UTF8String]);
		exit(1);
	}

	//NSLog(@"getting a free buffer from openAL.");
	ALuint bufferID;
	// grab a buffer ID from openAL
	alGenBuffers(1, &bufferID);

	//NSLog(@"loading audio data into openAL buffer.");
	// load the awaiting data blob into the openAL buffer.
	alBufferData(bufferID,format,outData,size,freq);

	// save the buffer so we can release it later
	[bufferStorageArray addObject:[NSNumber numberWithUnsignedInteger:bufferID]];

	//NSLog(@"getting a free source from openAL.");
	ALuint sourceID;
	// grab a source ID from openAL
	alGenSources(1, &sourceID);

	//NSLog(@"attatching the buffer to the source and setting up preferences");
	// attach the buffer to the source
	alSourcei(sourceID, AL_BUFFER, bufferID);
	// set some basic source prefs
	alSourcef(sourceID, AL_PITCH, 1.0f);
	alSourcef(sourceID, AL_GAIN, 1.0f);
	if (loops) alSourcei(sourceID, AL_LOOPING, AL_TRUE);

	// store this for future use
	[soundDictionary setObject:[NSNumber numberWithUnsignedInt:sourceID] forKey:_soundKey];

	//NSLog(@"free %i bytes of temporary allocated memory.", size);
	// clean up the buffer
	if (outData)
	{
		free(outData);
		outData = NULL;
	}

//	END_TIMER(@"Audiofile successfully loaded.");
	return true;

}
@end
#endif
