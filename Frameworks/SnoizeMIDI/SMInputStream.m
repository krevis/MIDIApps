//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMMessage.h"
#import "SMMessageParser.h"
#import "SMSystemExclusiveMessage.h"
#import "MessageQueue.h"


@interface SMInputStream (Private)

static void midiReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);
+ (void)runSecondaryMIDIThread:(id)ignoredObject;
static void receivePendingPacketList(CFTypeRef objectFromQueue, void *refCon);

- (id <SMInputStreamSource>)findInputSourceWithName:(NSString *)desiredName uniqueID:(NSNumber *)desiredUniqueID;

@end


@implementation SMInputStream

NSString *SMInputStreamReadingSysExNotification = @"SMInputStreamReadingSysExNotification";
NSString *SMInputStreamDoneReadingSysExNotification = @"SMInputStreamDoneReadingSysExNotification";
NSString *SMInputStreamSelectedInputSourceDisappearedNotification = @"SMInputStreamSelectedInputSourceDisappearedNotification";
NSString *SMInputStreamSourceListChangedNotification = @"SMInputStreamSourceListChangedNotification";


+ (void)didLoad
{
    [NSThread detachNewThreadSelector:@selector(runSecondaryMIDIThread:) toTarget:self withObject:nil];    
}

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    sysExTimeOut = 1.0;
    
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

- (NSTimeInterval)sysExTimeOut;
{
    return sysExTimeOut;
}

- (void)setSysExTimeOut:(NSTimeInterval)value;
{
    NSArray *parsers;
    unsigned int parserIndex;

    if (sysExTimeOut == value)
        return;

    sysExTimeOut = value;

    parsers = [self parsers];
    parserIndex = [parsers count];
    while (parserIndex--)
        [[parsers objectAtIndex:parserIndex] setSysExTimeOut:sysExTimeOut];
}

- (void)cancelReceivingSysExMessage;
{
    [[self parsers] makeObjectsPerformSelector:@selector(cancelReceivingSysExMessage)];
}

- (id)persistentSettings;
{
    NSSet *selectedInputSources;
    unsigned int sourcesCount;
    NSEnumerator *sourceEnumerator;
    id <SMInputStreamSource> source;
    NSMutableArray *persistentSettings;

    selectedInputSources = [self selectedInputSources];
    sourcesCount = [selectedInputSources count];
    if (sourcesCount == 0)
        return nil;
    persistentSettings = [NSMutableArray arrayWithCapacity:sourcesCount];

    sourceEnumerator = [selectedInputSources objectEnumerator];
    while ((source = [sourceEnumerator nextObject])) {
        NSMutableDictionary *dict;
        id object;

        dict = [NSMutableDictionary dictionary];
        if ((object = [source inputStreamSourceUniqueID]))
            [dict setObject:object forKey:@"uniqueID"];
        if ((object = [source inputStreamSourceName]))
            [dict setObject:object forKey:@"name"];

        if ([dict count] > 0)
            [persistentSettings addObject:dict];
    }
    
    return persistentSettings;
}

- (NSArray *)takePersistentSettings:(id)settings;
{
    // If any endpoints couldn't be found, their names are returned
    NSArray *settingsArray = (NSArray *)settings;
    unsigned int settingsCount, settingsIndex;
    NSMutableSet *newInputSources;
    NSMutableArray *missingNames = nil;

    settingsCount = [settingsArray count];
    newInputSources = [NSMutableSet setWithCapacity:settingsCount];
    for (settingsIndex = 0; settingsIndex < settingsCount; settingsIndex++) {
        NSDictionary *dict;
        NSString *name;
        NSNumber *uniqueID;
        id <SMInputStreamSource> source;

        dict = [settingsArray objectAtIndex:settingsIndex];
        name = [dict objectForKey:@"name"];
        uniqueID = [dict objectForKey:@"uniqueID"];
        if ((source = [self findInputSourceWithName:name uniqueID:uniqueID])) {
            [newInputSources addObject:source];
        } else {
            if (!name)
                name = NSLocalizedStringFromTableInBundle(@"Unknown", @"SnoizeMIDI", [self bundle], "name of missing endpoint if not specified in document");
            if (!missingNames)
                missingNames = [NSMutableArray array];
            [missingNames addObject:name];
        }
    }

    [self setSelectedInputSources:newInputSources];

    return missingNames;
}

//
// For use by subclasses only
//

- (MIDIReadProc)midiReadProc;
{
    return midiReadProc;
}

- (SMMessageParser *)newParserWithOriginatingEndpoint:(SMEndpoint *)originatingEndpoint;
{
    SMMessageParser *parser;

    parser = [[[SMMessageParser alloc] init] autorelease];
    [parser setDelegate:self];
    [parser setSysExTimeOut:sysExTimeOut];
    [parser setOriginatingEndpoint:originatingEndpoint];

    return parser;
}

- (void)postSelectedInputStreamSourceDisappearedNotification:(id<SMInputStreamSource>)source;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamSelectedInputSourceDisappearedNotification object:self userInfo:[NSDictionary dictionaryWithObject:source forKey:@"source"]];
}

- (void)postSourceListChangedNotification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamSourceListChangedNotification object:self];
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

