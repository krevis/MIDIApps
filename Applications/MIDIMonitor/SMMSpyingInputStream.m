//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMMSpyingInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import "SMDestinationEndpoint-Additions.h"


@interface SMMSpyingInputStream (Private)

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
        
    endpoints = [[NSMutableArray alloc] init];

    parsersForEndpoints = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 0);

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

- (NSArray *)endpoints;
{
    return [NSArray arrayWithArray:endpoints];
}

- (void)addEndpoint:(SMDestinationEndpoint *)endpoint;
{
    SMMessageParser *parser;
    OSStatus status;
    NSNotificationCenter *center;

    if (!endpoint)
        return;

    if ([endpoints indexOfObjectIdenticalTo:endpoint] != NSNotFound)
        return;

    parser = [self newParserWithOriginatingEndpoint:endpoint];

    status = MIDISpyPortConnectDestination(spyPort, [endpoint endpointRef], parser);
    if (status != noErr) {
        NSLog(@"Error from MIDISpyPortConnectDestination: %ld", status);
        return;
    }

    NSMapInsert(parsersForEndpoints, endpoint, parser);

    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(endpointDisappeared:) name:SMEndpointDisappearedNotification object:endpoint];
    [center addObserver:self selector:@selector(endpointWasReplaced:) name:SMEndpointWasReplacedNotification object:endpoint];

    [endpoints addObject:endpoint];
}

- (void)removeEndpoint:(SMDestinationEndpoint *)endpoint;
{
    OSStatus status;
    NSNotificationCenter *center;

    if (!endpoint)
        return;

    if ([endpoints indexOfObjectIdenticalTo:endpoint] == NSNotFound)
        return;

    status = MIDISpyPortDisconnectDestination(spyPort, [endpoint endpointRef]);
    if (status != noErr) {
        NSLog(@"Error from MIDISpyPortDisconnectDestination: %ld", status);
        // An error can happen in normal circumstances (if the endpoint has disappeared), so ignore it.
    }

    NSMapRemove(parsersForEndpoints, endpoint);

    center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:SMEndpointDisappearedNotification object:endpoint];
    [center removeObserver:self name:SMEndpointWasReplacedNotification object:endpoint];

    [endpoints removeObjectIdenticalTo:endpoint];
}

- (void)setEndpoints:(NSArray *)newEndpoints;
{
    NSMutableArray *endpointsToRemove;
    NSMutableArray *endpointsToAdd;
    unsigned int index;

    // remove (endpoints - newEndpoints)
    endpointsToRemove = [NSMutableArray arrayWithArray:endpoints];
    [endpointsToRemove removeIdenticalObjectsFromArray:newEndpoints];

    // add (newEndpoints - endpoints)
    endpointsToAdd = [NSMutableArray arrayWithArray:newEndpoints];
    [endpointsToAdd removeIdenticalObjectsFromArray:endpoints];

    index = [endpointsToRemove count];
    while (index--)
        [self removeEndpoint:[endpointsToRemove objectAtIndex:index]];

    index = [endpointsToAdd count];
    while (index--)
        [self addEndpoint:[endpointsToAdd objectAtIndex:index]];
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

- (NSArray *)selectedInputSources;
{
    return [self endpoints];
}

- (void)setSelectedInputSources:(NSArray *)sources;
{
    [self setEndpoints:sources];
}

@end


@implementation SMMSpyingInputStream (Private)

- (void)endpointDisappeared:(NSNotification *)notification;
{
    SMDestinationEndpoint *endpoint;

    endpoint = [[[notification object] retain] autorelease];
    OBASSERT([endpoints indexOfObjectIdenticalTo:endpoint] != NSNotFound);

    [self removeEndpoint:endpoint];

    [self postSelectedInputStreamSourceDisappearedNotification:endpoint];
}

- (void)endpointWasReplaced:(NSNotification *)notification;
{
    SMDestinationEndpoint *oldEndpoint, *newEndpoint;

    oldEndpoint = [notification object];
    OBASSERT([endpoints indexOfObjectIdenticalTo:oldEndpoint] != NSNotFound);

    newEndpoint = [[notification userInfo] objectForKey:SMEndpointReplacement];

    [self removeEndpoint:oldEndpoint];
    [self addEndpoint:newEndpoint];
}

@end
