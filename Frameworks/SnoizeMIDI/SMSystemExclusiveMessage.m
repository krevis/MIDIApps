//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMSystemExclusiveMessage.h"

#import <AudioToolbox/MusicPlayer.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface SMSystemExclusiveMessage (Private)

static UInt32 readVariableLengthFieldFromSMF(const Byte **pPtr, const Byte *end);

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
    NSData *smfData;
    unsigned int smfDataLength;
    const Byte *p, *end;
    UInt32 chunkSize;
    NSMutableArray *messages;
    NSMutableData *readingSysexData = nil;

    messages = [NSMutableArray array];

    smfData = [NSData dataWithContentsOfFile:path];
    if (!smfData)
        goto done;

    smfDataLength = [smfData length];
    if (smfDataLength < 0x16)	// definitely too small
        goto done;

    p = [smfData bytes];
    end = p + smfDataLength;

    // Read the header chunk
    if (CFSwapInt32BigToHost(*(const UInt32 *)p) != 'MThd')
        goto done;
    p += 4;
    chunkSize = CFSwapInt32BigToHost(*(const UInt32 *)p);	// should be 6, but that could conceivably change, so don't hard-code it
    p += 4;
    p += chunkSize;
    if (p >= end)
        goto done;

    // Read track chunks
    while (p < end) {
        const Byte *trackChunkEnd;
        Byte runningStatusEventSize;

        if (end - p < 8)
            goto done;
        if (CFSwapInt32BigToHost(*(const UInt32 *)p) != 'MTrk')
            goto done;
        p += 4;
        chunkSize = CFSwapInt32BigToHost(*(const UInt32 *)p);
        p += 4;
        trackChunkEnd = p + chunkSize;
        if (trackChunkEnd > end)
            goto done;	// this track is supposedly bigger than the file is... unlikely.
        
        // Read each event in the track
        runningStatusEventSize = 0;
        while (p < trackChunkEnd) {
            Byte eventType;
            Byte topNibble;

            // Get the delta-time for this event. We don't really care what it is.
            (void)readVariableLengthFieldFromSMF(&p, trackChunkEnd);
            if (p >= trackChunkEnd)
                goto done;

            eventType = *p++;
            if (p >= trackChunkEnd)
                goto done;
            
            topNibble = (eventType & 0xF0) >> 4;
            if (topNibble < 0x8) {
                if (runningStatusEventSize) {
                    // This event omits the event type byte; "running status" indicates that we use the last encountered event type.
                    // We actually only remembered the offset that we need to skip. (We have already skipped over one byte.)
                    p += (runningStatusEventSize - 1);
                } else {
                    // Malformed file -- this shouldn't happen.
                    NSLog(@"Bad data in standard MIDI file: at offset 0x%08x, got byte 0x%02x when we expected >= 0x80", p - 1 - (const Byte*)[smfData bytes], eventType);
                    goto done;
                }

            } else if (topNibble < 0xF) {
                // This is a channel event. There may be 1 or 2 more bytes of data, which we can skip.
                // Also, the file may use "running status" after this point, so remember how big these events are.
                if (topNibble == 0x0C || topNibble == 0x0D)	// program change or channel aftertouch
                    runningStatusEventSize = 1;
                else
                    runningStatusEventSize = 2;
                p += runningStatusEventSize;

            } else {
                // This is a meta event or sysex event.
                runningStatusEventSize = 0;
                if (eventType == 0xFF) {
                    UInt32 eventSize;
                    
                    // The next byte is a meta event type. Skip it.
                    p++;
                    if (p >= trackChunkEnd)
                        goto done;

                    // Now read a variable-length value, which is the number of bytes in this event.
                    eventSize = readVariableLengthFieldFromSMF(&p, trackChunkEnd);
                    if (p > trackChunkEnd)	// Hitting the end of the track chunk is OK here
                        goto done;

                    // And skip the rest of the event.
                    p += eventSize;

                } else if (eventType == 0xF0 || eventType == 0xF7) {
                    // Sysex event (start or continuation).
                    UInt32 sysexSize;
                    const Byte *sysexEnd;
                    BOOL isCompleteMessage;

                    // Read a variable-length value, which is the number of bytes in this event.
                    sysexSize = readVariableLengthFieldFromSMF(&p, trackChunkEnd);
                    if (p >= trackChunkEnd)
                        goto done;

                    sysexEnd = p + sysexSize;
                    if (sysexEnd > trackChunkEnd)
                        goto done;

                    // Does the sysex data have a trailing 0xF7? If so, then this message is complete.
                    // If not, then we expect one or more sysex continuation events later in this track.
                    isCompleteMessage = (*(sysexEnd - 1) == 0xF7);
                    if (isCompleteMessage)
                        sysexSize--;	// Don't include the trailing 0xF7

                    if (eventType == 0xF0) {
                        // Starting a sysex message.
                        readingSysexData = [NSMutableData dataWithBytes:p length:sysexSize];
                    } else {
                        // Continuing a sysex message.
                        if (readingSysexData) {
                            [readingSysexData appendBytes:p length:sysexSize];
                        } else {
                            // We should have had a starting-sysex event earlier, but we didn't. So just skip this stuff.
                            // (It is using the 0xF7 as an 'escape' for other random MIDI data.)
                        }
                    }
                    
                    if (isCompleteMessage && readingSysexData) {
                        SMSystemExclusiveMessage *message;

                        message = [SMSystemExclusiveMessage systemExclusiveMessageWithTimeStamp:0 data:readingSysexData];
                        [messages addObject:message];
                        readingSysexData = nil;
                    }

                    p = sysexEnd;

                } else {
                    // Malformed file -- this shouldn't happen.
                    NSLog(@"Bad data in standard MIDI file: got byte 0x%02x which is an unknown event type", eventType);
                    goto done;
                }
            }
        }
    }
    
