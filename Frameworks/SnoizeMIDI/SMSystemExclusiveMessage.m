//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMSystemExclusiveMessage.h"

#import <AudioToolbox/MusicPlayer.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface SMSystemExclusiveMessage (Private)

+ (NSArray *)systemExclusiveMessagesInDataBuffer:(const Byte *)buffer withLength:(unsigned int)byteCount;
- (NSData *)dataByAddingStartByte:(NSData *)someData;

@end


@implementation SMSystemExclusiveMessage : SMMessage

+ (SMSystemExclusiveMessage *)systemExclusiveMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp data:(NSData *)aData
{
    SMSystemExclusiveMessage *message;
    
    message = [[[SMSystemExclusiveMessage alloc] initWithTimeStamp:aTimeStamp statusByte:0xF0] autorelease];
    [message setData:aData];

    return message;
}

+ (NSArray *)systemExclusiveMessagesInData:(NSData *)someData;
{
    return [self systemExclusiveMessagesInDataBuffer:[someData bytes] withLength:[someData length]];
}

+ (NSArray *)systemExclusiveMessagesInStandardMIDIFile:(NSString *)path;
{
    NSMutableArray *messages;
    FSRef fsRef;
    FSSpec fsSpec;
    OSStatus status;
    MusicSequence sequence;

    status = FSPathMakeRef([path fileSystemRepresentation], &fsRef, NULL);
    if (status != noErr)
        return nil;
    status = FSGetCatalogInfo(&fsRef, kFSCatInfoNone, NULL, NULL, &fsSpec, NULL);
    if (status != noErr)
        return nil;

    messages = [NSMutableArray array];

    status = NewMusicSequence(&sequence);
    if (status == noErr) {
        status = MusicSequenceLoadSMF(sequence, &fsSpec);
        if (status == noErr) {
            UInt32 trackCount, trackIndex;
            
            MusicSequenceGetTrackCount(sequence, &trackCount);
            for (trackIndex = 0; trackIndex < trackCount; trackIndex++) {
                MusicTrack track;
                MusicEventIterator iterator;
                Boolean hasNextEvent;
    
                MusicSequenceGetIndTrack(sequence, trackIndex, &track);        
                NewMusicEventIterator(track, &iterator);

                while (MusicEventIteratorHasNextEvent(iterator, &hasNextEvent), hasNextEvent) {
                    MusicEventType eventType;
                    UInt32 eventDataSize;
                    Byte *eventData;

                    MusicEventIteratorGetEventInfo(iterator, NULL, &eventType, (void **)&eventData, &eventDataSize);
                    if (eventType == kMusicEventType_MIDIRawData) {
                        NSArray *eventMessages;

                        eventMessages = [self systemExclusiveMessagesInDataBuffer:eventData withLength:eventDataSize];
                        if (eventMessages)
                            [messages addObjectsFromArray:eventMessages];
                    }

                    MusicEventIteratorNextEvent(iterator);
                }

                DisposeMusicEventIterator(iterator);
            }
        }

        // Dispose of all the tracks in the sequence. We shouldn't have to do this (DisposeMusicSequence should do it)
        // but apparently we have to. This works around bug #2848166.
        {
            UInt32 trackCount;

            if (MusicSequenceGetTrackCount(sequence, &trackCount) == noErr) {
                while (trackCount--) {
                    MusicTrack track;
    
                    if (MusicSequenceGetIndTrack(sequence, trackCount, &track) == noErr)
                        MusicSequenceDisposeTrack(sequence, track);
                }
            }
        }

        DisposeMusicSequence(sequence);
    }
    
    return messages;    
}

