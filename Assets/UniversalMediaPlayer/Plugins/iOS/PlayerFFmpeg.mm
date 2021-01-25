#include "PlayerFFmpeg.h"

@implementation PlayerFFmpeg

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
    [FFMoviePlayerController setLogReport:NO];
    [FFMoviePlayerController setLogLevel:k_LOG_SILENT];
    [FFMoviePlayerController checkIfFFmpegVersionMatch:NO];
    
    _ffOptions = [FFOptions optionsByDefault];
    [_ffOptions setPlayerOptionIntValue:1 forKey:@"start-on-prepared"];
    
    for(NSString *option in options)
    {
        NSArray *optionData = [option componentsSeparatedByString:@"="];
        if ([optionData count] > 1)
        {
            [_ffOptions setPlayerOptionIntValue:[optionData[1] integerValue] forKey:optionData[0]];
        }
        else
        {
			if ([optionData[0] isEqual: @"play-in-background"])
            {
                _playInBackground = true;
                continue;
            }
            
            if ([optionData[0] isEqual: @"rtsp-tcp"])
            {
                [_ffOptions setFormatOptionValue:@"tcp" forKey:@"rtsp_transport"];
                continue;
            }
			
            [_ffOptions setPlayerOptionIntValue:1 forKey:optionData[0]];
        }
    }
    
    [self initMediaPlayer];
}

- (void)initMediaPlayer
{
    _player = [[FFMoviePlayerController alloc] initWithOptions:_ffOptions];
    [_player setPauseInBackground:!_playInBackground];
    _cachedPlaybackTime = -1;
    _cachedBuffering = -1;
    _hasVideoTrack = false;
    _isBuffering = false;
    
    [self installMovieNotificationObservers];
}

- (void)setDataSource:(NSString *)path
{
    _videoPath = path;
}

- (void)play
{
    if (_player == nil)
        [self initMediaPlayer];
    
    if (![_player isPreparedToPlay])
    {
        [_player setDataSourceURL:[NSURL URLWithString:_videoPath]];
        [_player prepareToPlay];
        
        if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                PlayerState *newState = [[PlayerState alloc] init];
                newState.state = Opening;
                [_delegate mediaPlayerStateChanged:newState];
            });
        }
    }
    else
        [_player play];
}

- (void)pause
{
    [_player pause];
}

- (void)stop
{
    if (_player != nil)
    {
        [_player shutdown];
        [self removeMovieNotificationObservers];
        _player = nil;
        
        if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
        {
            PlayerState *newState = [[PlayerState alloc] init];
            newState.state = Stopped;
            [_delegate mediaPlayerStateChanged:newState];
        }
    }
}

- (int)getDuration
{
    return [_player duration] * 1000;
}

- (CVPixelBufferRef)getPixelBuffer
{
    return [_player videoBuffer];
}

- (int)getFramesCounter
{
    if (_isBuffering && _cachedBuffering != _player.bufferingProgress
        && _cachedBuffering < _player.bufferingProgress)
    {
        _cachedBuffering = _player.bufferingProgress;
        
        if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                PlayerState *newState = [[PlayerState alloc] init];
                newState.state = Buffering;
                newState.valueFloat = (float)_cachedBuffering;
                [_delegate mediaPlayerStateChanged:newState];
            });
        }
    }
    
    if ([self isReady] && [self isPlaying])
    {
        float currentTime = [_player currentPlaybackTime];
        if (fabs(currentTime - _cachedPlaybackTime) > TIME_CHANGE_OFFSET)
        {
            if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PlayerState *newState = [[PlayerState alloc] init];
                    newState.state = TimeChanged;
                    newState.valueLong = currentTime * 1000;
                    [_delegate mediaPlayerStateChanged:newState];
                });
            }
            
            if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PlayerState *newState = [[PlayerState alloc] init];
                    newState.state = PositionChanged;
                    newState.valueFloat = currentTime / [_player duration];
                    [_delegate mediaPlayerStateChanged:newState];
                });
            }
            
            _cachedPlaybackTime = [_player currentPlaybackTime];
        }
    }
    
    return (int)[_player frameCount];
}


- (int)getVolume
{
    return [_player playbackVolume] * 100;
}