- (id<SMInputStreamSource>)streamSourceForParser:(SMMessageParser *)parser;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (NSArray *)inputSources;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (NSSet *)selectedInputSources;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void)setSelectedInputSources:(NSSet *)sources;
{
    OBRequestConcreteImplementation(self, _cmd);
    return;
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

    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInt:length], @"length",
        [self streamSourceForParser:parser], @"source", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamReadingSysExNotification object:self userInfo:userInfo];
}

- (void)parser:(SMMessageParser *)parser finishedReadingSysExMessage:(SMSystemExclusiveMessage *)message;
{
    NSDictionary *userInfo;
    
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInt:1 + [[message receivedData] length]], @"length",
        [NSNumber numberWithBool:[message wasReceivedWithEOX]], @"valid",
        [self streamSourceForParser:parser], @"source", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamDoneReadingSysExNotification object:self userInfo:userInfo];
}

@end


@implementation SMInputStream (Private)

typedef struct PendingPacketList {
    void *readProcRefCon;
    void *srcConnRefCon;
    MIDIPacketList packetList;
} PendingPacketList;

static void midiReadProc(const MIDIPacketList *packetList, void *readProcRefCon, void *srcConnRefCon)
{
    // NOTE: This function is called in a separate, "high-priority" thread.
    //
    // NOTE: We used to just do this:
    //
    // SMInputStream *self = (SMInputStream *)readProcRefCon;
    // NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    // [[self parserForSourceConnectionRefCon:srcConnRefCon] takePacketList:packetList];
    // [pool release];
    //
    // However, as of Mac OS X 10.2.2, the CoreMIDI receive thread is no longer run using a run loop.
    // This violates some assumptions that we made in SMMessageParser regarding the sysex timeout;
    // we want the timer to fire in the same thread that MIDI messages normally come from, but without
    // the run loop that's impossible.
    //
    // The only way to get the old behavior back is to hand off the MIDI packets to another thread
    // of our own creation, in which they are processed as they were before. Fortunately this is not
    // difficult, especially with the MessageQueue that I had already written for SnoizeMIDISpy.

    UInt32 packetListSize;
    const MIDIPacket *packet;
    UInt32 i;
    NSData *data;
    PendingPacketList *pendingPacketList;

    // Find the size of the whole packet list
    packetListSize = sizeof(UInt32);	// numPackets
    packet = &packetList->packet[0];
    for (i = 0; i < packetList->numPackets; i++) {
        packetListSize += offsetof(MIDIPacket, data) + packet->length;
        packet = MIDIPacketNext(packet);
    }

    // Copy the packet list and other arguments into a new PendingPacketList (in an NSData)
    data = [[NSMutableData alloc] initWithLength:(offsetof(PendingPacketList, packetList) + packetListSize)];
    pendingPacketList = (PendingPacketList *)[data bytes];
    pendingPacketList->readProcRefCon = readProcRefCon;
    pendingPacketList->srcConnRefCon = srcConnRefCon;
    memcpy(&pendingPacketList->packetList, packetList, packetListSize);

    // Queue the data; receiveFromMessageQueue() will be called in the secondary MIDI thread.
    AddToMessageQueue((CFDataRef)data);
    
    [data release];
}

+ (void)runSecondaryMIDIThread:(id)ignoredObject;
{
    NSAutoreleasePool *pool;

    pool = [[NSAutoreleasePool alloc] init];

    CreateMessageQueue(receivePendingPacketList, NULL);

    [[NSRunLoop currentRunLoop] run];
    // Runs until DestroyMessageQueue() is called

    [pool release];
}

static void receivePendingPacketList(CFTypeRef objectFromQueue, void *refCon)
{
    // NOTE: This function is called in the secondary MIDI thread that we create

    NSAutoreleasePool *pool;
    NSData *data = (NSData *)objectFromQueue;
    PendingPacketList *pendingPacketList;
    SMInputStream *inputStream;

    pool = [[NSAutoreleasePool alloc] init];

    pendingPacketList = (PendingPacketList *)[data bytes];
    inputStream = (SMInputStream *)pendingPacketList->readProcRefCon;
    NS_DURING {
        [[inputStream parserForSourceConnectionRefCon:pendingPacketList->srcConnRefCon] takePacketList:&pendingPacketList->packetList];
    } NS_HANDLER {
        // Ignore any exceptions raised
#if DEBUG
        NSLog(@"Exception raised during MIDI parsing in secondary thread: %@", localException);
#endif
    } NS_ENDHANDLER;

    [pool release];
}

- (id <SMInputStreamSource>)findInputSourceWithName:(NSString *)desiredName uniqueID:(NSNumber *)desiredUniqueID;
{
    // Find the input source with the desired unique ID. If there are no matches by uniqueID, return the first source whose name matches.
    // Otherwise, return nil.

    NSArray *inputSources;
    unsigned int inputSourceCount, inputSourceIndex;
    id <SMInputStreamSource> sourceWithMatchingName = nil;

    inputSources = [self inputSources];
    inputSourceCount = [inputSources count];
    for (inputSourceIndex = 0; inputSourceIndex < inputSourceCount; inputSourceIndex++) {
        id <SMInputStreamSource> source;

        source = [inputSources objectAtIndex:inputSourceIndex];
        if ([[source inputStreamSourceUniqueID] isEqual:desiredUniqueID])
            return source;
        else if (!sourceWithMatchingName && [[source inputStreamSourceName] isEqualToString:desiredName])
            sourceWithMatchingName = source;
    }

    return sourceWithMatchingName;
}

@end