+ (NSData *)dataForSystemExclusiveMessages:(NSArray *)messages;
#if SLOW_WAY
{
    unsigned int messageCount, messageIndex;
    NSData *allData = nil;

    messageCount = [messages count];
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        NSData *messageData;

        messageData = [[messages objectAtIndex:messageIndex] fullMessageData];
        if (allData)
            allData = [allData dataByAppendingData:messageData];
        else
            allData = messageData;
    }

    return allData;
}
#else
{
    // This is about a million times faster than the naive implementation above (which can take *minutes* for about 4500 60-byte messages).
    // Calculate the size of the total data buffer first and only do one malloc, instead of continually appending data (which causes lots of mallocs).
    unsigned int messageCount, messageIndex;
    unsigned int totalDataLength;
    NSMutableData *totalData;
    Byte *totalBytes, *p;

    messageCount = [messages count];
    if (messageCount == 0)
        return nil;
    else if (messageCount == 1)
        return [[messages objectAtIndex:0] fullMessageData];
    
    totalDataLength = 0;
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++)
        totalDataLength += ([[[messages objectAtIndex:messageIndex] data] length] + 2);

    totalData = [NSMutableData dataWithLength:totalDataLength];
    totalBytes = [totalData mutableBytes];

    p = totalBytes;
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMSystemExclusiveMessage *message;
        NSData *messageData;
        unsigned int messageDataLength;

        message = [messages objectAtIndex:messageIndex];
        messageData = [message data];
        messageDataLength = [messageData length];

        *p++ = 0xF0;
        memcpy(p, [messageData bytes], messageDataLength);
        p += messageDataLength;
        *p++ = 0xF7;
    }

    return totalData;    
}
#endif

+ (BOOL)writeSystemExclusiveMessages:(NSArray *)messages toStandardMIDIFile:(NSString *)path;
{
    FSRef fsRef;
    Boolean isDirectory;
    FSSpec fsSpec;
    FSCatalogInfo fsCatalogInfo;
    Str255 pascalFileName;
    OSStatus status;
    MusicSequence sequence;
    BOOL success = NO;

    // TODO This basically doesn't work at all, because MusicSequenceSaveSMF() is completely broken.
    // Reported as bug #2840253.
    
    NSLog(@"getting FSRef for path: %@", [path stringByDeletingLastPathComponent]);
    status = FSPathMakeRef([[path stringByDeletingLastPathComponent] fileSystemRepresentation], &fsRef, &isDirectory);
    if (status != noErr || !isDirectory)
        return NO;

    status = FSGetCatalogInfo(&fsRef, kFSCatInfoNodeID, &fsCatalogInfo, NULL, &fsSpec, NULL);
    if (status != noErr)
        return NO;
    {
        CFStringRef stringName;

        NSLog(@"fsSpec has vRefNum %d, parID %d", (int)fsSpec.vRefNum, fsSpec.parID);
        stringName = CFStringCreateWithPascalString(kCFAllocatorDefault, fsSpec.name, kCFStringEncodingUTF8);
        NSLog(@"name: %@", stringName);
        NSLog(@"catalog info has node id: %d", fsCatalogInfo.nodeID);
    }
//    NSLog(@"fsSpec has vRefNum %h, parID %d, name %@", fsSpec.vRefNum, fsSpec.parID, CFStringCreateWithPascalString(kCFAllocatorDefault, fsSpec.name, kCFStringEncodingMacRoman));

    NSLog(@"going on with file: %@", [path lastPathComponent]);
    if (!CFStringGetPascalString((CFStringRef)[path lastPathComponent], pascalFileName, 256, kCFStringEncodingUTF8))
        return NO;
    status = FSMakeFSSpec(fsSpec.vRefNum, fsCatalogInfo.nodeID, pascalFileName, &fsSpec);
    if (status != fnfErr)
        return NO;
    {
        CFStringRef stringName;

        NSLog(@"fsSpec has vRefNum %d, parID %d", (int)fsSpec.vRefNum, fsSpec.parID);
        stringName = CFStringCreateWithPascalString(kCFAllocatorDefault, fsSpec.name, kCFStringEncodingUTF8);
        NSLog(@"name: %@", stringName);
    }
    //    NSLog(@"fsSpec has vRefNum %h, parID %d, name %@", fsSpec.vRefNum, fsSpec.parID, CFStringCreateWithPascalString(NULL, fsSpec.name, kCFStringEncodingMacRoman));
    
    // TODO maybe support an "atomically", or overwrite the file, or something

    status = NewMusicSequence(&sequence);
    if (status == noErr) {
        MusicTrack track;

        {
            UInt32 trackCount;

            status = MusicSequenceGetTrackCount(sequence, &trackCount);
            NSLog(@"status: %ld track count: %lu", status, trackCount);
        }
        
        status = MusicSequenceNewTrack(sequence, &track);
        if (status == noErr) {
            unsigned int messageIndex, messageCount;
            MusicTimeStamp eventTimeStamp = 0;

            messageCount = [messages count];
            for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
                NSData *messageData;
                unsigned int messageDataLength;
                MIDIRawData *midiRawData;

                messageData = [[messages objectAtIndex:messageIndex] fullMessageData];
                messageDataLength = [messageData length];
                midiRawData = malloc(sizeof(UInt32) + messageDataLength);
                midiRawData->length = messageDataLength;
                [messageData getBytes:midiRawData->data];

                NSLog(@"adding raw data event with length: %u", messageDataLength);
                
                status = MusicTrackNewMIDIRawDataEvent(track, eventTimeStamp, midiRawData);
                if (status != noErr)
                    NSLog(@"MusicTrackNewMIDIRawDataEvent: error %ld", status);

                free(midiRawData);
                eventTimeStamp += 1.0; // TODO should be the approx. duration of this sysex data at the sequence's tempo
                    // unclear if this is in beats or seconds (probably beats)
                    // also add on some time between messages (say 150ms or more, or round up to next bar)
            }

            // TODO Apparently we need to create the file first, then save to it... seems like a bug.
            status = FSpCreate(&fsSpec, '????', '????', smSystemScript);
            if (status != noErr) {
                NSLog(@"FSpCreate failed: %ld", status);
            }
            
            status = MusicSequenceSaveSMF(sequence, &fsSpec, 0);
            if (status == noErr)
                success = YES;
        }

        DisposeMusicSequence(sequence);
    }

    return success;
}


