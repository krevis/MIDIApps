/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


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
