//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SMVoiceMessage.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>


@interface SMMessageFilter : NSObject <SMMessageDestination>
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
