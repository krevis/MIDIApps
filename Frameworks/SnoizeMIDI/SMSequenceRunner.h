//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>
#import <SnoizeMIDI/SMPeriodicTimer.h>

@class SMSequence;


@interface SMSequenceRunner : OFObject <SMPeriodicTimerListener>
{
    id<SMMessageDestination> nonretainedMessageDestination;

    SMSequence *sequence;

    Float64 tempo;
    MIDITimeStamp beatDuration;
    NSLock *tempoLock;	// TODO rename -- we use this for locking loop points, too

    struct {
        unsigned int sendsMIDIClock:1;
        unsigned int isRunning:1;
        unsigned int doesLoop:1;
    } flags;

    Float64 currentBeat;
    MIDITimeStamp currentTime;
    
    NSMutableArray *playingNotes;
    NSLock *playingNotesLock;

    Float64 loopStartBeat;
    Float64 loopEndBeat;
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
- (Float64)currentBeat;

- (BOOL)doesLoop;
- (void)setDoesLoop:(BOOL)value;
- (Float64)loopStartBeat;
- (void)setLoopStartBeat:(Float64)value;
- (Float64)loopEndBeat;
- (void)setLoopEndBeat:(Float64)value;
- (Float64)loopBeatDuration;
- (void)setLoopBeatDuration:(Float64)value;

@end
