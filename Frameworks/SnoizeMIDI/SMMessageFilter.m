/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMMessageFilter.h"


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

    return self;
}

- (void)dealloc;
{
    nonretainedMessageDestination = nil;

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
    filterMask = newFilterMask;
}

- (SMChannelMask)channelMask;
{
    return channelMask;
}

- (void)setChannelMask:(SMChannelMask)newChannelMask;
{
    channelMask = newChannelMask;
}

//
// SMMessageDestination protocol
//

- (void)takeMIDIMessages:(NSArray *)messages
{
    NSArray *filteredMessages = [self filterMessages:messages];
    if ([filteredMessages count])
        [nonretainedMessageDestination takeMIDIMessages:filteredMessages];
}

@end


@implementation SMMessageFilter (Private)

- (NSArray *)filterMessages:(NSArray *)messages;
{
    NSUInteger messageIndex, messageCount;
    NSMutableArray *filteredMessages;

    messageCount = [messages count];
    filteredMessages = [NSMutableArray arrayWithCapacity:messageCount];
    
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMMessage *message;

        message = [messages objectAtIndex:messageIndex];
        if ([message matchesMessageTypeMask:filterMask]) {
            // NOTE: This type checking kind of smells, but I can't think of a better way to do it.
            // We could implement -matchesChannelMask on all SMMessages, but I don't know if the default should be YES or NO...
            // I could see it going either way, in different contexts.
            if ([message isKindOfClass:[SMVoiceMessage class]] && ![(SMVoiceMessage *)message matchesChannelMask:channelMask]) {
                // drop this message
            } else {
                [filteredMessages addObject:message];
            }
        }
    }

    return filteredMessages;
}

@end
