#ifndef IJKSDLGLViewProtocol_h
#define IJKSDLGLViewProtocol_h

#import <UIKit/UIKit.h>

typedef struct MMPOverlay IJKOverlay;
struct MMPOverlay {
    int w;
    int h;
    UInt32 format;
    int planes;
    UInt16 *pitches;
    UInt8 **pixels;
    int sar_num;
    int sar_den;
    CVPixelBufferRef pixel_buffer;
};

@protocol SDLGLViewProtocol <NSObject>
- (UIImage*) snapshot;
@property(nonatomic, readonly) CGFloat  fps;
@property(nonatomic)        CGFloat  scaleFactor;
@property(nonatomic)        BOOL  isThirdGLView;
- (void) display_pixels: (IJKOverlay *) overlay;
@end

#endif /* IJKSDLGLViewProtocol_h */
