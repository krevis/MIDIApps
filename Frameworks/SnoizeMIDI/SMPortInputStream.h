//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

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
- (void)setEndpoints:(NSArray *)newEndpoints;

@end

// Notifications

extern NSString *SMPortInputStreamEndpointDisappeared;
    // Sent if one of the stream's source endpoints goes away
