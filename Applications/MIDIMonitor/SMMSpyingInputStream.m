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

    parser = [[self newParser] retain];
    spyClient = MIDISpyClientCreate(spyClientCallBack, self);
    
    return self;
}

- (void)dealloc;
{
    if (spyClient)
        MIDISpyClientDispose(spyClient);

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
    // refCon is ignored, since it only applies to connections created with MIDIPortConnectSource()
    return parser;
}

@end


@implementation SMMSpyingInputStream (Private)

static void spyClientCallBack(SInt32 endpointUniqueID, CFStringRef endpointName, const MIDIPacketList *packetList, void *refCon)
{
    // TODO we need some way to pass down the endpoint information
    [((SMMSpyingInputStream *)refCon)->parser takePacketList:packetList];
}

@end
