//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMMSpyingInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface SMMSpyingInputStream (Private)

- (void)endpointDisappeared:(NSNotification *)notification;
- (void)endpointWasReplaced:(NSNotification *)notification;

static void spyClientCallBack(SInt32 endpointUniqueID, CFStringRef endpointName, const MIDIPacketList *packetList, void *refCon);

@end


@implementation SMMSpyingInputStream

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    spyClient = MIDISpyClientCreate(spyClientCallBack, self);
    if (!spyClient) {
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

    if (spyClient)
        MIDISpyClientDispose(spyClient);
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
    NSNotificationCenter *center;

    if (!endpoint)
        return;

    if ([endpoints indexOfObjectIdenticalTo:endpoint] != NSNotFound)
        return;

    parser = [self newParserWithOriginatingEndpoint:endpoint];

    // TODO hook up spying client
    /*
    status = MIDIPortConnectSource(inputPort, [endpoint endpointRef], parser);
    if (status != noErr) {
        NSLog(@"Error from MIDIPortConnectSource: %d", status);
        return;
    }
     */

    NSMapInsert(parsersForEndpoints, endpoint, parser);

    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_endpointDisappeared:) name:SMEndpointDisappearedNotification object:endpoint];
    [center addObserver:self selector:@selector(_endpointWasReplaced:) name:SMEndpointWasReplacedNotification object:endpoint];

    [endpoints addObject:endpoint];
}

- (void)removeEndpoint:(SMDestinationEndpoint *)endpoint;
{
    NSNotificationCenter *center;

    if (!endpoint)
        return;

    if ([endpoints indexOfObjectIdenticalTo:endpoint] == NSNotFound)
        return;

    // TODO disconnect w/spying client
    /*
    status = MIDIPortDisconnectSource(inputPort, [endpoint endpointRef]);
    if (status != noErr) {
        // An error can happen in normal circumstances (if the endpoint has disappeared), so ignore it.
    }
     */

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
    // In our case, the "refCon" is really a destination endpoint
    return NSMapGet(parsersForEndpoints, refCon);
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

    endpoint = [notification object];
    OBASSERT([endpoints indexOfObjectIdenticalTo:endpoint] != NSNotFound);

    [self removeEndpoint:endpoint];

    // TODO need to post a notification?
    //[[NSNotificationCenter defaultCenter] postNotificationName:SMPortInputStreamEndpointDisappeared object:self];
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


static void spyClientCallBack(SInt32 endpointUniqueID, CFStringRef endpointName, const MIDIPacketList *packetList, void *refCon)
{
    SMDestinationEndpoint *destinationEndpoint;

    if ((destinationEndpoint = [SMDestinationEndpoint destinationEndpointWithUniqueID:endpointUniqueID])) {
        [[(SMMSpyingInputStream *)refCon parserForSourceConnectionRefCon:destinationEndpoint] takePacketList:packetList];
    }
}

// TODO
// Also... we should make the communication channel to the spy driver only pass the MIDI data for endpoints that we are interested in, not all of them.

@end
