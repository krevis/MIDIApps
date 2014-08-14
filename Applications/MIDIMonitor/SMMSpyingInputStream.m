/*
 Copyright (c) 2001-2014, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SMMSpyingInputStream.h"

@interface SMMSpyingInputStream ()
{
    NSMutableSet *_endpoints;
}

@property (nonatomic, assign) MIDISpyClientRef spyClient;
@property (nonatomic, assign) MIDISpyPortRef spyPort;
@property (nonatomic, retain) NSMapTable *parsersForEndpoints;

@end

@implementation SMMSpyingInputStream

- (instancetype)initWithMIDISpyClient:(MIDISpyClientRef)midiSpyClient;
{
    if (!(self = [super init])) {
        return nil;
    }

    if (!midiSpyClient) {
        [self release];
        return nil;
    }
    _spyClient = midiSpyClient;

    OSStatus status = MIDISpyPortCreate(_spyClient, self.midiReadProc, self, &_spyPort);
    if (status != noErr) {
#if DEBUG
        NSLog(@"Couldn't create a MIDI spy port: error %ld", (long)status);
#endif
        [self release];
        return nil;
    }
        
    _endpoints = [[NSMutableSet alloc] init];

    _parsersForEndpoints = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 0);

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endpointListChanged:) name:SMMIDIObjectListChangedNotification object:[SMDestinationEndpoint class]];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (_spyPort) {
        MIDISpyPortDispose(_spyPort);
    }
    _spyPort = NULL;

    // Don't tear down the spy client, since others may be using it
    _spyClient = NULL;

    [_endpoints release];
    _endpoints = nil;

    NSFreeMapTable(_parsersForEndpoints);
    _parsersForEndpoints = NULL;

    [super dealloc];
}

- (NSSet *)endpoints
{
    return [NSSet setWithSet:_endpoints];
}

- (void)addEndpoint:(SMDestinationEndpoint *)endpoint
{
    if (endpoint && ![_endpoints containsObject:endpoint]) {
        SMMessageParser *parser = [self createParserWithOriginatingEndpoint:endpoint];
        NSMapInsert(self.parsersForEndpoints, endpoint, parser);
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(endpointDisappeared:) name:SMMIDIObjectDisappearedNotification object:endpoint];
        [center addObserver:self selector:@selector(endpointWasReplaced:) name:SMMIDIObjectWasReplacedNotification object:endpoint];
        
        [_endpoints addObject:endpoint];
        
        OSStatus status = MIDISpyPortConnectDestination(self.spyPort, endpoint.endpointRef, endpoint);
        if (status != noErr) {
            NSLog(@"Error from MIDISpyPortConnectDestination: %ld", (long)status);
        }
    }
}

- (void)removeEndpoint:(SMDestinationEndpoint *)endpoint
{
    if (endpoint && [_endpoints containsObject:endpoint]) {
        OSStatus status = MIDISpyPortDisconnectDestination(self.spyPort, [endpoint endpointRef]);
        if (status != noErr) {
            NSLog(@"Error from MIDISpyPortDisconnectDestination: %ld", (long)status);
            // An error can happen in normal circumstances (if the endpoint has disappeared), so ignore it.
        }

        NSMapRemove(self.parsersForEndpoints, endpoint);

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center removeObserver:self name:SMMIDIObjectDisappearedNotification object:endpoint];
        [center removeObserver:self name:SMMIDIObjectWasReplacedNotification object:endpoint];

        [_endpoints removeObject:endpoint];
    }
}

- (void)setEndpoints:(NSSet *)newEndpoints
{
    // remove (endpoints - newEndpoints)
    NSMutableSet *endpointsToRemove = [NSMutableSet setWithSet:_endpoints];
    [endpointsToRemove minusSet:newEndpoints];

    // add (newEndpoints - endpoints)
    NSMutableSet *endpointsToAdd = [NSMutableSet setWithSet:newEndpoints];
    [endpointsToAdd minusSet:_endpoints];

    for (SMDestinationEndpoint *endpoint in endpointsToRemove) {
        [self removeEndpoint:endpoint];
    }

    for (SMDestinationEndpoint *endpoint in endpointsToAdd) {
        [self addEndpoint:endpoint];
    }
}


//
// SMInputStream subclass
//

- (NSArray *)parsers
{
    return NSAllMapTableValues(self.parsersForEndpoints);
}

- (SMMessageParser *)parserForSourceConnectionRefCon:(void *)refCon
{
    // note: refCon is an SMDestinationEndpoint*.
    // We are allowed to return nil if we are no longer listening to this source endpoint.
    return (SMMessageParser*)NSMapGet(self.parsersForEndpoints, refCon);
}

- (id<SMInputStreamSource>)streamSourceForParser:(SMMessageParser *)parser
{
    return parser.originatingEndpoint;
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

- (NSArray *)inputSources
{
    NSMutableArray *inputSources = [NSMutableArray arrayWithArray:[SMDestinationEndpoint destinationEndpoints]];
    NSUInteger inputSourceIndex = [inputSources count];
    while (inputSourceIndex--) {
        if ([[inputSources objectAtIndex:inputSourceIndex] isOwnedByThisProcess])
            [inputSources removeObjectAtIndex:inputSourceIndex];
    }

    return inputSources;
}

- (NSSet *)selectedInputSources
{
    return self.endpoints;
}

- (void)setSelectedInputSources:(NSSet *)sources
{
    self.endpoints = sources;
}

#pragma mark Private

- (void)endpointListChanged:(NSNotification *)notification
{
    [self postSourceListChangedNotification];
}

- (void)endpointDisappeared:(NSNotification *)notification
{
    SMDestinationEndpoint *endpoint = [[notification.object retain] autorelease];
    SMAssert([_endpoints containsObject:endpoint]);

    [self removeEndpoint:endpoint];

    [self postSelectedInputStreamSourceDisappearedNotification:endpoint];
}

- (void)endpointWasReplaced:(NSNotification *)notification
{
    SMDestinationEndpoint *oldEndpoint = notification.object;
    SMAssert([_endpoints containsObject:oldEndpoint]);

    SMDestinationEndpoint *newEndpoint = notification.userInfo[SMMIDIObjectReplacement];

    [self removeEndpoint:oldEndpoint];
    [self addEndpoint:newEndpoint];
}

@end
