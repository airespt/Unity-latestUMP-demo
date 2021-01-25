#import <Foundation/Foundation.h>

@interface MediaModule : NSObject

+ (MediaModule *)sharedModule;

@property(atomic, getter=isAppIdleTimerDisabled)            BOOL appIdleTimerDisabled;
@property(atomic, getter=isMediaModuleIdleTimerDisabled)    BOOL mediaModuleIdleTimerDisabled;

@end
