#import "SMInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMMessage.h"
#import "SMMessageParser.h"
#import "SMSystemExclusiveMessage.h"


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

    //    parser = [[SMMessageParser alloc] init];
    //    [parser setDelegate:self];

    return self;
}

- (void)dealloc;
{
    [super dealloc];
}

- (id<SMMessageDestination>)messageDestination;
{
    return nonretainedMessageDestination;
}

- (void)setMessageDestination:(id<SMMessageDestination>)messageDestination;
{
    nonretainedMessageDestination = messageDestination;
}

- (BOOL)cancelReceivingSysExMessage;
{
    [[self parsers] makeObjectsPerformSelector:@selector(cancelReceivingSysExMessage)];
    // TODO is the return value really used anywhere?  (need to AND or OR the results together?)
    return YES;
}

- (MIDIReadProc)midiReadProc;
{
    return midiReadProc;
}

//
// For subclasses to implement
//

- (NSArray *)parsers;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (SMMessageParser *)parserForSourceConnectionRefCon:(void *)refCon;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

//
// Parser delegate
//

- (void)parser:(SMMessageParser *)parser didReadMessages:(NSArray *)messages;
{
    [nonretainedMessageDestination takeMIDIMessages:messages];
}

- (void)parser:(SMMessageParser *)parser isReadingSysExWithLength:(unsigned int)length;
{
    NSDictionary *userInfo;
    
    userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:length] forKey:@"length"];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamReadingSysExNotification object:self userInfo:userInfo];
        // TODO There could be multiple sysex messages being read simultaneously (from different sources), but this notification gives no way to distinguish between them.
}

- (void)parser:(SMMessageParser *)parser finishedReadingSysExMessage:(SMSystemExclusiveMessage *)message;
{
    NSDictionary *userInfo;
    
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInt:1 + [[message receivedData] length]], @"length",
        [NSNumber numberWithBool:[message wasReceivedWithEOX]], @"valid", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamDoneReadingSysExNotification object:self userInfo:userInfo];
        // TODO There could be multiple sysex messages being read simultaneously (from different sources), but this notification gives no way to distinguish between them.
}

@end


@implementation SMInputStream (Private)

static void midiReadProc(const MIDIPacketList *packetList, void *readProcRefCon, void *srcConnRefCon)
{
    // NOTE: This function is called in a separate, "high-priority" thread.

    SMInputStream *self = (SMInputStream *)readProcRefCon;
    NSAutoreleasePool *pool;

    pool = [[NSAutoreleasePool alloc] init];
    [[self parserForSourceConnectionRefCon:srcConnRefCon] takePacketList:packetList];
    [pool release];
}

@end
