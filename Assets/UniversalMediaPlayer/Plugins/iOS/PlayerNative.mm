#include "PlayerNative.h"
#import "UnityAppController.h"

static void *PlayerItemStatusContext = &PlayerItemStatusContext;
static void *PlayerItemPlaybackBufferEmpty = &PlayerItemPlaybackBufferEmpty;
static void *PlayerItemLoadedTimeRangesContext = &PlayerItemLoadedTimeRangesContext;

@implementation PlayerNative

@synthesize delegate = _delegate;

- (void)dealloc
{
    [self stop];
}

- (id)init
{
    self = [super init];
    return self;
}

- (void)setupPlayer:(NSArray *)options
{
    _player = [[AVPlayer alloc] init];
    
    for(NSString *option in options)
    {
        if ([option isEqual: @"flip-vertically"])
            _flipVertically = true;
    }
}

- (AVPlayerItem*)getPlayerItem
{
    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithURL:_url];
    
    if (playerItem)
    {
        [_player replaceCurrentItemWithPlayerItem:playerItem];
        [self addPlayerItemObservers:playerItem];
    }
    else
    {
        [self reportUnableToCreatePlayerItem];
        return nil;
    }
    
    return playerItem;
}

- (void)setDataSource:(NSString *)path
{
    _url = [NSURL URLWithString:path];
    
    if (_url == nil)
        return;
    
    _playerItem = [self getPlayerItem];
}

- (void)play
{
    if (!_playerItem)
    {
        if (_url == nil)
            return;
        
        _playerItem = [self getPlayerItem];
    }
    
    if (_ready)
    {
        [_player play];
        _playing = true;
    }
}

- (void)pause
{
    [self.player pause];
    _playing = false;
    
    if (_ready)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            PlayerState *newState = [[PlayerState alloc] init];
            newState.state = Paused;
            [_delegate mediaPlayerStateChanged:newState];
        });
    }
}

- (void)stop
{
    _ready = false;
    _hasVideoTrack = false;
    _framesCounter = 0;
    
    [self pause];
    [self cleanPixelBuffer];
    
    if (self.playerItem)
    {
        [self removePlayerItemObservers:self.playerItem];
        [self.player replaceCurrentItemWithPlayerItem:nil];
        
        self.playerItem = nil;
    }
    
    if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
    {
        PlayerState *newState = [[PlayerState alloc] init];
        newState.state = Stopped;
        [_delegate mediaPlayerStateChanged:newState];
    }
}

- (int)getDuration
{
    return _duration * 1000;
}

- (void)flipPixelBuffer:(CVPixelBufferRef)buffer withHeight:(int)height
{
    if (kCVReturnSuccess == CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly))
    {
        const int pitch = (int)CVPixelBufferGetBytesPerRow(buffer);
        
        unsigned char* row = (unsigned char*)malloc(sizeof(unsigned char*) * pitch);
        unsigned char* low = (unsigned char*)CVPixelBufferGetBaseAddress(buffer);
        unsigned char* high = &low[(height - 1) * pitch];
        
        for (; low < high; low += pitch, high -= pitch) {
            memcpy(row, low, pitch);
            memcpy(low, high, pitch);
            memcpy(high, row, pitch);
        }
        free(row);
        
        CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    }
}

- (CVPixelBufferRef)getPixelBuffer
{
    if (_pixelBuffer != nil)
    {
        int width = (int)CVPixelBufferGetWidth(_pixelBuffer);
        int height = (int)CVPixelBufferGetHeight(_pixelBuffer);

        if (_videoSize.width != width || _videoSize.height != height)
            _videoSize = CGSizeMake(width, height);
        
        if (_flipVertically)
            [self flipPixelBuffer:_pixelBuffer withHeight:height];
    }
    
    return _pixelBuffer;
}

- (void)cleanPixelBuffer
{
    if (_pixelBuffer)
    {
        CFRelease(_pixelBuffer);
        _pixelBuffer = nil;
    }
}

