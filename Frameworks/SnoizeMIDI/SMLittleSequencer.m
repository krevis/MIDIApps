//
//  SMLittleSequencer.m
//  SnoizeMIDI
//
//  Created by Kurt Revis on Thu Dec 13 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMLittleSequencer.h"
#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreMIDI/CoreMIDI.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import "SMScheduler.h"
#import "SMMessage.h"


@interface SMLittleSequencer (Private)

- (void)_nextEvent;

@end


@implementation SMLittleSequencer

- (id)init;
{
    unsigned int messageIndex;

    if (!(self = [super init]))
        return nil;

    messages = [[NSMutableArray alloc] init];
    messageIndex = 16;
    while (messageIndex--) {
        [messages addObject:[NSNull null]];
    }

    messagesLock = [[NSLock alloc] init];
    tempoLock = [[NSLock alloc] init];
    eventLock = [[NSLock alloc] init];

    [self setTempo:120.0];

    return self;
}

- (void)dealloc;
{
    nonretainedMessageDestination = nil;

    [messages release];
    messages = nil;
    [messagesLock release];
    messagesLock = nil;
    [tempoLock release];
    tempoLock = nil;
    [savedEvent release];
    savedEvent = nil;
    [eventLock release];
    eventLock = nil;

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

- (unsigned int)messageCount;
{
    return [messages count];
}

- (SMMessage *)messageAtIndex:(unsigned int)index;
{
    id object;

    [messagesLock lock];
    object = [[messages objectAtIndex:index] retain];
    [messagesLock unlock];
    if (object == [NSNull null])
        return nil;
    else
        return [object autorelease];
}

- (void)setMessage:(SMMessage *)message atIndex:(unsigned int)index;
{
    [messagesLock lock];
    [messages replaceObjectAtIndex:index withObject:message];
    [messagesLock unlock];
}

- (double)tempo;
{
    return tempo;
}

- (void)setTempo:(double)value;
{
    [tempoLock lock];

    tempo = value;
    // Convert from beats/minute to seconds/event. We need 4 events for each beat.
    eventTimeStampDelta = AudioConvertNanosToHostTime(((60.0 / tempo) / 4.0) * 1.0e9);

    [tempoLock unlock];
}

- (void)start;
{
    OBASSERT([NSThread inMainThread]);
    // TODO Look into allowing this from other threads

    if ([self isRunning]) {
#if DEBUG
        NSLog(@"-[SMLittleSequencer start] called while already running; ignoring");
#endif
        return;
    }

    lastEventTimeStamp = 0;
    nextMessageIndex = 0;
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

        // TODO and then what about the messages which have already gone out?
    } else {
#if DEBUG
        NSLog(@"-[SMLittleSequencer stop] called while not running; ignoring");
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


@implementation SMLittleSequencer (Private)

- (void)_nextEvent;
{
    MIDITimeStamp currentTimeStamp;
    BOOL sendEvent = NO;
    NSTimeInterval delay;

    currentTimeStamp = AudioGetCurrentHostTime();
    // TODO: If there is an advance schedule time for the endpoint or device we're talking to,
    // it should be added to currentTimeStamp here.  (Probably need to revisit all of this.)

    if (lastEventTimeStamp == 0) {
        // We are just starting.
        lastEventTimeStamp = currentTimeStamp;
        sendEvent = YES;

    } else if (currentTimeStamp < lastEventTimeStamp) {
        // Nothing to do yet--we've woken up early. This shouldn't really happen.

    } else {
        // We've passed the time of the last sent event.
        MIDITimeStamp localEventTimeStampDelta;
        MIDITimeStamp nextEventTimeStamp;

        [tempoLock lock];
        localEventTimeStampDelta = eventTimeStampDelta;
        [tempoLock unlock];

        // Are we in time to send the next event?
        nextEventTimeStamp = lastEventTimeStamp + localEventTimeStampDelta;
        if (currentTimeStamp > nextEventTimeStamp) {
            // It took too long to wake up, and we've missed an event.
            unsigned int eventsToSkip;

#if DEBUG
            NSLog(@"missed event! current: %@  last clock was sent at: %@  delta: %@",
                  [SMMessage formatTimeStamp:currentTimeStamp usingOption:SMTimeFormatClockTime],
                  [SMMessage formatTimeStamp:lastEventTimeStamp usingOption:SMTimeFormatClockTime],
                  [SMMessage formatTimeStamp:localEventTimeStampDelta usingOption:SMTimeFormatHostTimeSeconds]);
#endif
            // Try to recover by figuring out what event we should now be on.
            // TODO This may get confused if the tempo changes at the same time...
            // but it's pretty darn difficult to even get this to happen in the first place.
            eventsToSkip = (currentTimeStamp - lastEventTimeStamp) / localEventTimeStampDelta;
            nextMessageIndex += eventsToSkip;
            lastEventTimeStamp += (eventsToSkip + 1) * localEventTimeStampDelta;
            sendEvent = YES;

        } else {
            // We can send another event, right on time.
            lastEventTimeStamp += localEventTimeStampDelta;
            sendEvent = YES;

        }
    }

    if (sendEvent) {
        id message;
        
        [messagesLock lock];
        message = [[[messages objectAtIndex:nextMessageIndex] copy] autorelease];
        [messagesLock unlock];

        nextMessageIndex = (nextMessageIndex + 1) % 16;

        if (message != [NSNull null]) {
            [(SMMessage *)message setTimeStamp:lastEventTimeStamp];
            [nonretainedMessageDestination takeMIDIMessages:[NSArray arrayWithObject:message]];
        }
    }

    // Schedule a wakeup at lastClockTimeStamp
    delay = AudioConvertHostTimeToNanos(lastEventTimeStamp - currentTimeStamp) / 1.0e9;
    [eventLock lock];
    [savedEvent release];
    savedEvent = [[[SMScheduler midiScheduler] scheduleSelector:@selector(_nextEvent) onObject:self afterTime:delay] retain];
    [eventLock unlock];
}

@end
