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

- (void)_processNotesFromBeat:(Float64)blockStartBeat toBeat:(Float64)blockEndBeat;

- (NSArray *)_notesStartingFromBeat:(Float64)blockStartBeat toBeat:(Float64)blockEndBeat;
- (NSArray *)_notesEndingBeforeBeat:(Float64)blockEndBeat;

- (SMMessage *)_noteOnMessageForNote:(SMSequenceNote *)note;
- (SMMessage *)_noteOffMessageForNote:(SMSequenceNote *)note immediate:(BOOL)isImmediate;

- (MIDITimeStamp)_timeStampForBeat:(Float64)beat;

- (void)_stopAllPlayingNotesImmediately;

- (void)_processMIDIClockFromBeat:(Float64)blockStartBeat toBeat:(Float64)blockEndBeat;

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

    flags.sendsMIDIClock = NO;
    flags.isRunning = NO;
    currentTime = 0;
    currentBeat = 0.0;
    
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
    // Convert from beats/minute to seconds/beat to host clock units/beat.
    beatDuration = AudioConvertNanosToHostTime((60.0 / tempo) * 1.0e9);
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

    [sequenceLock lock];
    [sequence release];
    sequence = [value retain];
    [sequenceLock unlock];

    // TODO should we allow this while playing?
    // what about pending notes?
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
        message = [SMSystemRealTimeMessage systemRealTimeMessageWithTimeStamp:AudioGetCurrentHostTime() type:SMSystemRealTimeMessageTypeStart];
        [nonretainedMessageDestination takeMIDIMessages:[NSArray arrayWithObject:message]];

        // Then wait 100 ms for devices to receive the Start message and get ready.
        // They don't really start until they receive a MIDI Clock message.
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:100.0e-3]];
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

    [self _stopAllPlayingNotesImmediately];
}

- (BOOL)isRunning;
{
    return flags.isRunning;
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
    
    processingEndBeat = currentBeat + ((double)(processingEndTime - currentTime)) / beatDuration;
    [self _processNotesFromBeat:currentBeat toBeat:processingEndBeat];

    if ([self sendsMIDIClock])
        [self _processMIDIClockFromBeat:currentBeat toBeat:processingEndBeat];

    [tempoLock unlock];
    
    // Update currentBeat for the next time around
    currentBeat = processingEndBeat;
}

@end


@implementation SMSequenceRunner (Private)

- (void)_processNotesFromBeat:(Float64)blockStartBeat toBeat:(Float64)blockEndBeat;
{
    NSMutableArray *messages;
    NSArray *notes;
    unsigned int noteIndex, noteCount;

    messages = [NSMutableArray array];

    [playingNotesLock lock];

    // Handle the notes which are ending
    notes = [self _notesEndingBeforeBeat:blockEndBeat];
    noteCount = [notes count];
    for (noteIndex = 0; noteIndex < noteCount; noteIndex++) {
        SMSequenceNote *note;

        note = [notes objectAtIndex:noteIndex];
        [messages addObject:[self _noteOffMessageForNote:note immediate:NO]];
        [playingNotes removeObjectIdenticalTo:note];
    }

    // Handle the notes which are starting
    notes = [self _notesStartingFromBeat:blockStartBeat toBeat:blockEndBeat];
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

- (NSArray *)_notesStartingFromBeat:(Float64)blockStartBeat toBeat:(Float64)blockEndBeat;
{
    SMSequence *localSequence;

    [sequenceLock lock];
    localSequence = [[sequence retain] autorelease];
    [sequenceLock unlock];

    return [localSequence notesStartingFromBeat:blockStartBeat toBeat:blockEndBeat];
}

- (NSArray *)_notesEndingBeforeBeat:(Float64)blockEndBeat;
{
    NSMutableArray *notes;
    unsigned int index, count;

    count = [playingNotes count];
    if (count == 0)
        return nil;
    
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

- (MIDITimeStamp)_timeStampForBeat:(Float64)beat;
{
    OBASSERT(beat >= 0);

    return (MIDITimeStamp)((beat - currentBeat) * beatDuration) + currentTime;
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

- (void)_processMIDIClockFromBeat:(Float64)blockStartBeat toBeat:(Float64)blockEndBeat;
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
        message = [SMSystemRealTimeMessage systemRealTimeMessageWithTimeStamp:[self _timeStampForBeat:nextClockBeat] type:SMSystemRealTimeMessageTypeClock];
        [messages addObject:message];

        nextClockBeat += midiClockDurationInBeats;
    }

    if ([messages count] > 0)
        [nonretainedMessageDestination takeMIDIMessages:messages];
}

@end
