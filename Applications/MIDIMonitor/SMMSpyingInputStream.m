//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMMSpyingInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface SMMSpyingInputStream (Private)

static void spyClientCallBack(SInt32 endpointUniqueID, CFStringRef endpointName, const MIDIPacketList *packetList, void *refCon);

@end


@implementation SMMSpyingInputStream

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    inputStreamSource = [[SMSimpleInputStreamSource alloc] initWithName:@"Spy on computer output"];
    // TODO better name

    parser = [[self newParser] retain];

    return self;
}

- (void)dealloc;
{
    [self setIsActive:NO];

    [inputStreamSource release];
    inputStreamSource = nil;

    [parser release];
    parser = nil;

    [super dealloc];
}

//
// SMInputStream subclass
//

- (NSArray *)parsers;
{
    return [NSArray arrayWithObject:parser];
}

- (SMMessageParser *)parserForSourceConnectionRefCon:(void *)refCon;
{
    // TODO this is never actually called in this subclass
    // refCon is ignored, since it only applies to connections created with MIDIPortConnectSource()
    return parser;
}

- (NSArray *)inputSources;
{
    return [NSArray arrayWithObject:inputStreamSource];
    // TODO it would be nice to be able to spy on endpoints selectively, not just all of them at once...
    // we would need to return an object for each destination endpoint here, and then filter as input comes in.
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

static void spyClientCallBack(SInt32 endpointUniqueID, CFStringRef endpointName, const MIDIPacketList *packetList, void *refCon)
{
    // TODO we need some way to pass down the endpoint information
    // TODO also, we need a separate parser for each endpoint... as it is now, this is just wrong.
    [((SMMSpyingInputStream *)refCon)->parser takePacketList:packetList];
}

@end
