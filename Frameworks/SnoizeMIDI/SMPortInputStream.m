//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMPortInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMInputStreamSource.h"
#import "SMEndpoint.h"
#import "SMMessageParser.h"


@interface SMPortInputStream (Private)

- (void)_endpointDisappeared:(NSNotification *)notification;
- (void)_endpointWasReplaced:(NSNotification *)notification;

@end


@implementation SMPortInputStream

DEFINE_NSSTRING(SMPortInputStreamEndpointDisappeared);


- (id)init;
{
    OSStatus status;

    if (!(self = [super init]))
        return nil;

    status = MIDIInputPortCreate([[SMClient sharedClient] midiClient], (CFStringRef)@"Input port", [self midiReadProc], self, &inputPort);
    if (status != noErr)
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't create a MIDI input port (error %ld)", @"SnoizeMIDI", [self bundle], "exception with OSStatus if MIDIInputPortCreate() fails"), status];

    endpoints = [[NSMutableArray alloc] init];

    parsersForEndpoints = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 0);

    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    MIDIPortDispose(inputPort);
    inputPort = NULL;

    [endpoints release];
    endpoints = nil;

    NSFreeMapTable(parsersForEndpoints);
    
    [super dealloc];
}

- (NSArray *)endpoints;
{
    return [NSArray arrayWithArray:endpoints];
}

- (void)addEndpoint:(SMSourceEndpoint *)endpoint;
{
    SMMessageParser *parser;
    OSStatus status;
    NSNotificationCenter *center;

    if (!endpoint)
        return;
    
    if ([endpoints indexOfObjectIdenticalTo:endpoint] != NSNotFound)
        return;

    parser = [self newParser];
    
    status = MIDIPortConnectSource(inputPort, [endpoint endpointRef], parser);
    if (status != noErr) {
        NSLog(@"Error from MIDIPortConnectSource: %d", status);
        return;
    }

    NSMapInsert(parsersForEndpoints, endpoint, parser);

    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_endpointDisappeared:) name:SMEndpointDisappearedNotification object:endpoint];
    [center addObserver:self selector:@selector(_endpointWasReplaced:) name:SMEndpointWasReplacedNotification object:endpoint];

    [endpoints addObject:endpoint];
}

- (void)removeEndpoint:(SMSourceEndpoint *)endpoint;
{
    OSStatus status;
    NSNotificationCenter *center;

    if (!endpoint)
        return;

    if ([endpoints indexOfObjectIdenticalTo:endpoint] == NSNotFound)
        return;
    
    status = MIDIPortDisconnectSource(inputPort, [endpoint endpointRef]);
    if (status != noErr) {
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
    return [SMSourceEndpoint sourceEndpoints];
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


@implementation SMPortInputStream (Private)

- (void)_endpointDisappeared:(NSNotification *)notification;
{
    SMSourceEndpoint *endpoint;

    endpoint = [notification object];
    OBASSERT([endpoints indexOfObjectIdenticalTo:endpoint] != NSNotFound);

    [self removeEndpoint:endpoint];

    [[NSNotificationCenter defaultCenter] postNotificationName:SMPortInputStreamEndpointDisappeared object:self];
}

- (void)_endpointWasReplaced:(NSNotification *)notification;
{
    SMSourceEndpoint *oldEndpoint, *newEndpoint;

    oldEndpoint = [notification object];
    OBASSERT([endpoints indexOfObjectIdenticalTo:oldEndpoint] != NSNotFound);    

    newEndpoint = [[notification userInfo] objectForKey:SMEndpointReplacement];

    [self removeEndpoint:oldEndpoint];
    [self addEndpoint:newEndpoint];    
}

@end
