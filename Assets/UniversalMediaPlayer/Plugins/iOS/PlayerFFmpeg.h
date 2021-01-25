#import "PlayerBase.h"
#import <PlayerFFmpeg/PlayerFFmpeg.h>

@interface PlayerFFmpeg : NSObject<PlayerBase>

@property (atomic, retain) id<MediaPlayback> player;
@property FFOptions* ffOptions;
@property bool playInBackground;
@property NSString* videoPath;
@property bool hasVideoTrack;
@property bool isBuffering;
@property NSInteger cachedBuffering;
@property float cachedPlaybackTime;
@property unsigned char* frameBuffer;

@end
