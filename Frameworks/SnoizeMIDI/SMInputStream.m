//
//  SMInputStream.m
//  SnoizeMIDI
//
//  Created by krevis on Wed Nov 28 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMInputStream.h"

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMMessageParser.h"


@interface SMInputStream (Private)

static void midiReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);

@end


@implementation SMInputStream

DEFINE_NSSTRING(SMInputStreamReadingSysExNotification);
DEFINE_NSSTRING(SMInputStreamDoneReadingSysExNotification);


- (id)init;
{
    if (!(self = [super init]))
        return nil;

    parser = [[SMMessageParser alloc] init];
    [parser setDelegate:self];

    return self;
}

- (void)dealloc;
{
    [parser release];

    [super dealloc];
}

- (id<SMMessageDestination>)messageDestination;
{
    return [parser messageDestination];
}

- (void)setMessageDestination:(id<SMMessageDestination>)messageDestination;
{
    [parser setMessageDestination:messageDestination];
}

- (MIDIReadProc)midiReadProc;
{
    return midiReadProc;
}

//
// Parser delegate
//

- (void)parser:(SMMessageParser *)parser isReadingSysExData:(NSData *)sysExData;
{
    NSDictionary *userInfo;
    
    userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:[sysExData length]] forKey:@"length"];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamReadingSysExNotification object:self userInfo:userInfo];
}

- (void)parser:(SMMessageParser *)parser finishedReadingSysExData:(NSData *)sysExData validEOX:(BOOL)wasValid;
{
    NSDictionary *userInfo;
    
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:[sysExData length]], @"length", [NSNumber numberWithBool:wasValid], @"valid", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamDoneReadingSysExNotification object:self userInfo:userInfo];
}

@end


@implementation SMInputStream (Private)

static void midiReadProc(const MIDIPacketList *packetList, void *readProcRefCon, void *srcConnRefCon)
{
    // NOTE: This function is called in a separate, "high-priority" thread.

    SMInputStream *self = (SMInputStream *)readProcRefCon;
    NSAutoreleasePool *pool;

    pool = [[NSAutoreleasePool alloc] init];
    [self->parser takePacketList:packetList];
    [pool release];
}

@end
