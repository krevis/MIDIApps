/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SSECombinationOutputStream.h"

#import "SMDestinationEndpoint-SSEOutputStreamDestination.h"


@interface SSECombinationOutputStream (Private)

- (void)selectEndpoint:(SMDestinationEndpoint *)endpoint;

- (void)createPortStream;
- (void)removePortStream;
- (void)createVirtualStream;
- (void)removeVirtualStream;

- (void)repostNotification:(NSNotification *)notification;
- (void)portStreamEndpointDisappeared:(NSNotification *)notification;
- (void)portStreamEndpointListChanged:(NSNotification *)notification;

@end


@implementation SSECombinationOutputStream

NSString *SSECombinationOutputStreamSelectedDestinationDisappearedNotification = @"SSECombinationOutputStreamSelectedDestinationDisappearedNotification";
NSString *SSECombinationOutputStreamDestinationListChangedNotification = @"SSECombinationOutputStreamDestinationListChangedNotification";

+ (NSArray *)destinationEndpoints
{
    // The regular set of destination endpoints, but don't show any of our own virtual endpoints in the list

	NSMutableArray *destinations = [NSMutableArray arrayWithArray:[SMDestinationEndpoint destinationEndpoints]];

    unsigned destinationsIndex = [destinations count];
    while (destinationsIndex--) {
        if ([[destinations objectAtIndex:destinationsIndex] isOwnedByThisProcess])
            [destinations removeObjectAtIndex:destinationsIndex];
    }
	return destinations;
}

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    virtualEndpointName = [[[SMClient sharedClient] name] copy];
    virtualStreamDestination = [[SSESimpleOutputStreamDestination alloc] initWithName:virtualEndpointName];
    virtualEndpointUniqueID = 0;	// Let CoreMIDI assign the virtual endpoint a uniqueID

    flags.ignoresTimeStamps = NO;
    flags.sendsSysExAsynchronously = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(portStreamEndpointListChanged:) 
                                                 name:SMMIDIObjectListChangedNotification
                                               object:[SMDestinationEndpoint class]];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [portStream release];
    portStream = nil;
    [virtualStream release];
    virtualStream = nil;
    [virtualEndpointName release];
    virtualEndpointName = nil;
    [virtualStreamDestination release];
    virtualStreamDestination = nil;

    [super dealloc];
}

- (NSArray *)destinations;
{
    // Collapse the groups into a flat list
    NSArray *groups;
    unsigned int groupIndex, groupCount;
    NSArray *results = nil;

    groups = [self groupedDestinations];
    groupCount = [groups count];
    for (groupIndex = 0; groupIndex < groupCount; groupIndex++) {
        NSArray *groupDestinations = [groups objectAtIndex:groupIndex];
        if (!results)
            results = groupDestinations;
        else
            results = [results arrayByAddingObjectsFromArray:groupDestinations];        
    }

    return results;    
}

- (NSArray *)groupedDestinations;
{
    return [NSArray arrayWithObjects:
        [SSECombinationOutputStream destinationEndpoints],
        [NSArray arrayWithObject:virtualStreamDestination],
        nil];
}

- (id <SSEOutputStreamDestination>)selectedDestination;
{
    if (virtualStream)
        return virtualStreamDestination;
    else if (portStream)
        return [[portStream endpoints] anyObject];
    else
        return nil;
}

- (void)setSelectedDestination:(id <SSEOutputStreamDestination>)aDestination;
{
    if (aDestination) {
        if ([aDestination isKindOfClass:[SMDestinationEndpoint class]])
            [self selectEndpoint:(SMDestinationEndpoint *)aDestination];
        else
            [self selectEndpoint:nil];	// Use the virtual stream
    } else {
        // Deselect everything
        [self removePortStream];
        [self removeVirtualStream];
    }
}

- (void)setVirtualDisplayName:(NSString *)newName;
{
    [virtualStreamDestination setName:newName];
}

- (NSDictionary *)persistentSettings;
{
    if (portStream) {
        SMDestinationEndpoint *endpoint;
        
        if ((endpoint = [[portStream endpoints] anyObject])) {
            NSMutableDictionary *dict;
            NSString *name;
        
            dict = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:[endpoint uniqueID]] forKey:@"portEndpointUniqueID"];
            if ((name = [endpoint name])) {
                [dict setObject:name forKey:@"portEndpointName"];
            }
            
            return dict;
        }
    } else if (virtualStream) {
        return [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:[[virtualStream endpoint] uniqueID]] forKey:@"virtualEndpointUniqueID"];
    }

    return nil;
}

