//
//  SMPortOrVirtualInputStream.h
//  SnoizeMIDI
//
//  Created by krevis on Fri Dec 07 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <SnoizeMIDI/SMPortOrVirtualStream.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@interface SMPortOrVirtualInputStream : SMPortOrVirtualStream
{
    id<SMMessageDestination> nonretainedMessageDestination;
}

- (id<SMMessageDestination>)messageDestination;
- (void)setMessageDestination:(id<SMMessageDestination>)messageDestination;

@end

// Notifications
// This class will repost SMInputStreamReadingSysExNotification and SMInputStreamDoneReadingSysExNotification, if it receives them from its own streams.
