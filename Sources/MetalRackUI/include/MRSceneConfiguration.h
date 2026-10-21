#pragma once
#import "MRSceneHost.h"
#define MR_DELEGATE_CLASS MRSceneHost
#define MR_GAME_NAME ([MRSceneHost option:@"gameName" fallback:@""])
#define MR_ISC_APP_NAME ([MRSceneHost option:@"serviceAppName" fallback:@""])
#ifdef IPHONE_TARGET
#define MR_IPHONE 1
#endif
#define MR_SCREEN_MINOR ([MRSceneHost screenMinor])
#define MR_SCREEN_MAJOR ([MRSceneHost screenMajor])
#define MR_DEFAULT_FONT_SIZE (12)
#define MR_FONT_SIZE_MENU (20)
#define MR_HALF_SCREEN_MINOR (MR_SCREEN_MINOR / 2.0f)
#define MR_HALF_SCREEN_MAJOR (MR_SCREEN_MAJOR / 2.0f)
#define MR_FRAMES_PER_SECOND (60)
#define MR_PREF_REQUESTED_FACEBOOK @"RequestedFacebook"    // Has this user requested to use Facebook?
#define MR_FACEBOOK_APP_ID ([MRSceneHost option:@"facebookAppID" fallback:@""])
#define MR_LAYER_BACK (100)
#define MR_LAYER_FOREGROUND (3000)
#define MR_LAYER_UI (9000)
#define MR_LAYER_NOTIFY (10000)
#define MR_LAYER_MAX (10000000)
#define MR_TAG_ACTION_SPIN (100)
#define MR_PREF_NICKNAME ([MRSceneHost option:@"nicknamePreference" fallback:@""])
#define MR_PREFS_KEY_MUSIC @"PREFERENCE: music"
#define MR_ENTRY_SPRITES @"sprites"				// Array of sprite entries.
#define MR_ENTRY_SPRITE_IMAGE @"image"				// Graphic name for an item.
#define MR_ENTRY_SPRITE_SCALE @"scale"				// Scale of said graphic item.
#define MR_ENTRY_SPRITE_COLOR @"color"				// Grab the color from our color.plist
#define MR_ENTRY_SPRITE_ROTATE @"rotate"				// Does it rotate
#define MR_ENTRY_SPRITE_SET @"set"					// What set must be unlocked for this to display
#define MR_ENTRY_SPRITE_ROTATION @"rotation"				// Initial rotation of sprite
#define MR_ENTRY_POSITION @"position"				// Where in the mission scene to put this?
#define MR_ENTRY_PHONE_POSITION @"phone position"		// Where in the mission scene to put this?
#define MR_CURRENCY_FOR_UNLOCK ([MRSceneHost option:@"unlockCurrency" fallback:@""])
