//
//  SMSequenceRunner.m
//  SnoizeMIDI
//
//  Created by Kurt Revis on Sat Dec 15 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMSequenceRunner.h"
#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreMIDI/CoreMIDI.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import "SMPeriodicTimer.h"
#import "SMSequence.h"
#import "SMSequenceNote.h"
#import "SMSystemRealTimeMessage.h"
#import "SMVoiceMessage.h"


@interface SMSequenceRunner (Private)

- (void)_processNotesFromTime:(MIDITimeStamp)blockStartTime toTime:(MIDITimeStamp)blockEndTime;

- (NSArray *)_notesStartingFromTime:(MIDITimeStamp)blockStartTime toTime:(MIDITimeStamp)blockEndTime;
- (NSArray *)_notesEndingBeforeTime:(MIDITimeStamp)blockEndTime;

- (SMMessage *)_noteOnMessageForNote:(SMSequenceNote *)note;
- (SMMessage *)_noteOffMessageForNote:(SMSequenceNote *)note immediate:(BOOL)isImmediate;

- (Float64)_beatForTimeStamp:(MIDITimeStamp)timeStamp;
- (MIDITimeStamp)_timeStampForBeat:(Float64)beat;

- (void)_stopAllPlayingNotesImmediately;

- (void)_processMIDIClockFromTime:(MIDITimeStamp)blockStartTime toTime:(MIDITimeStamp)blockEndTime;

@end


@implementation SMSequenceRunner

- (id)init;
{
    if (![super init])
        return nil;

    sequenceLock = [[NSLock alloc] init];
    tempoLock = [[NSLock alloc] init];

    playingNotes = [[NSMutableArray alloc] init];
    playingNotesLock = [[NSLock alloc] init];

    sendsMIDIClock = NO;
    isRunning = NO;
    
    [self setTempo:120.0];
    
    return self;
}

- (void)dealloc;
{
    nonretainedMessageDestination = nil;

    [sequence release];
    sequence = nil;
    [sequenceLock release];
    sequenceLock = nil;
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
    // Convert from beats/minute to seconds/clock. We need 24 clocks for each beat.
    midiClockDuration = AudioConvertNanosToHostTime(((60.0 / tempo) / 24.0) * 1.0e9);
    [tempoLock unlock];

    // TODO We don't handle tempo change correctly while running... see _beatForTimeStamp comment
    // TODO Also check that we lock tempoLock in all appropriate places
}

- (SMSequence *)sequence;
{
    return sequence;
}

- (void)setSequence:(SMSequence *)value;
{
    if (sequence == value)
        return;

    [sequenceLock lock];
    [sequence release];
    sequence = [value retain];
    [sequenceLock unlock];

    // TODO should we allow this while playing?
    // what about pending notes?
}

- (BOOL)sendsMIDIClock;
{
    return sendsMIDIClock;
}

- (void)setSendsMIDIClock:(BOOL)value;
{
    sendsMIDIClock = value;
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

    startTimeStamp = 0;

    isRunning = YES;
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

    isRunning = NO;
    [[SMPeriodicTimer sharedPeriodicTimer] removeListener:self];

    [self _stopAllPlayingNotesImmediately];
}

- (BOOL)isRunning;
{
    return isRunning;
}

//
// SMPeriodicTimerListener protocol
//

- (void)periodicTimerFiredForStart:(UInt64)processingStartTime end:(UInt64)processingEndTime;
{
    if (startTimeStamp == 0)
        startTimeStamp = processingStartTime;

    [self _processNotesFromTime:processingStartTime toTime:processingEndTime];

    if ([self sendsMIDIClock])
        [self _processMIDIClockFromTime:processingStartTime toTime:processingEndTime];
}

@end


@implementation SMSequenceRunner (Private)

- (void)_processNotesFromTime:(MIDITimeStamp)blockStartTime toTime:(MIDITimeStamp)blockEndTime;
{
    NSMutableArray *messages;
    NSArray *notes;
    unsigned int noteIndex, noteCount;

    messages = [NSMutableArray array];

    [playingNotesLock lock];

    // Handle the notes which are ending
    notes = [self _notesEndingBeforeTime:blockEndTime];
    noteCount = [notes count];
    for (noteIndex = 0; noteIndex < noteCount; noteIndex++) {
        SMSequenceNote *note;

        note = [notes objectAtIndex:noteIndex];
        [messages addObject:[self _noteOffMessageForNote:note immediate:NO]];
        [playingNotes removeObjectIdenticalTo:note];
    }

    // Handle the notes which are starting
    notes = [self _notesStartingFromTime:blockStartTime toTime:blockEndTime];
    noteCount = [notes count];
    for (noteIndex = 0; noteIndex < noteCount; noteIndex++) {
        SMSequenceNote *note;

        note = [notes objectAtIndex:noteIndex];
        [messages addObject:[self _noteOnMessageForNote:note]];
        [playingNotes addObject:note];
    }

    [playingNotesLock unlock];

    if ([messages count])
        [nonretainedMessageDestination takeMIDIMessages:messages];
}

