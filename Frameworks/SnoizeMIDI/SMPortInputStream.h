#import <SnoizeMIDI/SMInputStream.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMSourceEndpoint;


@interface SMPortInputStream : SMInputStream
{
    MIDIPortRef inputPort;
    NSMutableArray *endpoints;
    NSMapTable *parsersForEndpoints;
}

- (NSArray *)endpoints;
- (void)addEndpoint:(SMSourceEndpoint *)endpoint;
- (void)removeEndpoint:(SMSourceEndpoint *)endpoint;

@end

// Notifications

extern NSString *SMPortInputStreamEndpointDisappeared;
    // Sent if one of the stream's source endpoints goes away
