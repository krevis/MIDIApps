//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMMessageFilter.h"

#import <OmniBase/OmniBase.h>


@interface SMMessageFilter (Private)

- (NSArray *)filterMessages:(NSArray *)messages;

@end


@implementation SMMessageFilter

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    filterMask = SMMessageTypeNothingMask;
    channelMask = SMChannelMaskAll;

    settingsLock = [[NSLock alloc] init];

    return self;
}

- (void)dealloc;
{
    nonretainedMessageDestination = nil;
    [settingsLock release];
    settingsLock = nil;

    [super dealloc];
}

- (id<SMMessageDestination>)messageDestination;
{
    return nonretainedMessageDestination;
}

- (void)setMessageDestination:(id<SMMessageDestination>)aMessageDestination;
{
    nonretainedMessageDestination = aMessageDestination;
}

- (SMMessageType)filterMask;
{
    return filterMask;
}

- (void)setFilterMask:(SMMessageType)newFilterMask;
{
    [settingsLock lock];
    filterMask = newFilterMask;
    [settingsLock unlock];
}

- (SMChannelMask)channelMask;
{
    return channelMask;
}

- (void)setChannelMask:(SMChannelMask)newChannelMask;
{
    [settingsLock lock];
    channelMask = newChannelMask;
    [settingsLock unlock];
}

//
// SMMessageDestination protocol
//

- (void)takeMIDIMessages:(NSArray *)messages
{
    NSArray *filteredMessages;
    
    filteredMessages = [self filterMessages:messages];
    if ([filteredMessages count])
        [nonretainedMessageDestination takeMIDIMessages:filteredMessages];
}

@end


@implementation SMMessageFilter (Private)

- (NSArray *)filterMessages:(NSArray *)messages;
{
    unsigned int messageIndex, messageCount;
    NSMutableArray *filteredMessages;
    SMMessageType localFilterMask;
    SMChannelMask localChannelMask;

    messageCount = [messages count];
    filteredMessages = [NSMutableArray arrayWithCapacity:messageCount];

    // Copy the filter settings so we act consistent, if someone else changes them while we're working
    [settingsLock lock];
    localFilterMask = filterMask;
    localChannelMask = channelMask;
    [settingsLock unlock];
    
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMMessage *message;

        message = [messages objectAtIndex:messageIndex];
        if ([message matchesMessageTypeMask:localFilterMask]) {
            // NOTE: This type checking kind of smells, but I can't think of a better way to do it.
            // We could implement -matchesChannelMask on all SMMessages, but I don't know if the default should be YES or NO...
            // I could see it going either way, in different contexts.
            if ([message isKindOfClass:[SMVoiceMessage class]] && ![(SMVoiceMessage *)message matchesChannelMask:localChannelMask]) {
                // drop this message
            } else {
                [filteredMessages addObject:message];
            }
        }
    }

    return filteredMessages;
}

@end