- (void)setVolume:(int)value
{
    [_player setPlaybackVolume:(float)value / 100.0];
}

- (int)getTime
{
    return [_player currentPlaybackTime] * 1000;
}

- (void)setTime:(int)value
{
    [_player setCurrentPlaybackTime:value];
}

- (float)getPosition
{
    float position = [_player currentPlaybackTime] / [_player duration];
    return position;
}

- (void)setPosition:(float)value
{
    float position = [_player duration] * value;
    [_player setCurrentPlaybackTime:position];
}

- (float)getPlaybackRate
{
    return [_player playbackRate];
}

- (void)setPlaybackRate:(float)value
{
    [_player setPlaybackRate:value];
}

- (bool)isPlaying
{
    return [_player isPlaying];
}

- (bool)isReady
{
    return _hasVideoTrack ? [_player frameCount] > 0 : [_player isPreparedToPlay];
}

- (int)getVideoWidth
{
    return [_player videoWidth];
}

- (int)getVideoHeight
{
    return [_player videoHeight];
}

- (void)movieVideoDecoderOpen:(NSNotification*)notification
{
    _hasVideoTrack = true;
}

- (void)loadStateDidChange:(NSNotification*)notification
{
    switch (_player.loadState)
    {
        case MMPMovieLoadStateStalled:
            _isBuffering = true;
            break;
            
        case MMPMovieLoadStatePlayable | MMPMovieLoadStatePlaythroughOK:
            _isBuffering = false;
            _cachedBuffering = -1;
            break;
    }
}

- (void)moviePlayBackDidFinish:(NSNotification*)notification
{
    int reason = [[[notification userInfo] valueForKey:MMPMoviePlayerPlaybackDidFinishReasonUserInfoKey] intValue];
    
    switch (reason)
    {
        case MMPMovieFinishReasonPlaybackEnded:
            if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PlayerState *newState = [[PlayerState alloc] init];
                    newState.state = EndReached;
                    [_delegate mediaPlayerStateChanged:newState];
                });
            }
            break;
            
        case MMPMovieFinishReasonUserExited:
            break;
            
        case MMPMovieFinishReasonPlaybackError:
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

- (void)mediaIsPreparedToPlayDidChange:(NSNotification*)notification
{
    NSLog(@"mediaIsPreparedToPlayDidChange\n");
}

- (void)moviePlayBackStateDidChange:(NSNotification*)notification
{
    switch (_player.playbackState)
    {
        case MMPMoviePlaybackStatePlaying:
            break;
            
        case MMPMoviePlaybackStatePaused:
            if ([_delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PlayerState *newState = [[PlayerState alloc] init];
                    newState.state = Paused;
                    [_delegate mediaPlayerStateChanged:newState];
                });
            }
            break;
            
        case MMPMoviePlaybackStateInterrupted:
            break;
            
        case MMPMoviePlaybackStateSeekingForward:
        case MMPMoviePlaybackStateSeekingBackward:
            break;
            
        default:
            break;
    }
}

-(void)installMovieNotificationObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadStateDidChange:)
                                                 name:MMPMoviePlayerLoadStateDidChangeNotification
                                               object:_player];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:MMPMoviePlayerPlaybackDidFinishNotification
                                               object:_player];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mediaIsPreparedToPlayDidChange:)
                                                 name:MMPMediaPlaybackIsPreparedToPlayDidChangeNotification
                                               object:_player];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackStateDidChange:)
                                                 name:MMPMoviePlayerPlaybackStateDidChangeNotification
                                               object:_player];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(movieVideoDecoderOpen:)
                                                 name:MMPMoviePlayerVideoDecoderOpenNotification
                                               object:_player];
}

-(void)removeMovieNotificationObservers
{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:MMPMoviePlayerLoadStateDidChangeNotification object:_player];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:MMPMoviePlayerPlaybackDidFinishNotification object:_player];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:MMPMediaPlaybackIsPreparedToPlayDidChangeNotification object:_player];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:MMPMoviePlayerPlaybackStateDidChangeNotification object:_player];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:MMPMoviePlayerVideoDecoderOpenNotification object:_player];
}

@end