- (NSString *)takePersistentSettings:(NSDictionary *)settings;
{
    NSNumber *number;

    if ((number = [settings objectForKey:@"portEndpointUniqueID"])) {
        SMDestinationEndpoint *endpoint;

        endpoint = [SMDestinationEndpoint destinationEndpointWithUniqueID:[number intValue]];
        if (endpoint) {
            [self selectEndpoint:endpoint];
        } else {
            NSString *endpointName;
        
            endpointName = [settings objectForKey:@"portEndpointName"];
            if (endpointName) {
                // Maybe an endpoint with this name still exists, but with a different unique ID.
                endpoint = [SMDestinationEndpoint destinationEndpointWithName:endpointName];
                if (endpoint)
                    [self selectEndpoint:endpoint];
                else
                    return endpointName;
            } else {
                return NSLocalizedStringFromTableInBundle(@"Unknown", @"SysExLibrarian", SMBundleForObject(self), "name of missing endpoint if not specified in document");
            }
        }
    } else if ((number = [settings objectForKey:@"virtualEndpointUniqueID"])) {
        [self removeVirtualStream];
        virtualEndpointUniqueID = [number intValue];
        [self selectEndpoint:nil];  // Use the virtual stream
    }

    return nil;
}

- (id)stream;
{
    if (virtualStream)
        return virtualStream;
    else
        return portStream;
}

- (BOOL)ignoresTimeStamps;
{
    return flags.ignoresTimeStamps;
}

- (void)setIgnoresTimeStamps:(BOOL)value;
{
    flags.ignoresTimeStamps = value;
    [[self stream] setIgnoresTimeStamps:value];
}

- (BOOL)sendsSysExAsynchronously;
{
    return flags.sendsSysExAsynchronously;
}

- (void)setSendsSysExAsynchronously:(BOOL)value;
{
    flags.sendsSysExAsynchronously = value;
    if ([[self stream] respondsToSelector:@selector(setSendsSysExAsynchronously:)])
        [[self stream] setSendsSysExAsynchronously:value];
}

- (BOOL)canSendSysExAsynchronously;
{
    return ([self stream] == portStream);
}

- (void)cancelPendingSysExSendRequests;
{
    if ([[self stream] respondsToSelector:@selector(cancelPendingSysExSendRequests)])
        [[self stream] cancelPendingSysExSendRequests];
}

- (SMSysExSendRequest *)currentSysExSendRequest;
{
    SMSysExSendRequest *currentSysExSendRequest = nil;
    
    if ([[self stream] respondsToSelector:@selector(pendingSysExSendRequests)]) {
        NSArray *pending = [[self stream] pendingSysExSendRequests];
        if (pending && [pending count] > 0)
            currentSysExSendRequest = [pending objectAtIndex: 0];
    }
    
    return currentSysExSendRequest;
}

//
// SMMessageDestination protocol
//

- (void)takeMIDIMessages:(NSArray *)messages;
{
    [[self stream] takeMIDIMessages:messages];
}

@end


@implementation SSECombinationOutputStream (Private)

- (void)selectEndpoint:(SMDestinationEndpoint *)endpoint;
{
    if (endpoint) {
        // Set up the port stream
        if (!portStream)
            [self createPortStream];
        [portStream setEndpoints:[NSSet setWithObject:endpoint]];

        [self removeVirtualStream];
    } else {
        // Set up the virtual stream
        if (!virtualStream)
            [self createVirtualStream];

        [self removePortStream];
    }
}

- (void)createPortStream;
{
    SMAssert(portStream == nil);

    NS_DURING {
        portStream = [[SMPortOutputStream alloc] init];
        [portStream setIgnoresTimeStamps:flags.ignoresTimeStamps];
        [portStream setSendsSysExAsynchronously:flags.sendsSysExAsynchronously];
    } NS_HANDLER {
        [portStream release];
        portStream = nil;
    } NS_ENDHANDLER;

    if (portStream) {
        NSNotificationCenter *center;

        center = [NSNotificationCenter defaultCenter];
        
        [center addObserver:self selector:@selector(portStreamEndpointDisappeared:) name:SMPortOutputStreamEndpointDisappearedNotification object:portStream];
        [center addObserver:self selector:@selector(repostNotification:) name:SMPortOutputStreamWillStartSysExSendNotification object:portStream];
        [center addObserver:self selector:@selector(repostNotification:) name:SMPortOutputStreamFinishedSysExSendNotification object:portStream];
    }
}

- (void)removePortStream;
{
    if (portStream) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:portStream];

        [portStream release];
        portStream = nil;
    }
}

- (void)createVirtualStream;
{
    SMAssert(virtualStream == nil);

    virtualStream = [[SMVirtualOutputStream alloc] initWithName:virtualEndpointName uniqueID:virtualEndpointUniqueID];
    if (virtualStream) {
        [virtualStream setIgnoresTimeStamps:flags.ignoresTimeStamps];

        // We may not have specified a unique ID for the virtual endpoint, or it may not have actually stuck,
        // so update our idea of what it is.
        virtualEndpointUniqueID = [[virtualStream endpoint] uniqueID];
    }
}

- (void)removeVirtualStream;
{
    [virtualStream release];
    virtualStream = nil;
}

- (void)repostNotification:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:[notification name] object:self userInfo:[notification userInfo]];
}

- (void)portStreamEndpointDisappeared:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SSECombinationOutputStreamSelectedDestinationDisappearedNotification object:self];
}

- (void)portStreamEndpointListChanged:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SSECombinationOutputStreamDestinationListChangedNotification object:self];
}
 
@end
