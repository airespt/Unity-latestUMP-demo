#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, MMPMovieScalingMode) {
    MMPMovieScalingModeNone,       // No scaling
    MMPMovieScalingModeAspectFit,  // Uniform scale until one dimension fits
    MMPMovieScalingModeAspectFill, // Uniform scale until the movie fills the visible bounds. One dimension may have clipped contents
    MMPMovieScalingModeFill        // Non-uniform scale. Both render dimensions will exactly match the visible bounds
};

typedef NS_ENUM(NSInteger, MMPMoviePlaybackState) {
    MMPMoviePlaybackStateStopped,
    MMPMoviePlaybackStatePlaying,
    MMPMoviePlaybackStatePaused,
    MMPMoviePlaybackStateInterrupted,
    MMPMoviePlaybackStateSeekingForward,
    MMPMoviePlaybackStateSeekingBackward
};

typedef NS_OPTIONS(NSUInteger, MMPMovieLoadState) {
    MMPMovieLoadStateUnknown        = 0,
    MMPMovieLoadStatePlayable       = 1 << 0,
    MMPMovieLoadStatePlaythroughOK  = 1 << 1, // Playback will be automatically started in this state when shouldAutoplay is YES
    MMPMovieLoadStateStalled        = 1 << 2, // Playback will be automatically paused in this state, if started
};

typedef NS_ENUM(NSInteger, MMPMovieFinishReason) {
    MMPMovieFinishReasonPlaybackEnded,
    MMPMovieFinishReasonPlaybackError,
    MMPMovieFinishReasonUserExited
};

// -----------------------------------------------------------------------------
// Thumbnails

typedef NS_ENUM(NSInteger, MMPMovieTimeOption) {
    MMPMovieTimeOptionNearestKeyFrame,
    MMPMovieTimeOptionExact
};

@protocol MediaPlayback;

#pragma mark MediaPlayback

@protocol MediaPlayback <NSObject>

- (void)prepareToPlay;
- (void)play;
- (void)pause;
- (void)stop;
- (BOOL)isPlaying;
- (void)shutdown;
- (void)setPauseInBackground:(BOOL)pause;

- (void)setDataSourceURL:(NSURL *)aUrl;
- (BOOL)isReady;
- (CVPixelBufferRef)videoBuffer;
- (long)frameCount;
- (int)videoWidth;
- (int)videoHeight;

@property(nonatomic, readonly)  UIView *view;
@property(nonatomic)            NSTimeInterval currentPlaybackTime;
@property(nonatomic, readonly)  NSTimeInterval duration;
@property(nonatomic, readonly)  NSTimeInterval playableDuration;
@property(nonatomic, readonly)  NSInteger bufferingProgress;

@property(nonatomic, readonly)  BOOL isPreparedToPlay;
@property(nonatomic, readonly)  MMPMoviePlaybackState playbackState;
@property(nonatomic, readonly)  MMPMovieLoadState loadState;
@property(nonatomic, readonly) int isSeekBuffering;
@property(nonatomic, readonly) int isAudioSync;
@property(nonatomic, readonly) int isVideoSync;

@property(nonatomic, readonly) int64_t numberOfBytesTransferred;

@property(nonatomic, readonly) CGSize naturalSize;
@property(nonatomic) MMPMovieScalingMode scalingMode;
@property(nonatomic) BOOL shouldAutoplay;

@property (nonatomic) BOOL allowsMediaAirPlay;
@property (nonatomic) BOOL isDanmakuMediaAirPlay;
@property (nonatomic, readonly) BOOL airPlayMediaActive;

@property (nonatomic) float playbackRate;
@property (nonatomic) float playbackVolume;

- (UIImage *)thumbnailImageAtCurrentTime;

#pragma mark Notifications

#ifdef __cplusplus
#define IJK_EXTERN extern "C" __attribute__((visibility ("default")))
#else
#define IJK_EXTERN extern __attribute__((visibility ("default")))
#endif

// -----------------------------------------------------------------------------
//  MPMediaPlayback.h

// Posted when the prepared state changes of an object conforming to the MPMediaPlayback protocol changes.
// This supersedes MPMoviePlayerContentPreloadDidFinishNotification.
IJK_EXTERN NSString *const MMPMediaPlaybackIsPreparedToPlayDidChangeNotification;

// -----------------------------------------------------------------------------
//  MPMoviePlayerController.h
//  Movie Player Notifications

// Posted when the scaling mode changes.
IJK_EXTERN NSString* const MMPMoviePlayerScalingModeDidChangeNotification;

// Posted when movie playback ends or a user exits playback.
IJK_EXTERN NSString* const MMPMoviePlayerPlaybackDidFinishNotification;
IJK_EXTERN NSString* const MMPMoviePlayerPlaybackDidFinishReasonUserInfoKey; // NSNumber (MMPMovieFinishReason)

// Posted when the playback state changes, either programatically or by the user.
IJK_EXTERN NSString* const MMPMoviePlayerPlaybackStateDidChangeNotification;

