//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>


@protocol SMPeriodicTimerListener <NSObject>
- (void)periodicTimerFiredForStart:(UInt64)startTime end:(UInt64)endTime;
@end


@interface SMPeriodicTimer : OFObject
{
    NSMutableArray *listeners;
    NSLock *listenersLock;
}

+ (SMPeriodicTimer *)sharedPeriodicTimer;

- (void)addListener:(id<SMPeriodicTimerListener>)listener;
- (void)removeListener:(id<SMPeriodicTimerListener>)listener;

@end
