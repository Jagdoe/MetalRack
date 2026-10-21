#pragma once
#import "MRActionTypes.h"
#import "MRAction.h"
#import "MRActionInterval.h"
#import "MRActionInstant.h"
#import "MRSprite.h"
/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2008-2009 Jason Booth
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */


/** Base class for Easing actions
 */
@interface MRActionEase : MRActionInterval <NSCopying>
{
	MRActionInterval * other;
}
/** creates the action */
+(id) actionWithAction: (MRActionInterval*) action;
/** initializes the action */
-(id) initWithAction: (MRActionInterval*) action;
@end

/** Base class for Easing actions with rate parameters
 */
@interface MREaseRateAction :  MRActionEase <NSCopying>
{
	float	rate;
}
/** rate value for the actions */
@property (nonatomic,readwrite,assign) float rate;
/** Creates the action with the inner action and the rate parameter */
+(id) actionWithAction: (MRActionInterval*) action rate:(float)rate;
/** Initializes the action with the inner action and the rate parameter */
-(id) initWithAction: (MRActionInterval*) action rate:(float)rate;
@end

/** MREaseIn action with a rate
 */
@interface MREaseIn : MREaseRateAction <NSCopying> {} @end

/** MREaseOut action with a rate
 */
@interface MREaseOut : MREaseRateAction <NSCopying> {} @end

/** MREaseInOut action with a rate
 */
@interface MREaseInOut : MREaseRateAction <NSCopying> {} @end

/** MREase Exponential In
 */
@interface MREaseExponentialIn : MRActionEase <NSCopying> {} @end
/** Ease Exponential Out
 */
@interface MREaseExponentialOut : MRActionEase <NSCopying> {} @end
/** Ease Exponential InOut
 */
@interface MREaseExponentialInOut : MRActionEase <NSCopying> {} @end
/** Ease Sine In
 */
@interface MREaseSineIn : MRActionEase <NSCopying> {} @end
/** Ease Sine Out
 */
@interface MREaseSineOut : MRActionEase <NSCopying> {} @end
/** Ease Sine InOut
 */
@interface MREaseSineInOut : MRActionEase <NSCopying> {} @end

/** Ease Elastic abstract class
 @since v0.8.2
 */
@interface MREaseElastic : MRActionEase <NSCopying>
{
	float period_;
}

/** period of the wave in radians. default is 0.3 */
@property (nonatomic,readwrite) float period;

/** Creates the action with the inner action and the period in radians (default is 0.3) */
+(id) actionWithAction: (MRActionInterval*) action period:(float)period;
/** Initializes the action with the inner action and the period in radians (default is 0.3) */
-(id) initWithAction: (MRActionInterval*) action period:(float)period;
@end

/** Ease Elastic In action.
 @warning This action doesn't use a bijective fucntion. Actions like Sequence might have an unexpected result when used with this action.
 @since v0.8.2
 */
@interface MREaseElasticIn : MREaseElastic <NSCopying> {} @end
/** Ease Elastic Out action.
 @warning This action doesn't use a bijective fucntion. Actions like Sequence might have an unexpected result when used with this action.
 @since v0.8.2
 */
@interface MREaseElasticOut : MREaseElastic <NSCopying> {} @end
/** Ease Elastic InOut action.
 @warning This action doesn't use a bijective fucntion. Actions like Sequence might have an unexpected result when used with this action.
 @since v0.8.2
 */
@interface MREaseElasticInOut : MREaseElastic <NSCopying> {} @end

/** MREaseBounce abstract class.
 @since v0.8.2
*/
@interface MREaseBounce : MRActionEase <NSCopying> {} @end

/** MREaseBounceIn action.
 @warning This action doesn't use a bijective fucntion. Actions like Sequence might have an unexpected result when used with this action.
 @since v0.8.2
*/
@interface MREaseBounceIn : MREaseBounce <NSCopying> {} @end

/** EaseBounceOut action.
 @warning This action doesn't use a bijective fucntion. Actions like Sequence might have an unexpected result when used with this action.
 @since v0.8.2
 */
@interface MREaseBounceOut : MREaseBounce <NSCopying> {} @end

/** MREaseBounceInOut action.
 @warning This action doesn't use a bijective fucntion. Actions like Sequence might have an unexpected result when used with this action.
 @since v0.8.2
 */
@interface MREaseBounceInOut : MREaseBounce <NSCopying> {} @end

/** MREaseBackIn action.
 @warning This action doesn't use a bijective fucntion. Actions like Sequence might have an unexpected result when used with this action.
 @since v0.8.2
 */
@interface MREaseBackIn : MRActionEase <NSCopying> {} @end

/** MREaseBackOut action.
 @warning This action doesn't use a bijective fucntion. Actions like Sequence might have an unexpected result when used with this action.
 @since v0.8.2
 */
@interface MREaseBackOut : MRActionEase <NSCopying> {} @end

/** MREaseBackInOut action.
 @warning This action doesn't use a bijective fucntion. Actions like Sequence might have an unexpected result when used with this action.
 @since v0.8.2
 */
@interface MREaseBackInOut : MRActionEase <NSCopying> {} @end
