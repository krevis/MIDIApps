/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMPortOutputStream.h"

#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMHostTime.h"
#import "SMMessage.h"
#import "SMSystemExclusiveMessage.h"
#import "SMSysExSendRequest.h"
#import "SMUtilities.h"


@interface SMPortOutputStream (Private)

- (void)endpointDisappeared:(NSNotification *)notification;
- (void)endpointWasReplaced:(NSNotification *)notification;

- (void)splitMessages:(NSArray *)messages intoCurrentSysex:(NSArray **)sysExMessagesPtr andNormal:(NSArray **)normalMessagesPtr;

- (void)sendSysExMessagesAsynchronously:(NSArray *)sysExMessages;
- (void)sysExSendRequestFinished:(NSNotification *)notification;

@end


@implementation SMPortOutputStream

NSString *SMPortOutputStreamEndpointDisappearedNotification = @"SMPortOutputStreamEndpointDisappearedNotification";
NSString *SMPortOutputStreamWillStartSysExSendNotification = @"SMPortOutputStreamWillStartSysExSendNotification";
NSString *SMPortOutputStreamFinishedSysExSendNotification = @"SMPortOutputStreamFinishedSysExSendNotification";


- (id)init;
{
    OSStatus status;

    if (!(self = [super init]))
        return nil;

    portFlags.sendsSysExAsynchronously = NO;

    sysExSendRequests = [[NSMutableArray alloc] init];
    endpoints = [[NSMutableSet alloc] init];

    status = MIDIOutputPortCreate([[SMClient sharedClient] midiClient], (CFStringRef)@"Output port",  &outputPort);
    if (status != noErr) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't create a MIDI output port (error %d)", @"SnoizeMIDI", SMBundleForObject(self), "exception with OSStatus if MIDIOutputPortCreate() fails"), (int)status];
    }

    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    MIDIPortDispose(outputPort);
    outputPort = 0;

    [endpoints release];
    endpoints = nil;

    [sysExSendRequests release];
    sysExSendRequests = nil;    
    
    [super dealloc];
}

- (NSSet *)endpoints;
{
    return endpoints;
}

- (void)setEndpoints:(NSSet *)newEndpoints;
{
    NSNotificationCenter *center;
    NSMutableSet *removedEndpoints, *addedEndpoints;
    NSEnumerator *enumerator;
    SMDestinationEndpoint *endpoint;

    if (!newEndpoints)
        newEndpoints = [NSSet set];

    if ([endpoints isEqual:newEndpoints])
        return;
        
    center = [NSNotificationCenter defaultCenter];

    removedEndpoints = [NSMutableSet setWithSet:endpoints];
    [removedEndpoints minusSet:newEndpoints];
    enumerator = [removedEndpoints objectEnumerator];
    while ((endpoint = [enumerator nextObject]))
        [center removeObserver:self name:nil object:endpoint];

    addedEndpoints = [NSMutableSet setWithSet:newEndpoints];
    [addedEndpoints minusSet:endpoints];
    enumerator = [addedEndpoints objectEnumerator];
    while ((endpoint = [enumerator nextObject])) {
        [center addObserver:self selector:@selector(endpointDisappeared:) name:SMMIDIObjectDisappearedNotification object:endpoint];
        [center addObserver:self selector:@selector(endpointWasReplaced:) name:SMMIDIObjectWasReplacedNotification object:endpoint];
    }
                                
    [endpoints release];
    endpoints = [newEndpoints mutableCopy];        
}

- (BOOL)sendsSysExAsynchronously;
{
    return portFlags.sendsSysExAsynchronously;
}

- (void)setSendsSysExAsynchronously:(BOOL)value;
{
    portFlags.sendsSysExAsynchronously = value;
}

- (void)cancelPendingSysExSendRequests;
{
    [sysExSendRequests makeObjectsPerformSelector:@selector(cancel)];
}

- (NSArray *)pendingSysExSendRequests;
{
    return [NSArray arrayWithArray:sysExSendRequests];
}

//
// SMOutputStream overrides
//

- (void)takeMIDIMessages:(NSArray *)messages;
{
    if ([self sendsSysExAsynchronously]) {
        NSArray *sysExMessages, *normalMessages;

        // Find the messages which are sysex and which have timestamps which are <= now,
        // and send them using MIDISendSysex(). Other messages get sent normally.

        [self splitMessages:messages intoCurrentSysex:&sysExMessages andNormal:&normalMessages];

        [self sendSysExMessagesAsynchronously:sysExMessages];
        [super takeMIDIMessages:normalMessages];
    } else {
        [super takeMIDIMessages:messages];
    }
}