done:
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
    // TODO change this to just return some data instead of writing to file -- higher levels can deal with the file stuff
    OSStatus status;
    MusicSequence sequence;
    BOOL success = NO;
//    NSData *smfData = nil;
    FSSpec fsSpec;

    // TODO This basically doesn't work at all, because MusicSequenceSaveSMF() is completely broken on 10.1.
    // Reported as bug #2840253; supposedly fixed on 10.2 (testing it).

    {
        FSRef fsRef;
        Boolean isDirectory;
        FSCatalogInfo fsCatalogInfo;
        Str255 pascalFileName;

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
    }        
    
    status = NewMusicSequence(&sequence);
    if (status == noErr) {
        MusicTrack track;
        
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

                status = MusicTrackNewMIDIRawDataEvent(track, eventTimeStamp, midiRawData);
                if (status != noErr) {
                    NSLog(@"MusicTrackNewMIDIRawDataEvent: error %ld", status);
                    // TODO error out of this whole operation
                }

                free(midiRawData);
                eventTimeStamp += 1.0;
                    // TODO should be the approx. duration of this sysex data at the sequence's tempo
                    // unclear if this is in beats or seconds (probably beats)
                    // also add on some time between messages (say 150ms or more, or round up to next bar)
            }
            
/*            status = MusicSequenceSaveSMFData(sequence, (CFDataRef *)&smfData, 0);
            if (status != noErr)
                NSLog(@"MusicSequenceSaveSMFData returned err: %ld", status);

            if (smfData)
                NSLog(@"retain count of SMF data is originally %ld", [smfData retainCount]);
            [smfData retain]; */

            status = MusicSequenceSaveSMF(sequence, &fsSpec, 0);
            if (status != noErr)
                NSLog(@"MusicSequenceSaveSMF returned err: %ld", status);
        }

        DisposeMusicSequence(sequence);
    }

    /*
    if (smfData) {
        success = [smfData writeToFile:path atomically:YES];
        [smfData release];
    }
     */

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

UInt32 readVariableLengthFieldFromSMF(const Byte **pPtr, const Byte *end)
{
    const Byte *p = *pPtr;
    UInt32 value = 0;
    BOOL keepGoing = YES;

    while (p < end && keepGoing) {
        Byte byte;

        value <<= 7;

        byte = *p++;
        if (byte & 0x80)
            byte &= 0x7F;
        else
            keepGoing = NO;

        value += byte;
    }

    *pPtr = p;
    return value;
}


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
