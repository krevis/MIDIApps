//
//  SMPeriodicTimer.h
//  SnoizeMIDI
//
//  Created by Kurt Revis on Mon Dec 17 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OmniFoundation/OFObject.h>


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