- (id)initWithTimeStamp:(MIDITimeStamp)aTimeStamp statusByte:(Byte)aStatusByte
{
    if (!(self = [super initWithTimeStamp:aTimeStamp statusByte:aStatusByte]))
        return nil;

    flags.wasReceivedWithEOX = YES;
    
    return self;
}

- (void)dealloc
{
    [data release];
    [cachedDataWithEOX release];

    [super dealloc];
}

//
// SMMessage overrides
//

- (id)copyWithZone:(NSZone *)zone;
{
    SMSystemExclusiveMessage *newMessage;
    
    newMessage = [super copyWithZone:zone];
    [newMessage setData:data];

    return newMessage;
}

- (SMMessageType)messageType;
{
    return SMMessageTypeSystemExclusive;
}

- (unsigned int)otherDataLength
{
    return [data length] + 1;  // Add a byte for the EOX at the end
}

- (const Byte *)otherDataBuffer;
{
    return [[self otherData] bytes];    
}

- (NSData *)otherData
{
    if (!cachedDataWithEOX) {
        unsigned int length;
        Byte *bytes;
    
        length = [data length];
        cachedDataWithEOX = [[NSMutableData alloc] initWithLength:length + 1];
        bytes = [cachedDataWithEOX mutableBytes];
        [data getBytes:bytes];
        *(bytes + length) = 0xF7;
    }

    return cachedDataWithEOX;
}

- (NSString *)typeForDisplay;
{
    return NSLocalizedStringFromTableInBundle(@"SysEx", @"SnoizeMIDI", [self bundle], "displayed type of System Exclusive event");
}

- (NSString *)dataForDisplay;
{
    NSString *manufacturerName, *lengthString;

    manufacturerName = [self manufacturerName];
    lengthString = [self sizeForDisplay];

    if (manufacturerName)
        return [[manufacturerName stringByAppendingString:@"\t"] stringByAppendingString:lengthString];
    else
        return lengthString;
}

//
// Additional API
//

- (NSData *)data;
{
    return data;
}

- (void)setData:(NSData *)newData;
{
    if (data != newData) {
        [data release];
        data = [newData retain];
        
        [cachedDataWithEOX release];
        cachedDataWithEOX = nil;
    }
}

