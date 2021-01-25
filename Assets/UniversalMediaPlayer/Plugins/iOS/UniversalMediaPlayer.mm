#include "UniversalMediaPlayer.h"

@implementation UniversalMediaPlayer

- (id)init
{
    if (self = [super init])
    {
        _playerStates = [NSMutableArray array];
        _cachedVolume = -1;
        _cachedRate = -1;
    }
    
    return self;
}

- (void)setupPlayer:(NSString *)options
{
    options = [options stringByReplacingOccurrencesOfString:@":" withString:@""];
    NSArray *optionsArray = [options componentsSeparatedByString:@"\n"];
    _playerType = FFmpeg;
    
    for(NSString *option in optionsArray)
    {
        NSArray *optionData = [option componentsSeparatedByString:@"="];
        
        if ([optionData[0] isEqual: @"player-type"])
            _playerType = (PlayerTypes)[optionData[1] integerValue];
    }
    
#if NATIVE
    if (_playerType == Native)
        _player = [[PlayerNative alloc] init];
#endif
    
#if FFMPEG
    if (_playerType == FFmpeg)
        _player = [[PlayerFFmpeg alloc] init];
#endif
    
    [self setupAudioSession];
    [_player setupPlayer:optionsArray];
    _player.delegate = self;
}

- (void)setupAudioSession
{
    NSError *categoryError = nil;
    BOOL success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&categoryError];
    if (!success)
    {
        NSLog(@"Error setting audio session category: %@", categoryError);
    }
    
    NSError *activeError = nil;
    success = [[AVAudioSession sharedInstance] setActive:YES error:&activeError];
    if (!success)
    {
        NSLog(@"Error setting audio session active: %@", activeError);
    }
}

- (int)getFramesCounter
{
    return [_player getFramesCounter];
}

- (CMVideoSampling*)getVideoSampling
{
    return &_videoSampling;
}

- (CVPixelBufferRef)getPixelBuffer
{
    return [_player getPixelBuffer];
}

- (void)setDataSource:(NSString *)path
{
    [_player setDataSource:path];
}

- (void)play
{
    if (_videoSampling.cvTextureCache == nil)
        CMVideoSampling_Initialize(&_videoSampling);
    
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
        _cachedVolume = [_player getVolume];
        _cachedRate = [_player getPlaybackRate];
        
        [_player stop];
        CMVideoSampling_Uninitialize(&_videoSampling);
    }
}

- (int)getDuration
{
    return [_player getDuration];
}

- (int)getVolume
{
    return [self isReady] ? [_player getVolume] : _cachedVolume;
}

- (void)setVolume:(int)value
{
    if ([self isReady])
        [_player setVolume:value];
    else
        _cachedVolume = value;
}

- (int)getTime
{
    return [_player getTime];
}

- (void)setTime:(int)value
{
    [_player setTime:value];
}

- (float)getPosition
{
    return [_player getPosition];
}

- (void)setPosition:(float)value
{
    [_player setPosition:value];
}

- (float)getPlaybackRate
{
    return [self isReady] ? [_player getPlaybackRate] : _cachedRate;
}

- (void)setPlaybackRate:(float)value
{
    if ([self isReady])
        [_player setPlaybackRate:value];
    else
        _cachedRate = value;
}

- (bool)isPlaying
{
    return [_player isPlaying];
}

- (bool)isReady
{
    return [_player isReady];
}

- (int)getVideoWidth
{
    return [_player getVideoWidth];
}

- (int)getVideoHeight
{
    return [_player getVideoHeight];
}

- (void)mediaPlayerStateChanged:(PlayerState*)state
{
    [_playerStates queuePush:state];
}

@end

static std::vector<UniversalMediaPlayer*> _players;

static NSString* CreateNSString(const char* string)
{
    if (string != NULL)
        return [NSString stringWithUTF8String:string];
    else
        return [NSString stringWithUTF8String:""];
}

