#import <SnoizeMIDI/SMInputStream.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMSourceEndpoint;


@interface SMPortInputStream : SMInputStream
{
    MIDIPortRef inputPort;
    SMSourceEndpoint *endpoint;
}

- (SMSourceEndpoint *)endpoint;
- (void)setEndpoint:(SMSourceEndpoint *)newEndpoint;

@end

// Notifications

extern NSString *SMPortInputStreamEndpointWasRemoved;
    // Sent if the stream's source endpoint goes away