- (NSArray *)_notesStartingFromTime:(MIDITimeStamp)blockStartTime toTime:(MIDITimeStamp)blockEndTime;
{
    SMSequence *localSequence;
    Float64 blockStartBeat, blockEndBeat;

    [sequenceLock lock];
    localSequence = [[sequence retain] autorelease];
    [sequenceLock unlock];

    // TODO These should be passed in because they will be needed elsewhere
    blockStartBeat = [self _beatForTimeStamp:blockStartTime];
    blockEndBeat = [self _beatForTimeStamp:blockEndTime];
//    NSLog(@"notes starting between %g and %g", blockStartBeat, blockEndBeat);

    return [localSequence notesStartingFromBeat:blockStartBeat toBeat:blockEndBeat];
}

- (NSArray *)_notesEndingBeforeTime:(MIDITimeStamp)blockEndTime;
{
    NSMutableArray *notes;
    unsigned int index, count;
    Float64 blockEndBeat;

    count = [playingNotes count];
    if (count == 0)
        return nil;

    // TODO This should be passed in because it will be needed elsewhere
    blockEndBeat = [self _beatForTimeStamp:blockEndTime];
//    NSLog(@"notes ending before: %g", blockEndBeat);
    
    notes = [NSMutableArray arrayWithCapacity:count];
    for (index = 0; index < count; index++) {
        SMSequenceNote *note;

        note = [playingNotes objectAtIndex:index];
        if ([note endPosition] < blockEndBeat)
            [notes addObject:note];
    }

    return notes;
}

- (SMMessage *)_noteOnMessageForNote:(SMSequenceNote *)note;
{
    MIDITimeStamp timeStamp;
    SMVoiceMessage *message;

    timeStamp = [self _timeStampForBeat:[note position]];
    message = [[[SMVoiceMessage alloc] initWithTimeStamp:timeStamp statusByte:0] autorelease];
    [message setStatus:SMVoiceMessageStatusNoteOn];
    [message setChannel:1];	// TODO
    [message setDataByte1:[note noteNumber]];
    [message setDataByte2:[note onVelocity]];

    return message;
}

- (SMMessage *)_noteOffMessageForNote:(SMSequenceNote *)note immediate:(BOOL)isImmediate;
{
    MIDITimeStamp timeStamp;
    SMVoiceMessage *message;

    if (isImmediate)
        timeStamp = AudioGetCurrentHostTime();
    else
        timeStamp = [self _timeStampForBeat:[note endPosition]];

    message = [[[SMVoiceMessage alloc] initWithTimeStamp:timeStamp statusByte:0] autorelease];
    [message setStatus:SMVoiceMessageStatusNoteOff];
    [message setChannel:1];	// TODO
    [message setDataByte1:[note noteNumber]];
    [message setDataByte2:[note offVelocity]];

    return message;
}

- (Float64)_beatForTimeStamp:(MIDITimeStamp)timeStamp;
{
    Float64 seconds;

    OBASSERT(timeStamp >= startTimeStamp);

    seconds = AudioConvertHostTimeToNanos(timeStamp - startTimeStamp) / 1.0e9;
    return (seconds * (tempo / 60.0));

    // TODO This won't work if the tempo has ever changed... need to reset startTimeStamp when that happens, or something.
    // Alternatively we could keep a current beat pointer and then do operations on that... easier to keep up to date
}

- (MIDITimeStamp)_timeStampForBeat:(Float64)beat;
{
    Float64 seconds;

    OBASSERT(beat >= 0);

    seconds = beat * (60.0 / tempo);
    return startTimeStamp + AudioConvertNanosToHostTime(seconds * 1.0e9);    

    // TODO This won't work if the tempo has ever changed... need to reset startTimeStamp when that happens, or something.
    // Alternatively we could keep a current beat pointer and then do operations on that... easier to keep up to date
}

- (void)_stopAllPlayingNotesImmediately;
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
        SMSequenceNote *note;

        note = [playingNotes objectAtIndex:noteIndex];
        [messages addObject:[self _noteOffMessageForNote:note immediate:YES]];
    }
    [playingNotes removeAllObjects];

    [playingNotesLock unlock];

    [nonretainedMessageDestination takeMIDIMessages:messages];
}

- (void)_processMIDIClockFromTime:(MIDITimeStamp)blockStartTime toTime:(MIDITimeStamp)blockEndTime;
{
    NSMutableArray *messages;
    SMMessage *message;
    MIDITimeStamp nextClockTime;

    messages = [NSMutableArray array];

    if (blockStartTime == startTimeStamp) {
        // Send a MIDI Start message first (immediately).
        message = [SMSystemRealTimeMessage systemRealTimeMessageWithTimeStamp:AudioGetCurrentHostTime() type:SMSystemRealTimeMessageTypeStart];
        [messages addObject:message];
    }

    // Then emit as many MIDI clock messages as necessary.
    nextClockTime = blockStartTime - ((blockStartTime - startTimeStamp) % midiClockDuration) + midiClockDuration;
    while (nextClockTime < blockEndTime) {
        message = [SMSystemRealTimeMessage systemRealTimeMessageWithTimeStamp:nextClockTime type:SMSystemRealTimeMessageTypeClock];
        [messages addObject:message];

        nextClockTime += midiClockDuration;
    }

    if ([messages count] > 0)
        [nonretainedMessageDestination takeMIDIMessages:messages];
}

@end
