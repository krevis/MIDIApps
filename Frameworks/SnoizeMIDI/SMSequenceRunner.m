//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMSequenceRunner.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMHostTime.h"
#import "SMPeriodicTimer.h"
#import "SMPlayingNote.h"
#import "SMSequence.h"
#import "SMSequenceNote.h"
#import "SMSystemRealTimeMessage.h"
#import "SMVoiceMessage.h"


@interface SMSequenceRunner (Private)

- (void)processNotesAndMIDIClockFromBeat:(Float64)blockStartBeat toBeat:(Float64)blockEndBeat andTime:(UInt64)blockEndTime;
- (void)processNotesFromBeat:(Float64)blockStartBeat toBeat:(Float64)blockEndBeat andTime:(UInt64)blockEndTime;

- (NSArray *)noteOffMessagesForNotesEndingBeforeTime:(UInt64)endTime;
- (NSArray *)takePlayingNotesEndingBeforeTime:(UInt64)endTime;

- (SMMessage *)noteOnMessageForNote:(SMSequenceNote *)note atTime:(MIDITimeStamp)timeStamp;
- (SMMessage *)noteOffMessageForPlayingNote:(SMPlayingNote *)playingNote immediate:(BOOL)isImmediate;

- (void)stopAllPlayingNotesImmediately;

- (void)processMIDIClockFromBeat:(Float64)blockStartBeat toBeat:(Float64)blockEndBeat;

@end


@implementation SMSequenceRunner

- (id)init;
{
    if (![super init])
        return nil;

    tempoLock = [[NSLock alloc] init];

    playingNotes = [[NSMutableArray alloc] init];
    playingNotesLock = [[NSLock alloc] init];

    flags.sendsMIDIClock = NO;
    flags.isRunning = NO;
    flags.doesLoop = NO;
    currentTime = 0;
    currentBeat = 0.0;
    
    [self setTempo:120.0];

    loopStartBeat = 0.0;
    loopEndBeat = 0.0;
    
    return self;
}

- (void)dealloc;
{
    nonretainedMessageDestination = nil;

    [sequence release];
    sequence = nil;
    [tempoLock release];
    tempoLock = nil;
    [playingNotes release];
    playingNotes = nil;
    [playingNotesLock release];
    playingNotesLock = nil;
    
    [super dealloc];
}

- (id<SMMessageDestination>)messageDestination;
{
    return nonretainedMessageDestination;
}

- (void)setMessageDestination:(id<SMMessageDestination>)value;
{
    nonretainedMessageDestination = value;
}

- (Float64)tempo;
{
    return tempo;
}

- (void)setTempo:(Float64)value;
{
    [tempoLock lock];    
    tempo = value;
    // Convert from beats/minute to seconds/beat to host clock units/beat.
    beatDuration = SMConvertNanosToHostTime((60.0 / tempo) * 1.0e9);
    [tempoLock unlock];
}

- (SMSequence *)sequence;
{
    return sequence;
}

- (void)setSequence:(SMSequence *)value;
{
    if (sequence == value)
        return;

    [sequence release];
    sequence = [value retain];

    // TODO should we allow this while playing?  Need to lock around it, in that case...
}

- (BOOL)sendsMIDIClock;
{
    return flags.sendsMIDIClock;
}

- (void)setSendsMIDIClock:(BOOL)value;
{
    flags.sendsMIDIClock = value;
}

- (void)start;
{
    OBASSERT([NSThread inMainThread]);
    // TODO Look into allowing this from other threads

    if ([self isRunning]) {
#if DEBUG
        NSLog(@"-[%@ start] called while already running; ignoring", NSStringFromClass([self class]));
#endif
        return;
    }

    currentBeat = 0.0;
    currentTime = 0;

    flags.isRunning = YES;

    if ([self sendsMIDIClock]) {
        SMMessage *message;
        
        // Send a MIDI Start message first (immediately).
        message = [SMSystemRealTimeMessage systemRealTimeMessageWithTimeStamp:SMGetCurrentHostTime() type:SMSystemRealTimeMessageTypeStart];
        [nonretainedMessageDestination takeMIDIMessages:[NSArray arrayWithObject:message]];

        // Then wait 100 ms for devices to receive the Start message and get ready.
        // They don't really start until they receive a MIDI Clock message.
        usleep(100 * 1000);
    }

    [[SMPeriodicTimer sharedPeriodicTimer] addListener:self];
}

- (void)stop;
{
    OBASSERT([NSThread inMainThread]);
    // TODO Look into allowing this from other threads

    if (![self isRunning]) {
#if DEBUG
        NSLog(@"-[%@ stop] called while not running; ignoring", NSStringFromClass([self class]));
#endif
        return;
    }

    flags.isRunning = NO;
    [[SMPeriodicTimer sharedPeriodicTimer] removeListener:self];

    [self stopAllPlayingNotesImmediately];
}

- (BOOL)isRunning;
{
    return flags.isRunning;
}

- (Float64)currentBeat;
{
    return currentBeat;
}

