//
//  SMPortOutputStream.h
//  SnoizeMIDI
//
//  Created by krevis on Tue Dec 04 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <SnoizeMIDI/SMOutputStream.h>
#import <CoreMIDI/MIDIServices.h>

@class SMDestinationEndpoint;


@interface SMPortOutputStream : SMOutputStream
{
    MIDIPortRef outputPort;
    SMDestinationEndpoint *endpoint;
}

- (SMDestinationEndpoint *)endpoint;
- (void)setEndpoint:(SMDestinationEndpoint *)newEndpoint;

@end

// Notifications

extern NSString *SMPortOutputStreamEndpointWasRemoved;
    // Sent if the stream's destination endpoint goes away
