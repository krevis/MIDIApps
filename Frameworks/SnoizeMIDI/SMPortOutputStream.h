#import <SnoizeMIDI/SMOutputStream.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>

@class SMDestinationEndpoint;
@class SMSysExSendRequest;


@interface SMPortOutputStream : SMOutputStream
{
    struct {
        unsigned int sendsSysExAsynchronously:1;
    } portFlags;

    MIDIPortRef outputPort;
    SMDestinationEndpoint *endpoint;
    NSMutableArray *sysExSendRequests;
}

- (SMDestinationEndpoint *)endpoint;
- (void)setEndpoint:(SMDestinationEndpoint *)newEndpoint;

- (BOOL)sendsSysExAsynchronously;
- (void)setSendsSysExAsynchronously:(BOOL)value;
    // If YES, then use MIDISendSysex() to send sysex messages with timestamps now or in the past.
    // (We can't use MIDISendSysex() to schedule delivery in the future.)
    // Otherwise, use plain old MIDI packets.

- (void)cancelPendingSysExSendRequests;
- (SMSysExSendRequest *)currentSysExSendRequest;

@end

// Notifications

extern NSString *SMPortOutputStreamEndpointWasRemovedNotification;
    // Sent if the stream's destination endpoint goes away

extern NSString *SMPortOutputStreamWillStartSysExSendNotification;
    // user info has key @"sendRequest", object SMSysExSendRequest
extern NSString *SMPortOutputStreamFinishedSysExSendNotification;
    // user info has key @"sendRequest", object SMSysExSendRequest