- (BOOL)doesLoop;
{
    return flags.doesLoop;
}

- (void)setDoesLoop:(BOOL)value;
{
    flags.doesLoop = value && (loopStartBeat < loopEndBeat);
}

- (Float64)loopStartBeat;
{
    return loopStartBeat;
}

- (void)setLoopStartBeat:(Float64)value;
{
    [tempoLock lock];    
    loopStartBeat = value;
    [tempoLock unlock];
}

- (Float64)loopEndBeat;
{
    return loopEndBeat;
}

- (void)setLoopEndBeat:(Float64)value;
{
    [tempoLock lock];    
    loopEndBeat = value;
    [tempoLock unlock];
}

- (Float64)loopBeatDuration;
{
    // Derived property
    Float64 duration;

    // Need to lock because we're reading two properties at one time (don't want to slice between them)
    [tempoLock lock];
    duration = loopEndBeat - loopStartBeat;
    [tempoLock unlock];

    return duration;
}

- (void)setLoopBeatDuration:(Float64)value;
{
    // Derived property. This leaves the start point the same, changing the end point.
    [self setLoopEndBeat:loopStartBeat + value];
}

//
// SMPeriodicTimerListener protocol
//

- (void)periodicTimerFiredForStart:(UInt64)processingStartTime end:(UInt64)processingEndTime;
{
    Float64 processingEndBeat;

    OBASSERT(processingEndTime > processingStartTime);

    currentTime = processingStartTime;

    [tempoLock lock];

    processingEndBeat = currentBeat + (Float64)(processingEndTime - currentTime) / beatDuration;
    if (flags.doesLoop) {
        // We should be processing less than one loop worth of time in each pass.
        // (If this changes, we will need to complicate things.)
        OBASSERT(processingEndBeat - currentBeat < loopEndBeat - loopStartBeat);
    }
    [self processNotesAndMIDIClockFromBeat:currentBeat toBeat:processingEndBeat andTime:processingEndTime];

    [tempoLock unlock];

    // Update currentBeat for the next time around
    if (flags.doesLoop && processingEndBeat > loopEndBeat)
        currentBeat = loopStartBeat + (processingEndBeat - loopEndBeat);
    else
        currentBeat = processingEndBeat;
}

@end


@implementation SMSequenceRunner (Private)

- (void)processNotesAndMIDIClockFromBeat:(Float64)blockStartBeat toBeat:(Float64)blockEndBeat andTime:(UInt64)blockEndTime;
{
    [self processNotesFromBeat:blockStartBeat toBeat:blockEndBeat andTime:blockEndTime];
    if ([self sendsMIDIClock])
        [self processMIDIClockFromBeat:blockStartBeat toBeat:blockEndBeat];
}

- (void)processNotesFromBeat:(Float64)blockStartBeat toBeat:(Float64)blockEndBeat andTime:(UInt64)blockEndTime;
{
    NSMutableArray *messages;
    NSArray *notes;
    unsigned int noteIndex, noteCount;

    messages = [NSMutableArray array];

    [playingNotesLock lock];

    // Handle the notes which are ending
    [messages addObjectsFromArray:[self noteOffMessagesForNotesEndingBeforeTime:blockEndTime]];

    // Handle the notes which are starting
    if (flags.doesLoop && blockEndBeat > loopEndBeat) {
        // We're crossing the loop end point, so get the notes in two separate segments.
        NSArray *notes1, *notes2;

        notes1 = [sequence notesStartingFromBeat:blockStartBeat toBeat:loopEndBeat];
        notes2 = [sequence notesStartingFromBeat:loopStartBeat toBeat:(loopStartBeat + blockEndBeat - loopEndBeat)];
        notes = [notes1 arrayByAddingObjectsFromArray:notes2];
    } else {
        notes = [sequence notesStartingFromBeat:blockStartBeat toBeat:blockEndBeat];
    }
        
    noteCount = [notes count];
    for (noteIndex = 0; noteIndex < noteCount; noteIndex++) {
        SMSequenceNote *note;
        Float64 notePosition;
        UInt64 noteStartTime;
        UInt64 noteEndTime;
        SMPlayingNote *playingNote;

        note = [notes objectAtIndex:noteIndex];

        notePosition = [sequence positionForNote:note];

        if (flags.doesLoop && notePosition < currentBeat)
            notePosition += loopEndBeat - loopStartBeat;
        noteStartTime = currentTime + (MIDITimeStamp)((notePosition - currentBeat) * beatDuration);

        noteEndTime = noteStartTime + [note duration] * beatDuration;
        
        [messages addObject:[self noteOnMessageForNote:note atTime:noteStartTime]];

        playingNote = [[SMPlayingNote alloc] initWithNote:note endTime:noteEndTime];
        [playingNotes addObject:playingNote];
        [playingNote release];
    }

    [playingNotesLock unlock];

    if ([messages count])
        [nonretainedMessageDestination takeMIDIMessages:messages];
}

