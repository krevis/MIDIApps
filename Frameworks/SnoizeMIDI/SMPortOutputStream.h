#import <SnoizeMIDI/SMOutputStream.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>

@class SMDestinationEndpoint;


@interface SMPortOutputStream : SMOutputStream
{
    MIDIPortRef outputPort;
    SMDestinationEndpoint *endpoint;
}

- (void)setEndpoint:(SMDestinationEndpoint *)newEndpoint;

@end

// Notifications

extern NSString *SMPortOutputStreamEndpointWasRemoved;
    // Sent if the stream's destination endpoint goes away
