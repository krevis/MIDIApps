//
//  SMMessageFilter.h
//  SnoizeMIDI.framework
//
//  Created by krevis on Sat Sep 08 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <SnoizeMIDI/SMVoiceMessage.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@class NSLock;

@interface SMMessageFilter : OFObject <SMMessageDestination>
{
    SMMessageType filterMask;
    SMChannelMask channelMask;
    id<SMMessageDestination> nonretainedMessageDestination;
    NSLock *settingsLock;
}

- (id<SMMessageDestination>)messageDestination;
- (void)setMessageDestination:(id<SMMessageDestination>)aMessageDestination;

- (SMMessageType)filterMask;
- (void)setFilterMask:(SMMessageType)newFilterMask;

- (SMChannelMask)channelMask;
- (void)setChannelMask:(SMChannelMask)newChannelMask;

@end
