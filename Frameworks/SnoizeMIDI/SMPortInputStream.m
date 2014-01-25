/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMPortInputStream.h"

#import "SMClient.h"
#import "SMInputStreamSource.h"
#import "SMEndpoint.h"
#import "SMMessageParser.h"
#import "SMUtilities.h"


@interface SMPortInputStream (Private)

- (void)endpointListChanged:(NSNotification *)notification;
- (void)endpointDisappeared:(NSNotification *)notification;
- (void)endpointWasReplaced:(NSNotification *)notification;

@end


@implementation SMPortInputStream

- (id)init;
{
    OSStatus status;
    
    if (!(self = [super init]))
        return nil;
    
    status = MIDIInputPortCreate([[SMClient sharedClient] midiClient], (CFStringRef)@"Input port", [self midiReadProc], self, &inputPort);
    if (status != noErr)
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't create a MIDI input port (error %d)", @"SnoizeMIDI", SMBundleForObject(self), "exception with OSStatus if MIDIInputPortCreate() fails"), (int)status];
    
    endpoints = [[NSMutableSet alloc] init];
    
    parsersForEndpoints = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endpointListChanged:) name:SMMIDIObjectListChangedNotification object:[SMSourceEndpoint class]];
    
    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (inputPort)
        MIDIPortDispose(inputPort);
    inputPort = (MIDIPortRef)0;
    
    [endpoints release];
    endpoints = nil;
    
    CFRelease(parsersForEndpoints);
    parsersForEndpoints = NULL;
    
    [super dealloc];
}

- (NSSet *)endpoints;
{
    return [NSSet setWithSet:endpoints];
}

- (void)addEndpoint:(SMSourceEndpoint *)endpoint;
{
    SMMessageParser *parser;
    OSStatus status;
    NSNotificationCenter *center;
    
    if (!endpoint)
        return;
    
    if ([endpoints containsObject:endpoint])
        return;
    
    parser = [self createParserWithOriginatingEndpoint:endpoint];
    CFDictionarySetValue(parsersForEndpoints, endpoint, parser);
    
    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(endpointDisappeared:) name:SMMIDIObjectDisappearedNotification object:endpoint];
    [center addObserver:self selector:@selector(endpointWasReplaced:) name:SMMIDIObjectWasReplacedNotification object:endpoint];
    
    [endpoints addObject:endpoint];
    
    status = MIDIPortConnectSource(inputPort, [endpoint endpointRef], endpoint);
    if (status != noErr) {
        NSLog(@"Error from MIDIPortConnectSource: %ld", (long)status);
    }
    
    // At any time after MIDIPortConnectSource(), we can expect -retainForIncomingMIDIWithSourceConnectionRefCon:
    // and -parserForSourceConnectionRefCon: to be called.
}

- (void)removeEndpoint:(SMSourceEndpoint *)endpoint;
{
    OSStatus status;
    NSNotificationCenter *center;
    
    if (!endpoint)
        return;
    
    if (![endpoints containsObject:endpoint])
        return;
    
    status = MIDIPortDisconnectSource(inputPort, [endpoint endpointRef]);
    if (status != noErr) {
        // An error can happen in normal circumstances (if the endpoint has disappeared), so ignore it.
    }
    
    // At any time after MIDIPortDisconnectSource(), we can expect that
    // -retainForIncomingMIDIWithSourceConnectionRefCon: will no longer be called.
    // However, -parserForSourceConnectionRefCon: may still be called, on the main thread, later on;
    // it should not crash or fail, but it may return nil.
    
    CFDictionaryRemoveValue(parsersForEndpoints, endpoint);
    
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
    SMSourceEndpoint *endpoint;
    
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
    CFIndex count = CFDictionaryGetCount(parsersForEndpoints);
    if (count > 0)
    {
        const void **keys = malloc(count * sizeof(void*));
        const void **values = malloc(count * sizeof(void*));
        
        CFDictionaryGetKeysAndValues(parsersForEndpoints, keys, values);
        
        NSArray *array = [NSArray arrayWithObjects:(id *)values count:count];
        
        free(keys);
        free(values);
        
        return array;
    }
    else
        return [NSArray array];
}

- (SMMessageParser *)parserForSourceConnectionRefCon:(void *)refCon;
{
    // note: refCon is an SMSourceEndpoint*.
    // We are allowed to return nil if we are no longer listening to this source endpoint.
    return (SMMessageParser*)CFDictionaryGetValue(parsersForEndpoints, refCon);
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
    [(SMSourceEndpoint*)refCon retain];
}

- (void)releaseForIncomingMIDIWithSourceConnectionRefCon:(void *)refCon
{
    // release the endpoint that we retained earlier
    [(SMSourceEndpoint*)refCon release];
    
    // and release self, LAST
    [super releaseForIncomingMIDIWithSourceConnectionRefCon:refCon];    
}

- (NSArray *)inputSources;
{
    return [SMSourceEndpoint sourceEndpoints];
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


@implementation SMPortInputStream (Private)

- (void)endpointListChanged:(NSNotification *)notification;
{
    [self postSourceListChangedNotification];
}

- (void)endpointDisappeared:(NSNotification *)notification;
{
    SMSourceEndpoint *endpoint;
    
    endpoint = [[[notification object] retain] autorelease];
    SMAssert([endpoints containsObject:endpoint]);
    
    [self removeEndpoint:endpoint];
    
    [self postSelectedInputStreamSourceDisappearedNotification:endpoint];
}

- (void)endpointWasReplaced:(NSNotification *)notification;
{
    SMSourceEndpoint *oldEndpoint, *newEndpoint;
    
    oldEndpoint = [notification object];
    SMAssert([endpoints containsObject:oldEndpoint]);
    
    newEndpoint = [[notification userInfo] objectForKey:SMMIDIObjectReplacement];
    
    [self removeEndpoint:oldEndpoint];
    [self addEndpoint:newEndpoint];    
}

@end
