//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMMSpyingInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface SMMSpyingInputStream (Private)

- (void)endpointAppeared:(NSNotification *)notification;
- (void)endpointDisappeared:(NSNotification *)notification;
- (void)endpointWasReplaced:(NSNotification *)notification;

- (void)addEndpointToMapTable:(SMDestinationEndpoint *)endpoint withParser:(SMMessageParser *)parser;

static void spyClientCallBack(SInt32 endpointUniqueID, CFStringRef endpointName, const MIDIPacketList *packetList, void *refCon);

@end


@implementation SMMSpyingInputStream

- (id)init;
{
    NSArray *destinationEndpoints;
    unsigned int destinationEndpointCount, destinationEndpointIndex;
    
    if (!(self = [super init]))
        return nil;

    inputStreamSource = [[SMSimpleInputStreamSource alloc] initWithName:@"Spy on computer output"];
    // TODO better name

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endpointAppeared:) name:SMEndpointAppearedNotification object:nil];

    endpointToParserMapTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSObjectMapValueCallBacks, 0);

    destinationEndpoints = [SMDestinationEndpoint destinationEndpoints];
    destinationEndpointCount = [destinationEndpoints count];
    for (destinationEndpointIndex = 0; destinationEndpointIndex < destinationEndpointCount; destinationEndpointIndex++) {
        SMDestinationEndpoint *endpoint;
        SMMessageParser *parser;

        endpoint = [destinationEndpoints objectAtIndex:destinationEndpointIndex];
        parser = [self newParserWithOriginatingEndpoint:endpoint];
        [self addEndpointToMapTable:endpoint withParser:parser];
    }

    return self;
}

- (void)dealloc;
{
    [self setIsActive:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [inputStreamSource release];
    inputStreamSource = nil;

    NSFreeMapTable(endpointToParserMapTable);
    endpointToParserMapTable = NULL;

    [super dealloc];
}

//
// SMInputStream subclass
//

- (NSArray *)parsers;
{
    if (endpointToParserMapTable)
        return NSAllMapTableValues(endpointToParserMapTable);
    else
        return nil;
}

- (SMMessageParser *)parserForSourceConnectionRefCon:(void *)refCon;
{
    // In our case, the "refCon" is really a destination endpoint
    if (endpointToParserMapTable)
        return NSMapGet(endpointToParserMapTable, refCon);
    else
        return nil;
}

- (NSArray *)inputSources;
{
    return [NSArray arrayWithObject:inputStreamSource];
    // TODO it would be nice to be able to spy on endpoints selectively, not just all of them at once...
    // we would need to return an object for each destination endpoint here, and keep an array of the selected ones
}

- (NSArray *)selectedInputSources;
{
    if ([self isActive])
        return [self inputSources];
    else
        return [NSArray array];
}

- (void)setSelectedInputSources:(NSArray *)sources;
{
    [self setIsActive:(sources && [sources indexOfObjectIdenticalTo:inputStreamSource] != NSNotFound)];
}

//
// Other methods
//

- (BOOL)isActive;
{
    return (spyClient != NULL);
}

- (void)setIsActive:(BOOL)value;
{
    if (value && !spyClient) {
        spyClient = MIDISpyClientCreate(spyClientCallBack, self);
    } else if (!value && spyClient) {
        MIDISpyClientDispose(spyClient);
        spyClient = NULL;
    }

    OBASSERT([self isActive] == value);
}

@end


@implementation SMMSpyingInputStream (Private)

- (void)endpointAppeared:(NSNotification *)notification;
{
    SMEndpoint *endpoint;

    endpoint = [notification object];
    if ([endpoint isKindOfClass:[SMDestinationEndpoint class]]) {
        SMMessageParser *parser;

        parser = [self newParserWithOriginatingEndpoint:endpoint];
        [self addEndpointToMapTable:(SMDestinationEndpoint *)endpoint withParser:parser];
    }
}

- (void)endpointDisappeared:(NSNotification *)notification;
{
    SMDestinationEndpoint *endpoint;

    endpoint = [notification object];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:endpoint];

    NSMapRemove(endpointToParserMapTable, endpoint);
    // TODO and clean up anything which might be in progress?
}

- (void)endpointWasReplaced:(NSNotification *)notification;
{
    SMDestinationEndpoint *oldEndpoint, *newEndpoint;
    SMMessageParser *parser;

    oldEndpoint = [notification object];
    newEndpoint = [[notification userInfo] objectForKey:SMEndpointReplacement];

    parser = NSMapGet(endpointToParserMapTable, oldEndpoint);
    [parser retain];
    NSMapRemove(endpointToParserMapTable, oldEndpoint);
    [self addEndpointToMapTable:newEndpoint withParser:parser];
    [parser setOriginatingEndpoint:newEndpoint];
    [parser release];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:oldEndpoint];
}

- (void)addEndpointToMapTable:(SMDestinationEndpoint *)endpoint withParser:(SMMessageParser *)parser;
{
    NSMapInsert(endpointToParserMapTable, endpoint, parser);

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endpointDisappeared:) name:SMEndpointDisappearedNotification object:endpoint];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endpointWasReplaced:) name:SMEndpointWasReplacedNotification object:endpoint];    
}


static void spyClientCallBack(SInt32 endpointUniqueID, CFStringRef endpointName, const MIDIPacketList *packetList, void *refCon)
{
    SMDestinationEndpoint *destinationEndpoint;

    if ((destinationEndpoint = [SMDestinationEndpoint destinationEndpointWithUniqueID:endpointUniqueID])) {
        [[(SMMSpyingInputStream *)refCon parserForSourceConnectionRefCon:destinationEndpoint] takePacketList:packetList];
    }
}

@end
