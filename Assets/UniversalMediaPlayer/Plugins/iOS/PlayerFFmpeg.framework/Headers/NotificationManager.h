#import <Foundation/Foundation.h>

@interface NotificationManager : NSObject

- (nullable instancetype)init;

- (void)addObserver:(nonnull id)observer
           selector:(nonnull SEL)aSelector
               name:(nullable NSString *)aName
             object:(nullable id)anObject;

- (void)removeAllObservers:(nonnull id)observer;

@end