- (NSArray *)noteOffMessagesForNotesEndingBeforeTime:(UInt64)endTime
{
    NSArray *notes;
    unsigned int noteIndex, noteCount;
    NSMutableArray *messages;

    notes = [self takePlayingNotesEndingBeforeTime:endTime];
    noteCount = [notes count];

    messages = [NSMutableArray arrayWithCapacity:noteCount];
    
    for (noteIndex = 0; noteIndex < noteCount; noteIndex++) {
        SMPlayingNote *note;

        note = [notes objectAtIndex:noteIndex];
        [messages addObject:[self noteOffMessageForPlayingNote:note immediate:NO]];
    }

    return messages;
}

- (NSArray *)takePlayingNotesEndingBeforeTime:(UInt64)endTime;
{
    NSMutableArray *notes;
    unsigned int index, count;

    count = [playingNotes count];
    if (count == 0)
        return nil;
    
    notes = [NSMutableArray arrayWithCapacity:count];
    index = count;
    while (index--) {
        SMPlayingNote *note;

        note = [playingNotes objectAtIndex:index];
        if ([note endTime] < endTime) {
            [notes addObject:note];
            [playingNotes removeObjectAtIndex:index];
        }
    }

    return notes;

    // TODO this is not really correct. What if someone moves the note afterwards in time after it has been started, but before it ends,
    // so that its end position won't get reached for another minute?
    // We should always use the note's end position as it was when it started playing, EXCEPT if the duration changes.
    // (Changes in the note's position should not have any effect on the playing note.)
    //
    // So: when we start the note, keep that time (and compute the projected end time for it).
    // If the duration of the note changes while it is playing (but its position does not change), then update the end time accordingly.
    // If the note is moved: don't change the end time.
}

- (SMMessage *)noteOnMessageForNote:(SMSequenceNote *)note atTime:(MIDITimeStamp)timeStamp;
{
    SMVoiceMessage *message;

    message = [[[SMVoiceMessage alloc] initWithTimeStamp:timeStamp statusByte:0] autorelease];
    [message setStatus:SMVoiceMessageStatusNoteOn];
    [message setChannel:1];	// TODO
    [message setDataByte1:[note noteNumber]];
    [message setDataByte2:[note onVelocity]];

    return message;
}

- (SMMessage *)noteOffMessageForPlayingNote:(SMPlayingNote *)playingNote immediate:(BOOL)isImmediate;
{
    MIDITimeStamp timeStamp;
    SMVoiceMessage *message;
    SMSequenceNote *sequenceNote;

    if (isImmediate)
        timeStamp = currentTime;
    else
        timeStamp = [playingNote endTime];

    sequenceNote = [playingNote note];

    message = [[[SMVoiceMessage alloc] initWithTimeStamp:timeStamp statusByte:0] autorelease];
    [message setStatus:SMVoiceMessageStatusNoteOff];
    [message setChannel:1];	// TODO
    [message setDataByte1:[sequenceNote noteNumber]];
    [message setDataByte2:[sequenceNote offVelocity]];

    return message;
}

- (void)stopAllPlayingNotesImmediately;
{
    unsigned int noteIndex, noteCount;
    NSMutableArray *messages;

    [playingNotesLock lock];
    
    noteCount = [playingNotes count];
    if (noteCount == 0) {
        [playingNotesLock unlock];
        return;
    }

    messages = [NSMutableArray arrayWithCapacity:noteCount];
    for (noteIndex = 0; noteIndex < noteCount; noteIndex++) {
        SMPlayingNote *note;

        note = [playingNotes objectAtIndex:noteIndex];
        [messages addObject:[self noteOffMessageForPlayingNote:note immediate:YES]];
    }
    [playingNotes removeAllObjects];

    [playingNotesLock unlock];

    [nonretainedMessageDestination takeMIDIMessages:messages];
}

- (void)processMIDIClockFromBeat:(Float64)blockStartBeat toBeat:(Float64)blockEndBeat;
{
    NSMutableArray *messages;
    SMMessage *message;
    Float64 nextClockBeat;
    Float64 clockPhase;
    const Float64 midiClockDurationInBeats = 1/(Float64)24.0;

    messages = [NSMutableArray array];

    clockPhase = fmod(blockStartBeat, midiClockDurationInBeats);
    if (clockPhase == 0.0)
        nextClockBeat = blockStartBeat;
    else
        nextClockBeat = blockStartBeat - clockPhase + midiClockDurationInBeats;

    while (nextClockBeat < blockEndBeat) {
        MIDITimeStamp timeStamp;

        timeStamp = currentTime + (MIDITimeStamp)((nextClockBeat - currentBeat) * beatDuration);        
        message = [SMSystemRealTimeMessage systemRealTimeMessageWithTimeStamp:timeStamp type:SMSystemRealTimeMessageTypeClock];
        [messages addObject:message];

        nextClockBeat += midiClockDurationInBeats;
    }

    if ([messages count] > 0)
        [nonretainedMessageDestination takeMIDIMessages:messages];
}

@end
