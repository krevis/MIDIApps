//
//  SMPortInputStream.h
//  SnoizeMIDI
//
//  Created by krevis on Wed Nov 28 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <CoreMIDI/MIDIServices.h>
#import <SnoizeMIDI/SMInputStream.h>

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
