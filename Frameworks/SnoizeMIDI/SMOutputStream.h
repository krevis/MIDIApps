#import <OmniFoundation/OFObject.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>


@interface SMOutputStream : OFObject <SMMessageDestination>
{
    struct {
        unsigned int ignoresTimeStamps:1;
    } flags;
}

- (BOOL)ignoresTimeStamps;
- (void)setIgnoresTimeStamps:(BOOL)value;
    // If YES, then ignore the timestamps in the messages we receive, and use [self sendImmediatelyTimeStamp] instead

- (MIDITimeStamp)sendImmediatelyTimeStamp;
    // Returns 0 in the base class. Subclasses may override if necessary.

// For subclasses to override only
- (void)sendMIDIPacketList:(MIDIPacketList *)packetList;

@end