- (int)getFramesCounter
{
    if ([self isPlaying])
    {
        float playbackTime = CMTimeGetSeconds([_player currentTime]);
        if (fabs(playbackTime - _cachedPlaybackTime) > TIME_CHANGE_OFFSET)
        {
            if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PlayerState *newState = [[PlayerState alloc] init];
                    newState.state = TimeChanged;
                    newState.valueLong = playbackTime * 1000;
                    [_delegate mediaPlayerStateChanged:newState];
                });
            }
            
            if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PlayerState *newState = [[PlayerState alloc] init];
                    newState.state = PositionChanged;
                    newState.valueFloat = playbackTime / _duration;
                    [_delegate mediaPlayerStateChanged:newState];
                });
            }
            
            _cachedPlaybackTime = playbackTime;
        }
    }
    
    CMTime outputTime = [_videoOutput itemTimeForHostTime:CACurrentMediaTime()];
    if([_videoOutput hasNewPixelBufferForItemTime:outputTime])
    {
        [self cleanPixelBuffer];
        
        _pixelBuffer = [_videoOutput copyPixelBufferForItemTime:outputTime itemTimeForDisplay:nil];
        _framesCounter++;
    }
    
    return _framesCounter;
}

- (int)getVolume
{
    if (_ready)
        return self.player.volume * 100;
    
    return 0;
}

- (void)setVolume:(int)value
{
    if (_ready)
        self.player.volume = (float)value / 100.0;
}

- (int)getTime
{
    CMTime time = kCMTimeZero;
    if (_ready)
        time = [_player currentTime];
    
    return CMTIME_IS_VALID(time) ? (int)(CMTimeGetSeconds(time) * 1000) : 0;
}

- (void)setTime:(int)value
{
    if (!_seeking && [self isReady])
    {
        float time = (float)value / 1000.0;
        CMTime cmTime = CMTimeMakeWithSeconds(time, self.player.currentTime.timescale);
        
        _seeking = true;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.player seekToTime:cmTime completionHandler:^(BOOL finished)
            {
                _seeking = false;
            }];
        });
    }
}

- (float)getPosition
{
    CMTime time = kCMTimeZero;
    if (_ready)
        time = [_player currentTime];
    
    return CMTIME_IS_VALID(time) ? CMTimeGetSeconds(time) / _duration : 0;
}

- (void)setPosition:(float)value
{
    if (_ready)
        [self setTime:((_duration * value) * 1000)];
}

- (float)getPlaybackRate
{
    return _player.rate;
}

- (void)setPlaybackRate:(float)value
{
    [_player setRate:value];
}

- (int)getVideoWidth
{
    return _videoSize.width;
}

- (int)getVideoHeight
{
    return _videoSize.height;
}

- (BOOL)isPlaying
{
    return _playing;
}

- (BOOL)isReady
{
    return _hasVideoTrack ? _framesCounter > 0 : _ready;
}

- (void)reportUnableToCreatePlayerItem
{
    NSLog(@"Unable to create AVPlayerItem.");
    
    if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            PlayerState *newState = [[PlayerState alloc] init];
            newState.state = EncounteredError;
            [_delegate mediaPlayerStateChanged:newState];
        });
    }
}

- (float)getLoadedDuration
{
    float loadedDuration = 0.0f;
    
    if (self.player && self.player.currentItem)
    {
        NSArray *loadedTimeRanges = self.player.currentItem.loadedTimeRanges;
        
        if (loadedTimeRanges && [loadedTimeRanges count])
        {
            CMTimeRange timeRange = [[loadedTimeRanges firstObject] CMTimeRangeValue];
            loadedDuration = CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration));
        }
    }
    
    return loadedDuration;
}

