//
//  SMSequenceRunner.h
//  SnoizeMIDI
//
//  Created by Kurt Revis on Sat Dec 15 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import <OmniFoundation/OFObject.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>
#import <SnoizeMIDI/SMPeriodicTimer.h>

@class SMSequence;

@interface SMSequenceRunner : OFObject <SMPeriodicTimerListener>
{
    id<SMMessageDestination> nonretainedMessageDestination;

    SMSequence *sequence;
    NSLock *sequenceLock;

    Float64 tempo;
    MIDITimeStamp midiClockDuration;
    NSLock *tempoLock;

    BOOL sendsMIDIClock;

    MIDITimeStamp startTimeStamp;
    BOOL isRunning;

    NSMutableArray *playingNotes;
    NSLock *playingNotesLock;
}

- (id<SMMessageDestination>)messageDestination;
- (void)setMessageDestination:(id<SMMessageDestination>)value;

- (Float64)tempo;
- (void)setTempo:(Float64)value;

- (SMSequence *)sequence;
- (void)setSequence:(SMSequence *)value;

- (BOOL)sendsMIDIClock;
- (void)setSendsMIDIClock:(BOOL)value;

- (void)start;
- (void)stop;
- (BOOL)isRunning;

@end