intptr_t CMVideoSampling_SampleBuffer(CMVideoSampling* sampling, CVImageBufferRef pixelBuffer)
{
    intptr_t retTex = 0;
    
    if (sampling->cvImageBuffer)
        CFRelease(sampling->cvImageBuffer);
    
    sampling->cvImageBuffer = pixelBuffer;
    CFRetain(sampling->cvImageBuffer);
    
    int w = (int)CVPixelBufferGetWidth((CVImageBufferRef)sampling->cvImageBuffer);
    int h = (int)CVPixelBufferGetHeight((CVImageBufferRef)sampling->cvImageBuffer);
    if (sampling->cvTextureCacheTexture)
    {
        CFRelease(sampling->cvTextureCacheTexture);
        FlushCVTextureCache(sampling->cvTextureCache);
    }
    
#if BGRA32
    sampling->cvTextureCacheTexture = CreateBGRA32TextureFromCVTextureCache(sampling->cvTextureCache, sampling->cvImageBuffer, w, h);
#else
    sampling->cvTextureCacheTexture = CreateTextureFromCVTextureCache(sampling->cvTextureCache, sampling->cvImageBuffer, w, h);
#endif
    
    if (sampling->cvTextureCacheTexture)
        retTex = GetTextureFromCVTextureCache(sampling->cvTextureCacheTexture);
    
    if (UnitySelectedRenderingAPI() == apiOpenGLES2 || UnitySelectedRenderingAPI() == apiOpenGLES3)
    {
        GLint oldTexBinding = 0;
        
        glGetIntegerv(GL_TEXTURE_BINDING_2D, &oldTexBinding);
        glBindTexture(GL_TEXTURE_2D, (GLuint)retTex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glBindTexture(GL_TEXTURE_2D, oldTexBinding);
    }
    
    return retTex;
}

extern "C"
{
    int UMPNativeInit()
    {
        _players.push_back([[UniversalMediaPlayer alloc] init]);
        return (int)_players.size();
    }
    
    void UMPNativeInitPlayer(int index, char *options)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        NSString *optionsString = CreateNSString(options);
        [player setupPlayer:optionsString];
    }
    
    int UMPGetBufferingPercentage()
    {
        return 0;
    }
    
    intptr_t UMPNativeGetTexturePointer(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        CMVideoSampling* sampling = [player getVideoSampling];
        intptr_t texture = CMVideoSampling_LastSampledTexture(sampling);
        
        if (player.playerType == Native || texture == 0)
        {
            CVPixelBufferRef pixelBuffer = [player getPixelBuffer];
            if (pixelBuffer != nil)
                texture = CMVideoSampling_SampleBuffer(sampling, pixelBuffer);
        }

        return texture;
    }
    
    void UMPNativeUpdateTexture(int index, intptr_t texture) {}
    
    void UMPNativeSetPixelsBuffer(int index, unsigned char *buffer, int width, int height)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        player.frameBuffer = buffer;
    }
    
    void UMPNativeUpdateFrameBuffer(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        if (kCVReturnSuccess == CVPixelBufferLockBaseAddress([player getPixelBuffer], kCVPixelBufferLock_ReadOnly))
		{
            unsigned char *tmpBuffer = (uint8_t*)CVPixelBufferGetBaseAddress([player getPixelBuffer]);
            memcpy(player.frameBuffer, tmpBuffer, player.getVideoWidth * player.getVideoHeight * 4);
            CVPixelBufferUnlockBaseAddress([player getPixelBuffer], kCVPixelBufferLock_ReadOnly);
        }
    }
    
    void UMPSetDataSource(int index, char *path)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        NSString *pathString = CreateNSString(path);
        [player setDataSource:pathString];
    }
    
    bool UMPPlay(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        [player play];
        return true;
    }
    
    void UMPPause(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        [player pause];
    }
    
    void UMPStop(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        [player stop];
    }
    
    void UMPRelease(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        [player stop];
    }
	
	bool UMPIsPlaying(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        return [player isPlaying];
    }
    
    bool UMPIsReady(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        return [player isReady];
    }
    
    int UMPGetLength(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        return [player getDuration];
    }
	
	int UMPGetTime(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        return [player getTime];
    }
    
    void UMPSetTime(int index, int time)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        [player setTime:time];
    }
    
    float UMPGetPosition(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        return [player getPosition];
    }
    
    void UMPSetPosition(int index, float position)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        [player setPosition:position];
    }
	
	float UMPGetRate(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        return [player getPlaybackRate];
    }
    
	void UMPSetRate(int index, float rate)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        if (rate != player.getPlaybackRate)
            [player setPlaybackRate:rate];
    }
    
    int UMPGetVolume(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        return [player getVolume];
    }
    
    void UMPSetVolume(int index, int value)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        [player setVolume:value];
    }
	
	bool UMPGetMute(int index)
    {
        return false;
    }
	
	void UMPSetMute(int index, bool state)
    {
    }
    
    int UMPVideoWidth(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        return [player getVideoWidth];
    }
    
    int UMPVideoHeight(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        return [player getVideoHeight];
    }
    
    long UMPVideoFrameCount(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        if ([player isReady])
        {
            if (player.cachedVolume >= 0)
            {
                [player setVolume:player.cachedVolume];
                player.cachedVolume = -1;
            }
        
            if (player.cachedRate >= 0)
            {
                [player setPlaybackRate:player.cachedRate];
                player.cachedRate = -1;
            }
        }
        
        return [player getFramesCounter];
    }
	
	int UMPGetState(int index)
	{
        UniversalMediaPlayer *player = _players.at(index - 1);
        
        if (player.playerStates.count > 0)
        {
            player.playerState = player.playerStates.queuePop;
            return player.playerState.state;
        }
        
        return Empty;
	}
    
    float UMPGetStateFloatValue(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        return player.playerState.valueFloat;
    }
    
    long UMPGetStateLongValue(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        return player.playerState.valueLong;
    }
    
    char* UMPGetStateStringValue(int index)
    {
        UniversalMediaPlayer *player = _players.at(index - 1);
        return player.playerState.valueString;
    }
}
