//
//  SMClockGenerator.h
//  SnoizeMIDI
//
//  Created by krevis on Sun Dec 09 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@class NSLock;
@class OFScheduledEvent;

@interface SMClockGenerator : OFObject
{
    id<SMMessageDestination> nonretainedMessageDestination;

    double tempo;
    MIDITimeStamp clockTimeStampDelta;
    NSLock *tempoLock;

    MIDITimeStamp lastClockTimeStamp;

    OFScheduledEvent *savedEvent;
    NSLock *eventLock;
}

- (id<SMMessageDestination>)messageDestination;
- (void)setMessageDestination:(id<SMMessageDestination>)aMessageDestination;

- (double)tempo;
- (void)setTempo:(double)value;
    // quarter notes per minute aka BPM

- (void)start;
- (void)stop;
- (BOOL)isRunning;

@end
