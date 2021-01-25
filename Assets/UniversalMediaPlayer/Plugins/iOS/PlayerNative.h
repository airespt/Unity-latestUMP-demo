#import "PlayerBase.h"

@class PlayerNative;

@protocol VideoPlayerDelegates <NSObject>

@optional
- (void)videoPlayerIsReadyToPlayVideo:(PlayerNative *)videoPlayer;
- (void)videoPlayerDidReachEnd:(PlayerNative *)videoPlayer;
- (void)videoPlayer:(PlayerNative *)videoPlayer timeDidChange:(CMTime)cmTime;
- (void)videoPlayer:(PlayerNative *)videoPlayer loadedTimeRangeDidChange:(float)duration;
- (void)videoPlayerPlaybackBufferEmpty:(PlayerNative *)videoPlayer;
- (void)videoPlayerPlaybackLikelyToKeepUp:(PlayerNative *)videoPlayer;
- (void)videoPlayer:(PlayerNative *)videoPlayer didFailWithError:(NSError *)error;

@end

@interface PlayerNative : NSObject<PlayerBase>

@property AVPlayer *player;
@property AVPlayerItem *playerItem;
@property AVPlayerItemVideoOutput* videoOutput;
@property bool hasVideoTrack;
@property CVPixelBufferRef pixelBuffer;

@property BOOL flipVertically;
@property BOOL playing;
@property BOOL ready;
@property BOOL seeking;
@property NSURL* url;
@property CGSize videoSize;
@property (nonatomic) int duration;
@property (nonatomic) int framesCounter;
@property int cachedPlaybackTime;

@end
