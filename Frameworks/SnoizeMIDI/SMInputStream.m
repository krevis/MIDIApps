//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMInputStream.h"

#include <mach/mach.h>
#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMMessage.h"
#import "SMMessageParser.h"
#import "SMSystemExclusiveMessage.h"
#import "SMUtilities.h"
#import "VirtualRingBuffer.h"


@interface SMInputStream (Private)

static void midiReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);
static void sendTrivialMachMessageToPort(CFMachPortRef port);
+ (void)runSecondaryMIDIThread:(id)ignoredObject;
static void ringBufferConsumerSignaled(CFMachPortRef port, void *msg, CFIndex size, void *info);
static void readPacketListsFromRingBuffer();

- (id <SMInputStreamSource>)findInputSourceWithName:(NSString *)desiredName uniqueID:(NSNumber *)desiredUniqueID;

@end


@implementation SMInputStream

NSString *SMInputStreamReadingSysExNotification = @"SMInputStreamReadingSysExNotification";
NSString *SMInputStreamDoneReadingSysExNotification = @"SMInputStreamDoneReadingSysExNotification";
NSString *SMInputStreamSelectedInputSourceDisappearedNotification = @"SMInputStreamSelectedInputSourceDisappearedNotification";
NSString *SMInputStreamSourceListChangedNotification = @"SMInputStreamSourceListChangedNotification";


+ (void)initialize
{
    SMInitialize;

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

// Static variables, initialized in +runSecondaryMIDIThread:
static VirtualRingBuffer *sRingBuffer = nil;
static CFMachPortRef sRingBufferSignalPort = NULL;

static void midiReadProc(const MIDIPacketList *packetList, void *readProcRefCon, void *srcConnRefCon)
{
    // NOTE: This function is called in a high-priority, time-constraint thread,
    // created for us by CoreMIDI.
    //
    // Because we're in a time-constraint thread, we should avoid allocating memory,
    // since the allocator uses a single app-wide lock. (If another low-priority thread holds
    // that lock, we'll have to wait for that thread to release it, which is priority inversion.)
    // So we use a nonblocking ring buffer to pass the incoming data to another thread,
    // which can block as much as it likes.
    // Unfortunately the ring buffer could potentially fill up, but we don't need
    // to make it very large to work OK at MIDI speeds. (A typical MIDI message coming in
    // is only 3 bytes or so.)
    // TODO test this theory with big sysex (or otherwise) messages sent from a virtual source,
    // and hence dumped out all at once... we need to receive all the data OK.
    // We might look at the current MIDI client implementation... what's the size of the shared mem buffer
    // between the MIDI server and client? 16K.
    // But of course we can't just rely on that; this readProc might be called many times (with a full 16k) before
    // the consumer thread could even get one chance to read anything.
    // Perhaps we should have a reasonable-size ring buffer, and then fall back to allocating entries on a queue
    // (which would potentially block, but at least nothing would get dropped).
    // How to signal the consumer that it should pull from the queue, though? some special value for one of the two refcons

    UInt32 packetListSize;
    UInt32 ringBufferWriteSize;
    void *writePointer;

    // We need to write two refCons, then the packet list
    packetListSize = SMPacketListSize(packetList);
    ringBufferWriteSize = 2 * sizeof(void *) + packetListSize;

    // Check if we have room to write into the ring buffer
    if ([sRingBuffer lengthAvailableToWriteReturningPointer:&writePointer] >= ringBufferWriteSize) {
        // Copy the two refCons into the ring buffer
        *(void **)writePointer = readProcRefCon;
        writePointer += sizeof(void *);
        *(void **)writePointer = srcConnRefCon;
        writePointer += sizeof(void *);
        // And also the packet list
        memcpy(writePointer, packetList, packetListSize);

        // And advance the write pointer
        [sRingBuffer didWriteLength:ringBufferWriteSize];

        // Now signal the reading thread so it wakes up and reads.
        // We must be careful not to do this in a way that might block.
        // Normally we would use a Mach semaphore and call semaphore_signal(); the reading thread would be waiting
        // in semaphore_wait().
        // However, we want the reading thread to be running a normal run loop, so higher-level code can use an
        // NSTimer if necessary. So, instead, we have a Mach port attached to the run loop in the reading thread,
        // and in this thread, we send a message to that port.
        // The port is set to have a queue of only one message, and we specify that we don't want to wait at all
        // when sending the message, so there is no way that this thread can block.
        // This idea is essentially stolen from the implementation of CFRunLoop.
        sendTrivialMachMessageToPort(sRingBufferSignalPort);
        
    } else {
        // We have no choice but to drop this packet list.
        // TODO rectify this
#if DEBUG
        NSLog(@"SMInputStream: ring buffer is too full to write packet list of size %d; dropping it", packetListSize);
#endif
    }
}

static void sendTrivialMachMessageToPort(CFMachPortRef port)
{
    mach_msg_header_t header;

    header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
    header.msgh_size = sizeof(mach_msg_header_t);
    header.msgh_remote_port = CFMachPortGetPort(port);
    header.msgh_local_port = MACH_PORT_NULL;
    header.msgh_id = 0;

    mach_msg(&header, MACH_SEND_MSG | MACH_SEND_TIMEOUT, header.msgh_size, 0, MACH_PORT_NULL, 0, MACH_PORT_NULL);    
}

+ (void)runSecondaryMIDIThread:(id)ignoredObject;
{
    NSAutoreleasePool *pool;

    pool = [[NSAutoreleasePool alloc] init];

    sRingBuffer = [(VirtualRingBuffer *)[VirtualRingBuffer alloc] initWithLength:4096];
    // TODO make a #define for ring buffer length

    sRingBufferSignalPort = CFMachPortCreate(kCFAllocatorDefault, ringBufferConsumerSignaled, NULL, NULL);
    if (!sRingBufferSignalPort)
        NSLog(@"CFMachPortCreate failed");
    else {
        // Set the port to only queue one incoming message
        mach_port_t port = CFMachPortGetPort(sRingBufferSignalPort);
        mach_port_limits_t limits;
        CFRunLoopSourceRef source;
        
        limits.mpl_qlimit = 1;
        mach_port_set_attributes(mach_task_self(), port, MACH_PORT_LIMITS_INFO, (mach_port_info_t)&limits, MACH_PORT_LIMITS_INFO_COUNT);

        // Get a run loop source for the port, and add it to the current run loop
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, sRingBufferSignalPort, 0);
        if (source) {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
            CFRelease(source);
        } else {
            NSLog(@"CFMachPortCreateRunLoopSource failed");
        }
    }
  
    [[NSRunLoop currentRunLoop] run];
    // TODO does this have an exit condition?

    [sRingBuffer release];
    sRingBuffer = nil;

    if (sRingBufferSignalPort)
        CFRelease(sRingBufferSignalPort);
    sRingBufferSignalPort = NULL;

    [pool release];
}

