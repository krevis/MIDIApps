//
//  SMMessageTimeBase.m
//  SnoizeMIDI
//
//  Created by Kurt Revis on 9/2/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "SMMessageTimeBase.h"

#import "SMHostTime.h"


@implementation SMMessageTimeBase

+ (SMMessageTimeBase*)currentTimeBase
{
    static SMMessageTimeBase* currentTimeBase = nil;
    
    if (!currentTimeBase) {
        // Establish a base of what host time corresponds to what clock time.
        // TODO We should do this a few times and average the results, and also try to be careful not to get
        // scheduled out during this process. We may need to switch ourself to be a time-constraint thread temporarily
        // in order to do this. See discussion in the CoreAudio-API archives.
        UInt64 hostTime = SMGetCurrentHostTime();
        NSTimeInterval timeInterval = [NSDate timeIntervalSinceReferenceDate];
        currentTimeBase = [[SMMessageTimeBase alloc] initWithHostTime:hostTime forTimeInterval:timeInterval];
    }
    
    return currentTimeBase;
}

- (id)initWithHostTime:(UInt64)hostTime forTimeInterval:(NSTimeInterval)timeInterval
{
    if ((self = [super init])) {
        baseHostTime = hostTime;
        baseTimeInterval = timeInterval;        
    }
    
    return self;
}

- (UInt64)hostTime
{
    return baseHostTime;
}

- (NSTimeInterval)timeInterval
{
    return baseTimeInterval;
}

- (void)encodeWithCoder:(NSCoder *)coder
{    
    [coder encodeInt64:baseHostTime forKey:@"hostTime"];
    [coder encodeDouble:baseTimeInterval forKey:@"timeInterval"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super init])) {
        baseHostTime = [decoder decodeInt64ForKey:@"hostTime"]; 
        baseTimeInterval = [decoder decodeDoubleForKey:@"timeInterval"];
    }
    
    return self;
}

@end
