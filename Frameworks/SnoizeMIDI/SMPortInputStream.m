//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

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
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't create a MIDI input port (error %ld)", @"SnoizeMIDI", SMBundleForObject(self), "exception with OSStatus if MIDIInputPortCreate() fails"), status];

    endpoints = [[NSMutableSet alloc] init];

    parsersForEndpoints = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 0);

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endpointListChanged:) name:SMMIDIObjectListChangedNotification object:[SMSourceEndpoint class]];
    
    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (inputPort)
        MIDIPortDispose(inputPort);
    inputPort = NULL;

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

- (void)addEndpoint:(SMSourceEndpoint *)endpoint;
{
    SMMessageParser *parser;
    OSStatus status;
    NSNotificationCenter *center;

    if (!endpoint)
        return;
    
    if ([endpoints containsObject:endpoint])
        return;

    parser = [self newParserWithOriginatingEndpoint:endpoint];
    
    status = MIDIPortConnectSource(inputPort, [endpoint endpointRef], parser);
    if (status != noErr) {
        NSLog(@"Error from MIDIPortConnectSource: %d", status);
        return;
    }

    NSMapInsert(parsersForEndpoints, endpoint, parser);

    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(endpointDisappeared:) name:SMMIDIObjectDisappearedNotification object:endpoint];
    [center addObserver:self selector:@selector(endpointWasReplaced:) name:SMMIDIObjectWasReplacedNotification object:endpoint];

    [endpoints addObject:endpoint];
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
    return NSAllMapTableValues(parsersForEndpoints);
}

- (SMMessageParser *)parserForSourceConnectionRefCon:(void *)refCon;
{
    return (SMMessageParser *)refCon;
}

- (id<SMInputStreamSource>)streamSourceForParser:(SMMessageParser *)parser;
{
    return [parser originatingEndpoint];
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
