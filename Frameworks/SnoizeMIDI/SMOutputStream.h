//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>


@interface SMOutputStream : NSObject <SMMessageDestination>
{
    struct {
        unsigned int ignoresTimeStamps:1;
    } flags;
}

- (BOOL)ignoresTimeStamps;
- (void)setIgnoresTimeStamps:(BOOL)value;
    // If YES, then ignore the timestamps in the messages we receive, and use the current time instead

// For subclasses to override only
- (void)sendMIDIPacketList:(MIDIPacketList *)packetList;

@end
