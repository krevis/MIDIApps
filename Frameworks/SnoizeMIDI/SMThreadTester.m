//
//  SMThreadTester.m
//  SnoizeMIDI
//
//  Created by Kurt Revis on Sun Dec 16 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMThreadTester.h"
#import <mach/mach.h>
#import <mach/mach_error.h>
#import <mach/mach_time.h>
#import <CoreAudio/CoreAudio.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface SMThreadTester (Private)

- (void)_runInThread:(id)whoCares;
- (void)_setThreadSchedulingPolicy;
- (void)_recordStartTime:(UInt64)time1 endTime:(UInt64)time2 sleepTime:(UInt64)sleepTime;

@end


@implementation SMThreadTester

- (id)init;
{
    if (![super init])
        return nil;

    recordsLock = [[NSLock alloc] init];
    records = [[NSMutableArray alloc] init];
    dataCollectionLock = [[NSLock alloc] init];
    
    [NSThread detachNewThreadSelector:@selector(_runInThread:) toTarget:self withObject:nil];

    return self;
}

- (void)dumpRecords;
{
    unsigned int recordIndex, recordCount;
    int min = INT_MAX, max = INT_MIN;
    double average = 0;

    [dataCollectionLock lock];
    [recordsLock lock];

    fprintf(stderr, "Sleep time should be: %lld\n", savedSleepTime);
    
    recordCount = [records count];
    for (recordIndex = 0; recordIndex < recordCount; recordIndex++) {
        NSNumber *num = [records objectAtIndex:recordIndex];
        int val = (int)[num unsignedIntValue];

        val = val - (int)savedSleepTime;
        
//        fprintf(stderr, "%d\n", val);

        average += val;

        if (val < min)
            min = val;
        if (val > max)
            max = val;
    }

    average /= recordCount + 1;

    fprintf(stderr, "-------\n");
    fprintf(stderr, "%u records\n", recordCount + 1);
    fprintf(stderr, "average: %g\n", average);
    fprintf(stderr, "min: %d\n", min);
    fprintf(stderr, "max: %d\n", max);
    
    [records removeAllObjects];
    
    [recordsLock unlock];
    [dataCollectionLock unlock];
}

@end



@implementation SMThreadTester (Private)

- (void)_runInThread:(id)whoCares;
{
    NSAutoreleasePool *pool;
    NSTimeInterval sleepInterval;
    UInt64 sleepTime;

    pool = [[NSAutoreleasePool alloc] init];

    [self _setThreadSchedulingPolicy];

    sleepInterval = 1.0e-3;	// 1 ms
    sleepTime = AudioConvertNanosToHostTime(sleepInterval * 1.0e9);
    
    NS_DURING {
        while (1) {
            UInt64 time1, time2;
            kern_return_t kernError;

            [dataCollectionLock lock];
            
            time1 = AudioGetCurrentHostTime();

            kernError = mach_wait_until(time1 + sleepTime);
            if (kernError)
                mach_error("mach_wait_until error: ", kernError);

            time2 = AudioGetCurrentHostTime();

            [self _recordStartTime:time1 endTime:time2 sleepTime:sleepTime];

            [dataCollectionLock unlock];
        }
    } NS_HANDLER {
        NSLog(@"exception raised: %@", localException);
    } NS_ENDHANDLER;

    [pool release];
}

- (void)_setThreadSchedulingPolicy;
{
    kern_return_t error;
    thread_time_constraint_policy_data_t policy;

    OBASSERT(![NSThread inMainThread]);
    if ([NSThread inMainThread])
        return;

    /*
        From a message by Jeff Moore <jcm10@apple.com> on the CoreAudio-API mailing list,
        19 November 2001:
        
        pre-emptible: whether or not this thread can be pre-empted
        Always set this to true. Feeder threads have to be pre-emptible by the
        IO threads for audio and MIDI
        
        period: roughly how often the thread is going to wake up
        For a feeder thread being woken by your IOProc, you want to set this to
        the number of host ticks in one buffer's worth of data. This number does
        not need to be 100% accurate to do it's job.
        
        computation: the amount of time until the thread can be pre-empted
        Feeder thread's should be pre-emptible after a very very small amount of
        time, if not immediately. So, set this number very small, if not to 0.
        [Turns out it must actually be between 50us and 50ms, as of 10.1.]
        
        constraint: the amount of time until the your thread becomes a miscreant
        When your thread goes beyond this bound, the scheduler will treat it as
        a misbehaving thread and will punish it accordingly. The scheduler will
        restore the thread's status as soon as it goes to sleep. In general, you
        want this number to be the same as the number you pass to the period
        constraint. This warns the scheduler that you might take 100% of the
        CPU. If you know that you need more or less time to do your work, you
        should adjust this value accordingly.
        
        The scheduler is not 100% accurate, so these numbers don't need to be 100%
        accurate either (although accuracy doesn't hurt anything). Further, you can
        adjust these numbers whenever you like (be aware that this is not a free
        operation, as it involves a kernel transition).
    */

    policy.period = AudioConvertNanosToHostTime(1.0e-3 * 1.0e9);		// 1 ms
    policy.computation = AudioConvertNanosToHostTime(0.1e-3 * 1.0e9);	// 0.1 ms
        // No great thought went into this. I bet we don't really need this much time.    
    policy.constraint = 2 * policy.computation;
        // This is a reasonable setting (the default time-constraint policy is like this, as is the CoreMIDI thread)
    policy.preemptible = 1;

#if DEBUG
    NSLog(@"setting thread to time constraint, period=%ld, computation=%ld, constraint=%ld", policy.period, policy.computation, policy.constraint);
#endif

    error = thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&policy, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    if (error != KERN_SUCCESS) {
        NSLog(@"Couldn't set thread policy: error %s", mach_error_string(error));
    }
}

- (void)_recordStartTime:(UInt64)time1 endTime:(UInt64)time2 sleepTime:(UInt64)sleepTime;
{
    [recordsLock lock];
    savedSleepTime = sleepTime;
    [records addObject:[NSNumber numberWithUnsignedInt:(unsigned int)(time2-time1)]];
    [recordsLock unlock];
}

@end
