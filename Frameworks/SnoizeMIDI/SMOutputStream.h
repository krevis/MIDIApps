#import <OmniFoundation/OFObject.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@class SMEndpoint;


@interface SMOutputStream : OFObject <SMMessageDestination>
{
    struct {
        unsigned int ignoresTimeStamps:1;
        unsigned int sendsSysExAsynchronously:1;
    } flags;

    NSMutableArray *sysExSendRequests;
}

- (BOOL)ignoresTimeStamps;
- (void)setIgnoresTimeStamps:(BOOL)value;
    // If YES, then ignore the timestamps in the messages we receive, and use [self sendImmediatelyTimeStamp] instead

- (BOOL)sendsSysExAsynchronously;
- (void)setSendsSysExAsynchronously:(BOOL)value;
    // If YES, then use MIDISendSysex() to send sysex messages. Otherwise, use plain old MIDISend().

- (MIDITimeStamp)sendImmediatelyTimeStamp;
    // Returns 0 in the base class. Subclasses may override if necessary.

- (void)cancelPendingSysExSendRequests;

// TODO It might be nice to be able to find out about the status of pending sysex send requests, somehow.

// For subclasses to override only
- (SMEndpoint *)endpoint;
- (void)sendMIDIPacketList:(MIDIPacketList *)packetList;

@end

// Notifications
extern NSString *SMOutputStreamDoneSendingSysExNotification;
    // contains key @"bytesSent" with NSNumber (unsigned int) indicating size of data sent
    // and key @"valid" with NSNumber (BOOL) indicating whether sysex was completely sent
    // and key @"message" with SMSystemExclusiveMessage
