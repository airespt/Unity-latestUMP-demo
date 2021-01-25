#import "PlayerBase.h"

@implementation PlayerState

- (id)init
{
    self = [super init];
    _state = Empty;
    _valueFloat = -1;
    _valueLong = -1;
    _valueString = nil;
    
    return self;
}

@end

@implementation NSMutableArray (QueueStack)
-(PlayerState*)queuePop {
    @synchronized(self)
    {
        if ([self count] == 0)
            return nil;
        
        PlayerState *queueObject = (PlayerState*)[self objectAtIndex:0];
        [self removeObjectAtIndex:0];
        
        return queueObject;
    }
}

-(void)queuePush:(PlayerState*)anObject {
    @synchronized(self)
    {
        [self addObject:anObject];
    }
}

-(void)clear {
    @synchronized(self)
    {
        [self removeAllObjects];
    }
}
@end
