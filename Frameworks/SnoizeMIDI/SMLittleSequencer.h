//
//  SMLittleSequencer.h
//  SnoizeMIDI
//
//  Created by Kurt Revis on Thu Dec 13 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@class NSMutableArray, NSLock;
@class OFScheduledEvent;
@class SMMessage;

@interface SMLittleSequencer : OFObject
{
    id <SMMessageDestination> nonretainedMessageDestination;

    NSMutableArray *messages;
    NSLock *messagesLock;

    double tempo;
    MIDITimeStamp eventTimeStampDelta;
    NSLock *tempoLock;
    
    OFScheduledEvent *savedEvent;
    NSLock *eventLock;

    MIDITimeStamp lastEventTimeStamp;
    unsigned int nextMessageIndex;
}

- (id<SMMessageDestination>)messageDestination;
- (void)setMessageDestination:(id<SMMessageDestination>)aMessageDestination;

- (unsigned int)messageCount;
- (SMMessage *)messageAtIndex:(unsigned int)index;
- (void)setMessage:(SMMessage *)message atIndex:(unsigned int)index;

- (double)tempo;
- (void)setTempo:(double)value;
    // quarter notes per minute aka BPM

- (void)start;
- (void)stop;
- (BOOL)isRunning;

@end
