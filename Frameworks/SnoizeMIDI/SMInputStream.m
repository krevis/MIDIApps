/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMInputStream.h"

#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMMessage.h"
#import "SMSystemExclusiveMessage.h"
#import "SMMessageParser.h"
#import "SMUtilities.h"


@interface SMInputStream (Private)

static void midiReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);

+ (void)takePendingPacketList:(NSData *)pendingPacketListData;

- (id <SMInputStreamSource>)findInputSourceWithName:(NSString *)desiredName uniqueID:(NSNumber *)desiredUniqueID;

@end


@implementation SMInputStream

NSString *SMInputStreamReadingSysExNotification = @"SMInputStreamReadingSysExNotification";
NSString *SMInputStreamDoneReadingSysExNotification = @"SMInputStreamDoneReadingSysExNotification";
NSString *SMInputStreamSelectedInputSourceDisappearedNotification = @"SMInputStreamSelectedInputSourceDisappearedNotification";
NSString *SMInputStreamSourceListChangedNotification = @"SMInputStreamSourceListChangedNotification";


- (id)init
{
    if (!(self = [super init]))
        return nil;

    sysExTimeOut = 1.0;

    // Default to main queue for taking pending read packets
    self.readQueue = dispatch_get_main_queue();

    return self;
}

- (dispatch_queue_t)readQueue
{
    return readQueue;
}

- (void)setReadQueue:(dispatch_queue_t)newReadQueue
{
    if (newReadQueue != readQueue)
    {
        if (readQueue)
            dispatch_release(readQueue);
        if (newReadQueue)
            dispatch_retain(newReadQueue);
        readQueue = newReadQueue;
    }
}

- (void)dealloc
{
    if (readQueue)
		dispatch_release(readQueue);

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
    NSUInteger parserIndex;

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
    NSUInteger sourcesCount;
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
    NSUInteger settingsCount, settingsIndex;
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
                name = NSLocalizedStringFromTableInBundle(@"Unknown", @"SnoizeMIDI", SMBundleForObject(self), "name of missing endpoint if not specified in document");
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

- (SMMessageParser *)createParserWithOriginatingEndpoint:(SMEndpoint *)originatingEndpoint;
{
    SMMessageParser *parser;

    parser = [[SMMessageParser alloc] init];
    [parser setDelegate:self];
    [parser setSysExTimeOut:sysExTimeOut];
    [parser setOriginatingEndpoint:originatingEndpoint];

    return [parser autorelease];
}

- (void)postSelectedInputStreamSourceDisappearedNotification:(id<SMInputStreamSource>)source;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamSelectedInputSourceDisappearedNotification object:self userInfo:[NSDictionary dictionaryWithObject:source forKey:@"source"]];
}

- (void)postSourceListChangedNotification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamSourceListChangedNotification object:self];
}

- (void)retainForIncomingMIDIWithSourceConnectionRefCon:(void *)refCon
{
    // NOTE: This is called on the CoreMIDI thread!
    //
    // Subclasses may override if they have other data, dependent on the given refCon,
    // which needs to be retained until the incoming MIDI is processed on the main thread.
    
    [self retain];
}

- (void)releaseForIncomingMIDIWithSourceConnectionRefCon:(void *)refCon
{
    // Normally called on the main thread, but could be called on other queues if set
    //
    // Subclasses may override if they have other data, dependent on the given refCon,
    // which needs to be retained until the incoming MIDI is processed on the main thread.
    
    [self release];
}


//
// For subclasses to implement
//

- (NSArray *)parsers;
{
    SMRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (SMMessageParser *)parserForSourceConnectionRefCon:(void *)refCon;
{
    SMRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id<SMInputStreamSource>)streamSourceForParser:(SMMessageParser *)parser;
{
    SMRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (NSArray *)inputSources;
{
    SMRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (NSSet *)selectedInputSources;
{
    SMRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void)setSelectedInputSources:(NSSet *)sources;
{
    SMRequestConcreteImplementation(self, _cmd);
    return;
}

//
// Parser delegate
//

- (void)parser:(SMMessageParser *)parser didReadMessages:(NSArray *)messages;
{
    [nonretainedMessageDestination takeMIDIMessages:messages];
}

- (void)parser:(SMMessageParser *)parser isReadingSysExWithLength:(NSUInteger)length;
{
    NSDictionary *userInfo;

    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInteger:length], @"length",
        [self streamSourceForParser:parser], @"source", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamReadingSysExNotification object:self userInfo:userInfo];
}

- (void)parser:(SMMessageParser *)parser finishedReadingSysExMessage:(SMSystemExclusiveMessage *)message;
{
    NSDictionary *userInfo;
    
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInteger:1 + [[message receivedData] length]], @"length",
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
    // NOTE: This function is called in a high-priority, time-constraint thread,
    // created for us by CoreMIDI.
    //
    // TODO Because we're in a time-constraint thread, we should avoid allocating memory,
    // since the allocator uses a single app-wide lock. (If another low-priority thread holds
    // that lock, we'll have to wait for that thread to release it, which is priority inversion.)
    // We're not even attempting to do that yet. Frankly, neither MIDI Monitor nor SysEx Librarian
    // need that level of performance.
    
    UInt32 packetListSize;
    const MIDIPacket *packet;
    UInt32 i;
    NSData *data;
    PendingPacketList *pendingPacketList;
        
    // NOTE: There is a little bit of a race condition here.
    // By the time the async block runs, the input stream may be gone or in a different state.
    // Make sure that the input stream retains itself, and anything that depend on the srcConnRefCon, during the
    // interval between now and the time that -takePendingPacketList: is done working.
    SMInputStream *inputStream = (SMInputStream *)readProcRefCon;
    [inputStream retainForIncomingMIDIWithSourceConnectionRefCon:srcConnRefCon];

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
    
    // Get off the CoreMIDI time-contrained thread.
    dispatch_async([inputStream readQueue], ^{
        @autoreleasepool
        {
            [SMInputStream takePendingPacketList:data];
        }
    });

    [data release];
}

+ (void)takePendingPacketList:(NSData *)pendingPacketListData
{
    @try
    {
        PendingPacketList *pendingPacketList = (PendingPacketList *)[pendingPacketListData bytes];

        // Starting with an input stream...
        SMInputStream *inputStream = (SMInputStream *)pendingPacketList->readProcRefCon;
        // find the parser that is associated with this particular connection...
        SMMessageParser *parser = [inputStream parserForSourceConnectionRefCon:pendingPacketList->srcConnRefCon];
        if (parser) {   // parser may be nil if input stream was disconnected from this source
            // and give it the packet list
            [parser takePacketList:&(pendingPacketList->packetList)];
        }

        // Now that we're done with the input stream and its ref con (whatever that is),
        // release them.
        [inputStream releaseForIncomingMIDIWithSourceConnectionRefCon:pendingPacketList->srcConnRefCon];
    }
    @catch (id localException)
    {
        // Ignore any exceptions raised
#if DEBUG
        NSLog(@"Exception raised during MIDI parsing: %@", localException);
#endif
    }
}

- (id <SMInputStreamSource>)findInputSourceWithName:(NSString *)desiredName uniqueID:(NSNumber *)desiredUniqueID;
{
    // Find the input source with the desired unique ID. If there are no matches by uniqueID, return the first source whose name matches.
    // Otherwise, return nil.

    NSArray *inputSources;
    NSUInteger inputSourceCount, inputSourceIndex;
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
