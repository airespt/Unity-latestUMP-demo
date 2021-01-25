#import "MediaPlayback.h"
#import <MediaPlayer/MediaPlayer.h>

@interface MMPMoviePlayerController : MPMoviePlayerController <MediaPlayback>

- (id)initWithContentURL:(NSURL *)aUrl;
- (id)initWithContentURLString:(NSString *)aUrl;

@end
