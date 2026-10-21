//
//  MyOpenAL.h
//  Zombie
//
//  Created by Michael Scandizzo on 8/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenAL/al.h>
#import <OpenAL/alc.h>
#import <AudioToolbox/AudioToolbox.h>

@interface MROpenAL : NSObject
{
	ALCcontext* mContext; // stores the context (the 'air')
	ALCdevice* mDevice; // stores the device
	NSMutableArray * bufferStorageArray; // stores the buffer ids from openAL
	NSMutableDictionary * soundDictionary; // stores our soundkeys
}

// if you want to access directly the buffers or our sound dictionary
@property (nonatomic, retain) NSMutableArray * bufferStorageArray;
@property (nonatomic, retain) NSMutableDictionary * soundDictionary;

- (id) init; // init once
- (bool) initOpenAL; // no need to make it public, but I post it here to show you which methods we need. initOpenAL will be called within init process once.
- (void) playSoundWithKey:(NSString*)soundKey; // play a sound by name
- (void) stopSoundWithKey:(NSString*)soundKey; // stop a sound by name
- (bool) isPlayingSoundWithKey:(NSString *) soundKey; // check if sound is playing by name
- (void) rewindSoundWithKey:(NSString *) soundKey; // rewind a sound by name so its playing again
- (bool) loadSoundWithKey:(NSString *)_soundKey File:(NSString *)_file Ext:(NSString *) _ext Loop:(bool)loops; // load a sound and give it a name
- (void)setVolume:(float)flPercent;

+ (MROpenAL*)sharedMyOpenAL; // access to our instance

@end
