#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <UIKit/UIKit.h>
#import "UnityAppController.h"

#include <vector>
#include "UnityMetalSupport.h"
#include "PlayerBase.h"
#include "CVTextureCache.h"
#include "CMVideoSampling.h"

#if NATIVE
#include "PlayerNative.h"
#endif

#if FFMPEG
#include "PlayerFFmpeg.h"
#endif


@interface UniversalMediaPlayer : NSObject<PlayerDelegates>

@property id<PlayerBase> player;
@property PlayerTypes playerType;
@property PlayerState* playerState;
@property NSMutableArray* playerStates;
@property CMVideoSampling videoSampling;
@property int cachedVolume;
@property float cachedRate;
@property unsigned char* frameBuffer;

@end