// Posted when the network load state changes.
IJK_EXTERN NSString* const MMPMoviePlayerLoadStateDidChangeNotification;

// Posted when the movie player begins or ends playing video via AirPlay.
IJK_EXTERN NSString* const MMPMoviePlayerIsAirPlayVideoActiveDidChangeNotification;

// -----------------------------------------------------------------------------
// Movie Property Notifications

// Calling -prepareToPlay on the movie player will begin determining movie properties asynchronously.
// These notifications are posted when the associated movie property becomes available.
IJK_EXTERN NSString* const MMPMovieNaturalSizeAvailableNotification;

// -----------------------------------------------------------------------------
//  Extend Notifications

IJK_EXTERN NSString *const MMPMoviePlayerVideoDecoderOpenNotification;
IJK_EXTERN NSString *const MMPMoviePlayerFirstVideoFrameRenderedNotification;
IJK_EXTERN NSString *const MMPMoviePlayerFirstAudioFrameRenderedNotification;
IJK_EXTERN NSString *const MMPMoviePlayerFirstAudioFrameDecodedNotification;
IJK_EXTERN NSString *const MMPMoviePlayerFirstVideoFrameDecodedNotification;
IJK_EXTERN NSString *const MMPMoviePlayerOpenInputNotification;
IJK_EXTERN NSString *const MMPMoviePlayerFindStreamInfoNotification;
IJK_EXTERN NSString *const MMPMoviePlayerComponentOpenNotification;

IJK_EXTERN NSString *const MMPMoviePlayerDidSeekCompleteNotification;
IJK_EXTERN NSString *const MMPMoviePlayerDidSeekCompleteTargetKey;
IJK_EXTERN NSString *const MMPMoviePlayerDidSeekCompleteErrorKey;
IJK_EXTERN NSString *const MMPMoviePlayerDidAccurateSeekCompleteCurPos;
IJK_EXTERN NSString *const MMPMoviePlayerAccurateSeekCompleteNotification;
IJK_EXTERN NSString *const MMPMoviePlayerSeekAudioStartNotification;
IJK_EXTERN NSString *const MMPMoviePlayerSeekVideoStartNotification;

@end

#pragma mark MediaUrlOpenDelegate

// Must equal to the defination in ijkavformat/ijkavformat.h
typedef NS_ENUM(NSInteger, MediaEvent) {

    // Notify Events
    MediaEvent_WillHttpOpen         = 1,       // attr: url
    MediaEvent_DidHttpOpen          = 2,       // attr: url, error, http_code
    MediaEvent_WillHttpSeek         = 3,       // attr: url, offset
    MediaEvent_DidHttpSeek          = 4,       // attr: url, offset, error, http_code
    // Control Message
    MediaCtrl_WillTcpOpen           = 0x20001, // MediaUrlOpenData: no args
    MediaCtrl_DidTcpOpen            = 0x20002, // MediaUrlOpenData: error, family, ip, port, fd
    MediaCtrl_WillHttpOpen          = 0x20003, // MediaUrlOpenData: url, segmentIndex, retryCounter
    MediaCtrl_WillLiveOpen          = 0x20005, // MediaUrlOpenData: url, retryCounter
    MediaCtrl_WillConcatSegmentOpen = 0x20007, // MediaUrlOpenData: url, segmentIndex, retryCounter
};

#define MediaEventAttrKey_url            @"url"
#define MediaEventAttrKey_host           @"host"
#define MediaEventAttrKey_error          @"error"
#define MediaEventAttrKey_time_of_event  @"time_of_event"
#define MediaEventAttrKey_http_code      @"http_code"
#define MediaEventAttrKey_offset         @"offset"
#define MediaEventAttrKey_file_size      @"file_size"

// event of IJKMediaUrlOpenEvent_xxx
@interface MediaUrlOpenData: NSObject

- (id)initWithUrl:(NSString *)url
            event:(MediaEvent)event
     segmentIndex:(int)segmentIndex
     retryCounter:(int)retryCounter;

@property(nonatomic, readonly) MediaEvent event;
@property(nonatomic, readonly) int segmentIndex;
@property(nonatomic, readonly) int retryCounter;

@property(nonatomic, retain) NSString *url;
@property(nonatomic, assign) int fd;
@property(nonatomic, strong) NSString *msg;
@property(nonatomic) int error; // set a negative value to indicate an error has occured.
@property(nonatomic, getter=isHandled)    BOOL handled;     // auto set to YES if url changed
@property(nonatomic, getter=isUrlChanged) BOOL urlChanged;  // auto set to YES by url changed

@end

@protocol MediaUrlOpenDelegate <NSObject>

- (void)willOpenUrl:(MediaUrlOpenData*) urlOpenData;

@end

@protocol MediaNativeInvokeDelegate <NSObject>

- (int)invoke:(MediaEvent)event attributes:(NSDictionary *)attributes;

@end