- (void)addPlayerItemObservers:(AVPlayerItem *)playerItem
{
    [playerItem addObserver:self
                 forKeyPath:NSStringFromSelector(@selector(status))
                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                    context:PlayerItemStatusContext];
    
    [playerItem addObserver:self
                 forKeyPath:NSStringFromSelector(@selector(isPlaybackBufferEmpty))
                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                    context:PlayerItemPlaybackBufferEmpty];
    
    [playerItem addObserver:self
                 forKeyPath:NSStringFromSelector(@selector(loadedTimeRanges))
                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                    context:PlayerItemLoadedTimeRangesContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidPlayToEndTime:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];
}

- (void)removePlayerItemObservers:(AVPlayerItem *)playerItem
{
    [playerItem cancelPendingSeeks];
    
    [playerItem removeObserver:self
                    forKeyPath:NSStringFromSelector(@selector(status))
                       context:PlayerItemStatusContext];
    
    [playerItem removeObserver:self
                    forKeyPath:NSStringFromSelector(@selector(isPlaybackBufferEmpty))
                       context:PlayerItemPlaybackBufferEmpty];
    
    [playerItem removeObserver:self
                    forKeyPath:NSStringFromSelector(@selector(loadedTimeRanges))
                       context:PlayerItemLoadedTimeRangesContext];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == PlayerItemStatusContext)
    {
        AVPlayerStatus newStatus = (AVPlayerStatus)[[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        AVPlayerStatus oldStatus = (AVPlayerStatus)[[change objectForKey:NSKeyValueChangeOldKey] integerValue];
        
        if (newStatus != oldStatus)
        {
            switch (newStatus)
            {
                case AVPlayerItemStatusUnknown:
                {
                    NSLog(@"Video player Status Unknown");
                    break;
                }
                case AVPlayerItemStatusReadyToPlay:
                {
                    if (!_ready)
                    {
                        NSDictionary *options = @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                                   (__bridge NSString *)kCVPixelBufferOpenGLESCompatibilityKey : @YES };
                        
                        _videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:options];
                        [[_player currentItem] addOutput:_videoOutput];
                        
                        CMTime time;
                        
                        if([AVPlayerItem instancesRespondToSelector:@selector(duration)])
                            time = [[_player currentItem] duration];
                        else
                            time = [[[[[[_player currentItem] tracks] objectAtIndex:0] assetTrack] asset] duration];
                        
                        _duration = CMTIME_IS_INVALID(time) == NO ? CMTimeGetSeconds(time) : 0;
                        _ready = true;
                        _playing = true;
                        
                        if([[_player currentItem] tracks].count > 0)
                        {
                            NSUInteger tracksCount = [[[[[[[_player currentItem] tracks] objectAtIndex:0] assetTrack] asset] tracksWithMediaType:AVMediaTypeVideo] count];
                            
                            _hasVideoTrack = tracksCount > 0;
                        }
                    }
                    
                    break;
                }
                case AVPlayerItemStatusFailed:
                {
                    NSLog(@"Video player Status Failed: player item error = %@", self.player.currentItem.error);
                    NSLog(@"Video player Status Failed: player error = %@", self.player.error);
                    
                    if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            PlayerState *newState = [[PlayerState alloc] init];
                            newState.state = EncounteredError;
                            [_delegate mediaPlayerStateChanged:newState];
                        });
                    }
                    
                    break;
                }
            }
        }
    }
    else if (context == PlayerItemPlaybackBufferEmpty)
    {
        if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                PlayerState *newState = [[PlayerState alloc] init];
                newState.state = Opening;
                [_delegate mediaPlayerStateChanged:newState];
            });
        }
    }
    else if (context == PlayerItemLoadedTimeRangesContext)
    {
        float loadedDuration = [self getLoadedDuration];

        if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                PlayerState *newState = [[PlayerState alloc] init];
                newState.state = Buffering;
                newState.valueFloat = loadedDuration;
                [_delegate mediaPlayerStateChanged:newState];
            });
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)playerItemDidPlayToEndTime:(NSNotification *)notification
{
    if (notification.object != _player.currentItem)
        return;
    
    if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            PlayerState *newState = [[PlayerState alloc] init];
            newState.state = EndReached;
            [_delegate mediaPlayerStateChanged:newState];
        });
    }
}

@end