- (BOOL)wasReceivedWithEOX;
{
    return flags.wasReceivedWithEOX;
}

- (void)setWasReceivedWithEOX:(BOOL)value;
{
    flags.wasReceivedWithEOX = value;
}

- (NSData *)receivedData;
{
    if ([self wasReceivedWithEOX])
        return [self otherData];	// With EOX
    else
        return [self data];		// Without EOX
}

- (unsigned int)receivedDataLength;
{
    return [[self receivedData] length];
}

- (NSData *)receivedDataWithStartByte;
{
    return [self dataByAddingStartByte:[self receivedData]];
}

- (unsigned int)receivedDataWithStartByteLength;
{
    return [self receivedDataLength] + 1;
}

- (NSData *)fullMessageData;
{
    return [self dataByAddingStartByte:[self otherData]];
}

- (unsigned int)fullMessageDataLength;
{
    return [self otherDataLength] + 1;
}

- (NSData *)manufacturerIdentifier;
{
    unsigned int length;
    Byte *buffer;

    // If we have no data, we can't figure out a manufacturer ID.
    if (!data || ((length = [data length]) == 0)) 
        return nil;

    // If the first byte is not 0, the manufacturer ID is one byte long. Otherwise, return a three-byte value (if possible).
    buffer = (Byte *)[data bytes];
    if (*buffer != 0)
        return [NSData dataWithBytes:buffer length:1];
    else if (length >= 3)
        return [NSData dataWithBytes:buffer length:3];
    else
        return nil;
}

- (NSString *)manufacturerName;
{
    NSData *manufacturerIdentifier;

    if ((manufacturerIdentifier = [self manufacturerIdentifier]))
        return [SMMessage nameForManufacturerIdentifier:manufacturerIdentifier];
    else
        return nil;
}

- (NSString *)sizeForDisplay;
{
    return [NSString stringWithFormat:
        NSLocalizedStringFromTableInBundle(@"%@ bytes", @"SnoizeMIDI", [self bundle], "SysEx length format string"),
        [SMMessage formatLength:[self receivedDataWithStartByteLength]]];
}

@end


@implementation SMSystemExclusiveMessage (Private)

+ (NSArray *)systemExclusiveMessagesInDataBuffer:(const Byte *)buffer withLength:(unsigned int)byteCount;
{
    // Scan through someData and make messages out of it.
    // Messages must start with 0xF0.  Messages may end in any byte > 0x7F.

    NSMutableArray *messages;
    unsigned int byteIndex;
    const Byte *p;
    NSRange range;
    BOOL inMessage;

    messages = [NSMutableArray array];

    inMessage = NO;
    for (p=buffer, byteIndex = 0; byteIndex < byteCount; byteIndex++, p++) {
        if (inMessage && (*p & 0x80)) {
            range.length = byteIndex - range.location;
            if (range.length > 0) {
                NSData *sysexData;

                sysexData = [NSData dataWithBytes:buffer+range.location length:range.length];
                [messages addObject:[self systemExclusiveMessageWithTimeStamp:0 data:sysexData]];
            }
            inMessage = NO;
        }

        if (*p == 0xF0) {
            inMessage = YES;
            range.location = byteIndex + 1;
        }
    }
    if (inMessage) {
        range.length = byteIndex - range.location;
        if (range.length > 0) {
            NSData *sysexData;

            sysexData = [NSData dataWithBytes:buffer+range.location length:range.length];
            [messages addObject:[self systemExclusiveMessageWithTimeStamp:0 data:sysexData]];
        }
    }

    return messages;
}

- (NSData *)dataByAddingStartByte:(NSData *)someData;
{
    unsigned int length;
    NSMutableData *dataWithStartByte;
    Byte *bytes;

    length = [someData length];
    dataWithStartByte = [NSMutableData dataWithLength:1 + length];
    bytes = [dataWithStartByte mutableBytes];

    *bytes = 0xF0;
    [someData getBytes:bytes+1];

    return dataWithStartByte;
}

@end
