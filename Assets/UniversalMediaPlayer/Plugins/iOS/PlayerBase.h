#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NSString * const kUMPErrorDomain = @"kUMPErrorDomain";
float const TIME_CHANGE_OFFSET = 0.265;

enum PlayerTypes
{
    Native = 1,
    FFmpeg = 2
};

enum PlayerStates
{
	Empty,
	Opening,
	Buffering,
	ImageReady,
	Prepared,
	Playing,
	Paused,
	Stopped,
	EndReached,
	EncounteredError,
	TimeChanged,
	PositionChanged,
	SnapshotTaken
};

@interface PlayerState : NSObject

@property PlayerStates state;
@property float valueFloat;
@property long valueLong;
@property char* valueString;

@end

@interface NSMutableArray (QueueStack)

-(PlayerState*)queuePop;
-(void)queuePush:(PlayerState*)obj;

@end

@protocol PlayerDelegates <NSObject>

@optional
- (void)mediaPlayerStateChanged:(PlayerState*)state;

@end

@protocol PlayerBase

@property (nonatomic, weak) id<PlayerDelegates> delegate;

- (void)setupPlayer:(NSArray*)options;
- (void)setDataSource:(NSString*)path;
- (void)play;
- (void)pause;
- (void)stop;
- (int)getDuration;
- (CVPixelBufferRef)getPixelBuffer;
- (int)getFramesCounter;
- (int)getVolume;
- (void)setVolume:(int)value;
- (int)getTime;
- (void)setTime:(int)value;
- (float)getPosition;
- (void)setPosition:(float)value;
- (float)getPlaybackRate;
- (void)setPlaybackRate:(float)value;
- (bool)isPlaying;
- (bool)isReady;
- (int)getVideoWidth;
- (int)getVideoHeight;

@end
