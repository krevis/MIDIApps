//
//  SMClockGenerator.m
//  SnoizeMIDI
//
//  Created by krevis on Sun Dec 09 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMClockGenerator.h"
#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreMIDI/CoreMIDI.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import "SMScheduler.h"
#import "SMSystemRealTimeMessage.h"

@interface SMClockGenerator (Private)

- (void)_nextEvent;

@end


@implementation SMClockGenerator

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    tempoLock = [[NSLock alloc] init];
    eventLock = [[NSLock alloc] init];
    
    [self setTempo:120.0];

    return self;
}

- (void)dealloc;
{
    [tempoLock release];
    tempoLock = nil;

    [eventLock release];
    eventLock = nil;

    nonretainedMessageDestination = nil;

    [savedEvent release];
    savedEvent = nil;

    [super dealloc];
}

- (id<SMMessageDestination>)messageDestination;
{
    return nonretainedMessageDestination;
}

- (void)setMessageDestination:(id<SMMessageDestination>)aMessageDestination;
{
    nonretainedMessageDestination = aMessageDestination;
}

- (double)tempo;
{
    return tempo;
}

- (void)setTempo:(double)value;
{
    [tempoLock lock];

    tempo = value;
    // Convert from beats/minute to seconds/clock. We need 24 clocks for each beat.
    clockTimeStampDelta = AudioConvertNanosToHostTime(((60.0 / tempo) / 24.0) * 1.0e9);

    [tempoLock unlock];

    // TODO If the tempo changed, we will want to reschedule the next clock.
    // (Otherwise, the tempo change will not take effect until after the next clock is sent.)
    // HOWEVER: That would require us to remove the currently pending clock message,
    // which may or may not have made its way to CoreMIDI yet... and there is really no way
    // to effectively do this. And if it is in CoreMIDI already, then there is no way to remove
    // that event without nuking everything else pending for that endpoint.
    // So I guess we'll live with it the way it is for now.
}

- (void)start;
{
    OBASSERT([NSThread inMainThread]);
    // TODO Look into allowing this from other threads
    
    if ([self isRunning]) {
#if DEBUG
        NSLog(@"-[SMClockGenerator start] called while already running; ignoring");
#endif
        return;
    }

    lastClockTimeStamp = 0;
    [self _nextEvent];
}

- (void)stop;
{
    OBASSERT([NSThread inMainThread]);
    // TODO Look into allowing this from other threads

    [eventLock lock];
    if (savedEvent) {
        [[SMScheduler midiScheduler] abortEvent:savedEvent];
        [savedEvent release];
        savedEvent = nil;

        // TODO should we send a stop message?
        // TODO and then what about the messages which have already gone out?
    } else {
#if DEBUG
        NSLog(@"-[SMClockGenerator stop] called while not running; ignoring");
#endif    
    }
    [eventLock unlock];
}

- (BOOL)isRunning;
{
    // No need to acquire the lock for this atomic operation
    return (savedEvent != nil);
}

@end


@implementation SMClockGenerator (Private)

- (void)_nextEvent;
{
    MIDITimeStamp currentTimeStamp, nextClockTimeStamp;
    BOOL sendStart = NO;
    BOOL sendClock = NO;    
    NSTimeInterval delay;
    
    currentTimeStamp = AudioGetCurrentHostTime();
    // TODO: If there is an advance schedule time for the endpoint or device we're talking to,
    // it should be added to currentTimeStamp here.  (Probably need to revisit all of this.)

    if (lastClockTimeStamp == 0) {
        // We are just starting. Send a MIDI Start message, and then a clock 100ms afterwards.
        // ("Start" really means "get ready to start"; the device doesn't actually start until the clock message is received. The device may need some time to get ready after receiving the Start.)
        // TODO Maybe we should provide "start at time X" in the API... or provide some way to get
        // the timestamp of the start event.
        // TODO Can we turn this down to less than 100ms? It's a noticeable delay...
        sendStart = YES;
        nextClockTimeStamp = currentTimeStamp + AudioConvertNanosToHostTime(100.0e-3 * 1.0e9);
        sendClock = YES;
        
    } else if (currentTimeStamp < lastClockTimeStamp) {
        // Nothing to do yet--we've woken up early. This shouldn't really happen.
#if DEBUG
        NSLog(@"woke up early! current: %@  clock will go out at %@  delta: %@",
            [SMMessage formatTimeStamp:currentTimeStamp usingOption:SMTimeFormatClockTime],
            [SMMessage formatTimeStamp:lastClockTimeStamp usingOption:SMTimeFormatClockTime],
            [SMMessage formatTimeStamp:clockTimeStampDelta usingOption:SMTimeFormatHostTimeSeconds]);
#endif
        
    } else {
        // We've passed the time of the last sent clock.
        MIDITimeStamp localClockTimeStampDelta;
        
        [tempoLock lock];
        localClockTimeStampDelta = clockTimeStampDelta;
        [tempoLock unlock];
        
        if (currentTimeStamp - lastClockTimeStamp >= localClockTimeStampDelta) {
            // It took too long to wake up, and we've missed a clock.
#if DEBUG
            NSLog(@"missed clock! current: %@  last clock was sent at: %@  delta: %@",
                [SMMessage formatTimeStamp:currentTimeStamp usingOption:SMTimeFormatClockTime],
                [SMMessage formatTimeStamp:lastClockTimeStamp usingOption:SMTimeFormatClockTime],
                [SMMessage formatTimeStamp:localClockTimeStampDelta usingOption:SMTimeFormatHostTimeSeconds]);
#endif
            // To recover, send a clock as soon as possible. This isn't really great, but what else can we do?
            nextClockTimeStamp = currentTimeStamp;
            sendClock = YES;
            
        } else {
            // We can send another clock, right on time.
            nextClockTimeStamp = lastClockTimeStamp + localClockTimeStampDelta;
            sendClock = YES;

        }
    }

    if (sendStart || sendClock) {
        NSMutableArray *messages;
        SMMessage *message;
        
        messages = [NSMutableArray arrayWithCapacity:2];
        
        if (sendStart) {
            message = [SMSystemRealTimeMessage systemRealTimeMessageWithTimeStamp:currentTimeStamp type:SMSystemRealTimeMessageTypeStart];
            [messages addObject:message];
        }
        
        if (sendClock) {
            message = [SMSystemRealTimeMessage systemRealTimeMessageWithTimeStamp:nextClockTimeStamp type:SMSystemRealTimeMessageTypeClock];
            [messages addObject:message];
    
            lastClockTimeStamp = nextClockTimeStamp;
        }
        
        [nonretainedMessageDestination takeMIDIMessages:messages];
    }

    // Schedule a wakeup at lastClockTimeStamp
    delay = AudioConvertHostTimeToNanos(lastClockTimeStamp - currentTimeStamp) / 1.0e9;
    [eventLock lock];
    [savedEvent release];
    savedEvent = [[[SMScheduler midiScheduler] scheduleSelector:@selector(_nextEvent) onObject:self afterTime:delay] retain];
    [eventLock unlock];
}

@end
