//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

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
        NSLog(@"Couldn't create a MIDI spy port: error %ld", status);
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

    parser = [self newParserWithOriginatingEndpoint:endpoint];

    status = MIDISpyPortConnectDestination(spyPort, [endpoint endpointRef], parser);
    if (status != noErr) {
        NSLog(@"Error from MIDISpyPortConnectDestination: %ld", status);
        return;
    }

    NSMapInsert(parsersForEndpoints, endpoint, parser);

    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(endpointDisappeared:) name:SMMIDIObjectDisappearedNotification object:endpoint];
    [center addObserver:self selector:@selector(endpointWasReplaced:) name:SMMIDIObjectWasReplacedNotification object:endpoint];

    [endpoints addObject:endpoint];
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
        NSLog(@"Error from MIDISpyPortDisconnectDestination: %ld", status);
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
    return (SMMessageParser *)refCon;
}

- (id<SMInputStreamSource>)streamSourceForParser:(SMMessageParser *)parser;
{
    return [parser originatingEndpoint];
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
