//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMPeriodicTimer.h"

#import <mach/mach.h>
#import <mach/mach_error.h>
#import <mach/mach_time.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMHostTime.h"


@interface SMPeriodicTimer (Private)

- (void)runInThread:(id)object;
- (void)setThreadSchedulingPolicy;

@end


@implementation SMPeriodicTimer

static NSLock *sharedPeriodicTimerLock;
static SMPeriodicTimer *sharedPeriodicTimer = nil;

+ (void)initialize;
{
    OBINITIALIZE;
    sharedPeriodicTimerLock = [[NSLock alloc] init];
}

+ (SMPeriodicTimer *)sharedPeriodicTimer;
{
    if (sharedPeriodicTimer)
        return sharedPeriodicTimer;

    [sharedPeriodicTimerLock lock];
    if (!sharedPeriodicTimer)
        sharedPeriodicTimer = [[self alloc] init];
    [sharedPeriodicTimerLock unlock];
    return sharedPeriodicTimer;
}

- (id)init;
{
    if (![super init])
        return nil;

    listeners = [[NSMutableArray alloc] init];
    listenersLock = [[NSLock alloc] init];
    
    [NSThread detachNewThreadSelector:@selector(runInThread:) toTarget:self withObject:nil];

    return self;
}

- (void)dealloc;
{
    [listeners release];
    listeners = nil;
    [listenersLock release];
    listenersLock = nil;
    
    [super dealloc];
}

- (void)addListener:(id<SMPeriodicTimerListener>)listener;
{
    [listenersLock lock];
    [listeners addObject:listener];
    [listenersLock unlock];
}

- (void)removeListener:(id<SMPeriodicTimerListener>)listener;
{
    [listenersLock lock];
    [listeners removeObjectIdenticalTo:listener];
    [listenersLock unlock];
}

@end


@implementation SMPeriodicTimer (Private)

static const UInt64 sliceTimeNanoseconds = 10.0e-3 * 1.0e9;	// 10 ms

- (void)runInThread:(id)object;
{
    NSAutoreleasePool *pool;
    UInt64 sliceTime;
    BOOL started = NO;
    UInt64 processEndTime;

    pool = [[NSAutoreleasePool alloc] init];

    [self setThreadSchedulingPolicy];

    sliceTime = SMConvertNanosToHostTime(sliceTimeNanoseconds);

    while (1) {
        NSAutoreleasePool *pool2;
        UInt64 currentTime;
        UInt64 processStartTime;

        currentTime = SMGetCurrentHostTime();

        if (!started) {
            // We are starting.
            // Right now, we want to process all events from now up until the end of the next slice.
            processStartTime = currentTime;
            processEndTime = currentTime + sliceTime;

            // And come back around a second time, a little later.
        } else {
            // We are still running.
            // Hopefully, the current time is earlier than the last processEndTime.

            processStartTime = processEndTime;	// last processEndTime
            if (currentTime < processStartTime) {
                // We are ahead of time, as we should be
                processEndTime = processStartTime + sliceTime;
            } else {
                // We are falling behind, and missed the opportunity to send some messages on time.
                // Do some extra work to try to get ahead again.
                processEndTime = currentTime + sliceTime;
            }
        }

        pool2 = [[NSAutoreleasePool alloc] init];

        [listenersLock lock];
        NS_DURING {
            unsigned int listenerCount, listenerIndex;

            // Our listeners should process events which will happen in the next slice in the future.
            // That is, in the interval (processStartTime, processEndTime].
            listenerCount = [listeners count];
            for (listenerIndex = 0; listenerIndex < listenerCount; listenerIndex++) {
                [[listeners objectAtIndex:listenerIndex] periodicTimerFiredForStart:processStartTime end:processEndTime];
            }
        } NS_HANDLER {
            NSLog(@"SMPeriodicTimer: A listener raised an exception: %@", localException);
        } NS_ENDHANDLER;
        [listenersLock unlock];

        [pool2 release];

        if (!started) {
            started = YES;
            // Go on and process another slice immediately
        } else {
            UInt64 currentTimeAtEnd;

            currentTimeAtEnd = SMGetCurrentHostTime();
            if (processStartTime > currentTimeAtEnd) {
                // Wait for a while.
                kern_return_t error;

                // TODO: Should we use usleep() or nanosleep() instead of mach_wait_until()?
                error = mach_wait_until(processStartTime);
                if (error)
                    mach_error("SMPeriodicTimer: mach_wait_until error: ", error);
            } else {
                // We took longer than we would have liked.
                // Continue on instead of waiting (but give some other threads some time first);
                sched_yield();	// TODO is this really necessary or even beneficial? It seems like the Nice Thing To Do--maybe too nice.
            }
        }
    }
        
    [pool release];
}

- (void)setThreadSchedulingPolicy;
#if 1
{
    kern_return_t error;
    thread_extended_policy_data_t extendedPolicy;
    thread_precedence_policy_data_t precedencePolicy;

    OBASSERT(![NSThread inMainThread]);
    if ([NSThread inMainThread])
        return;

    // Increase this thread's priority, and turn off timesharing.

    extendedPolicy.timeshare = 0;
    error = thread_policy_set(mach_thread_self(), THREAD_EXTENDED_POLICY,  (thread_policy_t)&extendedPolicy, THREAD_EXTENDED_POLICY_COUNT);
    if (error != KERN_SUCCESS) {
#if DEBUG
        mach_error("Couldn't set periodic timer thread's extended policy", error);
#endif
    }

    precedencePolicy.importance = 4; // TODO play with this and parameterize
    error = thread_policy_set(mach_thread_self(), THREAD_PRECEDENCE_POLICY, (thread_policy_t)&precedencePolicy, THREAD_PRECEDENCE_POLICY_COUNT);
    if (error != KERN_SUCCESS) {
#if DEBUG
        mach_error("Couldn't set periodic timer thread's precedence policy", error);
#endif
    }
}
#else
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

    //
    // TODO TODO TODO
    // Investigate whether we can just a non-timeshare thread with an increased priority,
    // instead of a heavyweight time-constraint thread.
    //
    
    policy.period = SMConvertNanosToHostTime(sliceTimeNanoseconds);
    policy.computation = SMConvertNanosToHostTime(sliceTimeNanoseconds / 2);
        // TODO No great thought went into this. I bet we don't really need this much time.
    policy.constraint = 2 * policy.computation;
        // This is a reasonable setting (the default time-constraint policy is like this, as is the CoreMIDI thread)
    policy.preemptible = 1;

#if DEBUG
    NSLog(@"setting SMPeriodicTimer thread to time constraint, period=%ld, computation=%ld, constraint=%ld", policy.period, policy.computation, policy.constraint);
#endif

    error = thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&policy, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    if (error != KERN_SUCCESS) {
        NSLog(@"Couldn't set thread policy: error %s", mach_error_string(error));
    }
}
#endif

@end
