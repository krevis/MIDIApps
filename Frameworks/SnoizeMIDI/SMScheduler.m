//
//  SMScheduler.m
//  SnoizeMIDI
//
//  Created by krevis on Sun Dec 09 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMScheduler.h"
#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <mach/mach.h>
#import <mach/mach_error.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface SMScheduler (Private)

- (void)_setThreadSchedulingPolicy;

@end


@implementation SMScheduler

static NSLock *midiSchedulerLock;
static SMScheduler *midiScheduler = nil;

+ (void)initialize;
{
    OBINITIALIZE;
    midiSchedulerLock = [[NSLock alloc] init];
}

+ (SMScheduler *)midiScheduler;
{
    if (midiScheduler)
        return midiScheduler;

    [midiSchedulerLock lock];
    if (midiScheduler == nil) {
        midiScheduler = [[self alloc] init];
        [midiScheduler setInvokesEventsInMainThread:NO];
        [midiScheduler runScheduleForeverInNewThread];
    }
    [midiSchedulerLock unlock];

    [midiScheduler scheduleSelector:@selector(_setThreadSchedulingPolicy) onObject:midiScheduler afterTime:0.0];

    return midiScheduler;
}

@end


@implementation SMScheduler (Private)

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

//    policy.period = AudioConvertNanosToHostTime(125.0e-6 * 1.0e9);	// 125 us
    policy.period = 0;
        // At 500 BPM, 960 ticks/beat, we need  a tick every 125 us
    policy.computation = AudioConvertNanosToHostTime(62.5e-6 * 1.0e9);	// 62.5 us
        // No great thought went into this--just half the period. I bet we don't really need this much time.
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

@end
