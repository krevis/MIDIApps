/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SMMSpyingInputStream.h"



@interface SMMSpyingInputStream (Private)

- (void)endpointListChanged:(NSNotification *)notification;
- (void)endpointDisappeared:(NSNotification *)notification;
- (void)endpointWasReplaced:(NSNotification *)notification;

@end


@implementation SMMSpyingInputStream

- (id)initWithMIDISpyClient:(MIDISpyClientRef)midiSpyClient;
{
    OSStatus status;

    if (!(self = [super init]))
        return nil;

    if (!midiSpyClient) {
        [self release];
        return nil;
    }
    spyClient = midiSpyClient;

    status = MIDISpyPortCreate(spyClient, [self midiReadProc], self, &spyPort);
    if (status != noErr) {
#if DEBUG
        NSLog(@"Couldn't create a MIDI spy port: error %ld", (long)status);
#endif
        [self release];
        return nil;
    }
        
    endpoints = [[NSMutableSet alloc] init];

    parsersForEndpoints = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 0);

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endpointListChanged:) name:SMMIDIObjectListChangedNotification object:[SMDestinationEndpoint class]];

    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (spyPort)
        MIDISpyPortDispose(spyPort);
    spyPort = NULL;

    // Don't tear down the spy client, since others may be using it
    spyClient = NULL;

    [endpoints release];
    endpoints = nil;

    NSFreeMapTable(parsersForEndpoints);
    parsersForEndpoints = NULL;

    [super dealloc];
}

- (NSSet *)endpoints;
{
    return [NSSet setWithSet:endpoints];
}

- (void)addEndpoint:(SMDestinationEndpoint *)endpoint;
{
    SMMessageParser *parser;
    OSStatus status;
    NSNotificationCenter *center;

    if (!endpoint)
        return;

    if ([endpoints containsObject:endpoint])
        return;

    parser = [self createParserWithOriginatingEndpoint:endpoint];
    NSMapInsert(parsersForEndpoints, endpoint, parser);
    
    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(endpointDisappeared:) name:SMMIDIObjectDisappearedNotification object:endpoint];
    [center addObserver:self selector:@selector(endpointWasReplaced:) name:SMMIDIObjectWasReplacedNotification object:endpoint];
    
    [endpoints addObject:endpoint];
    
    status = MIDISpyPortConnectDestination(spyPort, [endpoint endpointRef], endpoint);
    if (status != noErr) {
        NSLog(@"Error from MIDISpyPortConnectDestination: %ld", (long)status);
        return;
    }
}

- (void)removeEndpoint:(SMDestinationEndpoint *)endpoint;
{
    OSStatus status;
    NSNotificationCenter *center;

    if (!endpoint)
        return;

    if (![endpoints containsObject:endpoint])
        return;

    status = MIDISpyPortDisconnectDestination(spyPort, [endpoint endpointRef]);
    if (status != noErr) {
        NSLog(@"Error from MIDISpyPortDisconnectDestination: %ld", (long)status);
        // An error can happen in normal circumstances (if the endpoint has disappeared), so ignore it.
    }

    NSMapRemove(parsersForEndpoints, endpoint);

    center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:SMMIDIObjectDisappearedNotification object:endpoint];
    [center removeObserver:self name:SMMIDIObjectWasReplacedNotification object:endpoint];

    [endpoints removeObject:endpoint];
}

- (void)setEndpoints:(NSSet *)newEndpoints;
{
    NSMutableSet *endpointsToRemove;
    NSMutableSet *endpointsToAdd;
    NSEnumerator *enumerator;
    SMDestinationEndpoint *endpoint;

    // remove (endpoints - newEndpoints)
    endpointsToRemove = [NSMutableSet setWithSet:endpoints];
    [endpointsToRemove minusSet:newEndpoints];

    // add (newEndpoints - endpoints)
    endpointsToAdd = [NSMutableSet setWithSet:newEndpoints];
    [endpointsToAdd minusSet:endpoints];

    enumerator = [endpointsToRemove objectEnumerator];
    while ((endpoint = [enumerator nextObject]))
        [self removeEndpoint:endpoint];

    enumerator = [endpointsToAdd objectEnumerator];
    while ((endpoint = [enumerator nextObject]))
        [self addEndpoint:endpoint];
}


//
// SMInputStream subclass
//

- (NSArray *)parsers;
{
    return NSAllMapTableValues(parsersForEndpoints);
}

- (SMMessageParser *)parserForSourceConnectionRefCon:(void *)refCon;
{
    // note: refCon is an SMDestinationEndpoint*.
    // We are allowed to return nil if we are no longer listening to this source endpoint.
    return (SMMessageParser*)NSMapGet(parsersForEndpoints, refCon);
}

- (id<SMInputStreamSource>)streamSourceForParser:(SMMessageParser *)parser;
{
    return [parser originatingEndpoint];
}

- (void)retainForIncomingMIDIWithSourceConnectionRefCon:(void *)refCon
{
    // retain self
    [super retainForIncomingMIDIWithSourceConnectionRefCon:refCon];
    
    // and retain the endpoint too, since we use it as a key in -parserForSourceConnectionRefCon:
    [(SMDestinationEndpoint*)refCon retain];
}

- (void)releaseForIncomingMIDIWithSourceConnectionRefCon:(void *)refCon
{
    // release the endpoint that we retained earlier
    [(SMDestinationEndpoint*)refCon release];
    
    // and release self, LAST
    [super releaseForIncomingMIDIWithSourceConnectionRefCon:refCon];    
}

- (NSArray *)inputSources;
{
    NSMutableArray *inputSources;
    unsigned int inputSourceIndex;

    inputSources = [NSMutableArray arrayWithArray:[SMDestinationEndpoint destinationEndpoints]];
    inputSourceIndex = [inputSources count];
    while (inputSourceIndex--) {
        if ([[inputSources objectAtIndex:inputSourceIndex] isOwnedByThisProcess])
            [inputSources removeObjectAtIndex:inputSourceIndex];
    }

    return inputSources;
}

- (NSSet *)selectedInputSources;
{
    return [self endpoints];
}

- (void)setSelectedInputSources:(NSSet *)sources;
{
    [self setEndpoints:sources];
}

@end


@implementation SMMSpyingInputStream (Private)

- (void)endpointListChanged:(NSNotification *)notification;
{
    [self postSourceListChangedNotification];
}

- (void)endpointDisappeared:(NSNotification *)notification;
{
    SMDestinationEndpoint *endpoint;

    endpoint = [[[notification object] retain] autorelease];
    SMAssert([endpoints containsObject:endpoint]);

    [self removeEndpoint:endpoint];

    [self postSelectedInputStreamSourceDisappearedNotification:endpoint];
}

- (void)endpointWasReplaced:(NSNotification *)notification;
{
    SMDestinationEndpoint *oldEndpoint, *newEndpoint;

    oldEndpoint = [notification object];
    SMAssert([endpoints containsObject:oldEndpoint]);

    newEndpoint = [[notification userInfo] objectForKey:SMMIDIObjectReplacement];

    [self removeEndpoint:oldEndpoint];
    [self addEndpoint:newEndpoint];
}

@end