static void ringBufferConsumerSignaled(CFMachPortRef port, void *msg, CFIndex size, void *info)
{
    readPacketListsFromRingBuffer();
}

static void readPacketListsFromRingBuffer()
{
    // NOTE: This function is called in the secondary MIDI thread that we create

    // Check the size avail for reading.
    // If > 0, Should be at least 2*sizeof(refcon) + sizeof(UInt32) + offsetof(MIDIPacket, data) + 1 (one data byte).
    // If not, then the write thread must have screwed up.
    // If it is, then get the read ptr, read off the refcons, and pass it on (as we do below).
    // Then advance the read ptr.
    // (We could malloc a new packet list and copy into it, which would let us advance the ring buffer faster
    // and thus decrease the chance of overflowing it. But the extra allocation might hurt... especially since
    // the parser will likely allocate another object and copy the data again itself.)
    // TODO cleanup

    void *readPointer;

    while ([sRingBuffer lengthAvailableToReadReturningPointer:&readPointer] > 0) {
        UInt32 readLength = 0;
        void *readProcRefCon;
        void *srcConnRefCon;
        const MIDIPacketList *packetList;

        // Copy the two refCons from the ring buffer
        readProcRefCon = *(void **)readPointer;
        readPointer += sizeof(void *);
        readLength += sizeof(void *);
        srcConnRefCon = *(void **)readPointer;
        readPointer += sizeof(void *);
        readLength += sizeof(void *);

        // Now the packet list is at readPointer.
        packetList = (const MIDIPacketList *)readPointer;
        readLength += SMPacketListSize(packetList);

        // Now pass on the packet list to the appropriate stream and parser
        {
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            
            NS_DURING {
                SMInputStream *inputStream = (SMInputStream *)readProcRefCon;            
                [[inputStream parserForSourceConnectionRefCon:srcConnRefCon] takePacketList:packetList];
            } NS_HANDLER {
                // Ignore any exception raised
    #if DEBUG
                NSLog(@"Exception raised during MIDI parsing in secondary thread: %@", localException);
    #endif
            } NS_ENDHANDLER;
        
            [pool release];
        }

         // Finally, tell the ring buffer that we're done with this data
         [sRingBuffer didReadLength:readLength];
    }
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