//
// SMOutputStream subclass-implementation methods
//

- (void)sendMIDIPacketList:(MIDIPacketList *)packetList;
{
    NSEnumerator *enumerator;
    SMDestinationEndpoint *endpoint;

    enumerator = [endpoints objectEnumerator];
    while ((endpoint = [enumerator nextObject])) {
        MIDIEndpointRef endpointRef;
        OSStatus status;

        if (!(endpointRef = [endpoint endpointRef]))
            continue;
    
        status = MIDISend(outputPort, endpointRef, packetList);
        if (status) {
#if DEBUG
            NSLog(@"MIDISend(%u, %u, %p) returned error: %ld", (unsigned int)outputPort, (unsigned int)endpointRef, packetList, (long)status);
#endif
        }
    }
}

@end


@implementation SMPortOutputStream (Private)

- (void)endpointDisappeared:(NSNotification *)notification;
{
    SMDestinationEndpoint *endpoint = [notification object];
    NSMutableSet *newEndpoints;

    SMAssert([endpoints containsObject:endpoint]);

    newEndpoints = [NSMutableSet setWithSet:endpoints];
    [newEndpoints removeObject:endpoint];
    [self setEndpoints:newEndpoints];

    [[NSNotificationCenter defaultCenter] postNotificationName:SMPortOutputStreamEndpointDisappearedNotification object:self];
}

- (void)endpointWasReplaced:(NSNotification *)notification;
{
    SMDestinationEndpoint *endpoint = [notification object];
    SMDestinationEndpoint *newEndpoint;
    NSMutableSet *newEndpoints;

    SMAssert([endpoints containsObject:endpoint]);

    newEndpoint = [[notification userInfo] objectForKey:SMMIDIObjectReplacement];

    newEndpoints = [NSMutableSet setWithSet:endpoints];
    [newEndpoints removeObject:endpoint];
    [newEndpoints addObject:newEndpoint];
    [self setEndpoints:newEndpoints];    
}

- (void)splitMessages:(NSArray *)messages intoCurrentSysex:(NSArray **)sysExMessagesPtr andNormal:(NSArray **)normalMessagesPtr;
{
    NSUInteger messageIndex, messageCount;
    NSMutableArray *sysExMessages = nil;
    NSMutableArray *normalMessages = nil;
    MIDITimeStamp now;

    now = SMGetCurrentHostTime();

    messageCount = [messages count];
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMMessage *message;
        NSMutableArray **theArray;

        message = [messages objectAtIndex:messageIndex];
        if ([message isKindOfClass:[SMSystemExclusiveMessage class]] && [message timeStamp] <= now)
            theArray = &sysExMessages;
        else
            theArray = &normalMessages;

        if (*theArray == nil)
            *theArray = [NSMutableArray array];
        [*theArray addObject:message];
    }

    if (sysExMessagesPtr)
        *sysExMessagesPtr = sysExMessages;
    if (normalMessagesPtr)
        *normalMessagesPtr = normalMessages;
}

- (void)sendSysExMessagesAsynchronously:(NSArray *)messages;
{
    NSUInteger messageCount, messageIndex;

    messageCount = [messages count];
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMSystemExclusiveMessage *message;
        NSEnumerator *enumerator;
        SMDestinationEndpoint *endpoint;

        message = [messages objectAtIndex:messageIndex];

        enumerator = [endpoints objectEnumerator];
        while ((endpoint = [enumerator nextObject])) {
            SMSysExSendRequest *sendRequest;

            sendRequest = [SMSysExSendRequest sysExSendRequestWithMessage:message endpoint:endpoint];
            [sysExSendRequests addObject:sendRequest];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sysExSendRequestFinished:) name:SMSysExSendRequestFinishedNotification object:sendRequest];

            [[NSNotificationCenter defaultCenter] postNotificationName:SMPortOutputStreamWillStartSysExSendNotification object:self userInfo:[NSDictionary dictionaryWithObject:sendRequest forKey:@"sendRequest"]];

            [sendRequest send];
        }
    }
}

- (void)sysExSendRequestFinished:(NSNotification *)notification;
{
    SMSysExSendRequest *sendRequest;

    sendRequest = [notification object];
    SMAssert([sysExSendRequests containsObject:sendRequest]);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:sendRequest];
    [sendRequest retain];
    [sysExSendRequests removeObjectIdenticalTo:sendRequest];

    [[NSNotificationCenter defaultCenter] postNotificationName:SMPortOutputStreamFinishedSysExSendNotification object:self userInfo:[NSDictionary dictionaryWithObject:sendRequest forKey:@"sendRequest"]];

    [sendRequest release];
}

@end
