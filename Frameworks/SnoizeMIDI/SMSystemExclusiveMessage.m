/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMSystemExclusiveMessage.h"

#import "SMUtilities.h"



@interface SMSystemExclusiveMessage (Private)

+ (NSArray *)systemExclusiveMessagesInSMFData:(NSData *)smfData;
static UInt32 readVariableLengthFieldFromSMF(const Byte **pPtr, const Byte *end);

+ (NSData *)smfDataForSystemExclusiveMessages:(NSArray *)messages;
static Byte lengthOfVariableLengthFieldForValue(UInt32 value);
static void writeVariableLengthFieldIntoSMF(Byte **pPtr, const UInt32 value);

+ (NSArray *)systemExclusiveMessagesInDataBuffer:(const Byte *)buffer withLength:(NSUInteger)byteCount;

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

+ (NSData *)dataForSystemExclusiveMessages:(NSArray *)messages;
#if SLOW_WAY
{
    NSUInteger messageCount, messageIndex;
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
    // This is much faster than the naive implementation above, which can take *minutes* for about 4500 60-byte messages.
    // Calculate the size of the total data buffer first and only do one malloc, instead of continually appending data (which causes lots of mallocs).
    NSUInteger messageCount, messageIndex;
    NSUInteger totalDataLength;
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
        NSUInteger messageDataLength;

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

+ (NSArray *)systemExclusiveMessagesInStandardMIDIFile:(NSString *)path;
{
    NSData *smfData;

    smfData = [NSData dataWithContentsOfFile:path];
    if (smfData)
        return [self systemExclusiveMessagesInSMFData:smfData];
    else
        return [NSArray array];
}

+ (BOOL)writeSystemExclusiveMessages:(NSArray *)messages toStandardMIDIFile:(NSString *)path;
{
    NSData *smfData;

    smfData = [self smfDataForSystemExclusiveMessages:messages];
    if (smfData)
        return [smfData writeToFile:path atomically:YES];
    else
        return NO;
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
    [newMessage setWasReceivedWithEOX:[self wasReceivedWithEOX]];

    return newMessage;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:data forKey:@"data"];
    [coder encodeBool:[self wasReceivedWithEOX] forKey:@"wasReceivedWithEOX"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super initWithCoder:decoder])) {
        id obj = [decoder decodeObjectForKey:@"data"];
        if (obj && [obj isKindOfClass:[NSData class]]) {
            data = [obj retain];
        } else {
            goto fail;
        }
        
        [self setWasReceivedWithEOX:[decoder decodeBoolForKey:@"wasReceivedWithEOX"]];
    }
    
    return self;
    
fail:
    [self release];
    return nil;
}

- (SMMessageType)messageType;
{
    return SMMessageTypeSystemExclusive;
}

- (NSUInteger)otherDataLength
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
        NSUInteger length;
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
    return NSLocalizedStringFromTableInBundle(@"SysEx", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of System Exclusive event");
}

- (NSString *)dataForDisplay;
{
    NSString *manufacturerName = [self manufacturerName];
    NSString *lengthString = [self sizeForDisplay];
    NSString *dataString = [self expertDataForDisplay];

    NSMutableString *result = [NSMutableString string];
    if (manufacturerName) {
        [result appendString:manufacturerName];
    }
    if (lengthString) {
        if (result.length > 0) {
            [result appendString:@" "];
        }
        [result appendString:lengthString];
    }
    if (dataString) {
        if (result.length > 0) {
            [result appendString:@"\t"];
        }
        [result appendString:dataString];
    }

    return result;
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

- (NSUInteger)receivedDataLength;
{
    return [[self receivedData] length];
}

- (NSData *)receivedDataWithStartByte;
{
    return [self dataByAddingStartByte:[self receivedData]];
}

- (NSUInteger)receivedDataWithStartByteLength;
{
    return [self receivedDataLength] + 1;
}

- (NSData *)fullMessageData;
{
    return [self dataByAddingStartByte:[self otherData]];
}

- (NSUInteger)fullMessageDataLength;
{
    return [self otherDataLength] + 1;
}

- (NSData *)manufacturerIdentifier;
{
    NSUInteger length;
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
        NSLocalizedStringFromTableInBundle(@"%@ bytes", @"SnoizeMIDI", SMBundleForObject(self), "SysEx length format string"),
        [SMMessage formatLength:[self receivedDataWithStartByteLength]]];
}

@end


@implementation SMSystemExclusiveMessage (Private)

+ (NSArray *)systemExclusiveMessagesInSMFData:(NSData *)smfData;
{
    NSUInteger smfDataLength;
    const Byte *p, *end;
    UInt32 chunkSize;
    NSMutableArray *messages;
    NSMutableData *readingSysexData = nil;

    messages = [NSMutableArray array];

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
                    NSLog(@"Bad data in standard MIDI file: at offset 0x%08ld, got byte 0x%02x when we expected >= 0x80", (long)(p - 1 - (const Byte*)[smfData bytes]), eventType);
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

+ (NSData *)smfDataForSystemExclusiveMessages:(NSArray *)messages;
{
    const Byte smfHeader[] = {
        // SMF header chunk 'MThd' : Type 1 file with 2 tracks and 480 ppqn
        0x4d, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06, 0x00, 0x01, 0x00, 0x02, 0x01, 0xe0,
        // Track chunk 'MTrk': establishes time signature and tempo
        0x4d, 0x54, 0x72, 0x6b,  0x00, 0x00, 0x00, 0x13, 0x00, 0xff, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08, 0x00, 0xff, 0x51, 0x03, 0x07, 0xa1, 0x20, 0x00, 0xff, 0x2f, 0x00,
        // Beginning of track chunk 'MTrk' for our event data
        0x4d, 0x54, 0x72, 0x6b
    };
    const Byte endOfTrackEvent[] = { 0x00, 0xff, 0x2f, 0x00 };
    const UInt32 tickOffsetBetweenMessages = 500;

    NSMutableData *smfData;
    UInt32 smfDataLength;
    UInt32 trackLength;
    NSUInteger messageIndex, messageCount;
    Byte *p;

    messageCount = [messages count];

    smfDataLength = sizeof(smfHeader);
    smfDataLength += 4;	// for track length UInt32
    trackLength = 0;
    
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMSystemExclusiveMessage *message;
        UInt32 tickOffset;
        UInt32 messageLength;

        message = [messages objectAtIndex:messageIndex];
        messageLength = (UInt32)[message otherDataLength];	// without 0xF0, with 0xF7

        if (messageIndex == 0)
            tickOffset = 0;
        else
            tickOffset = tickOffsetBetweenMessages;
        trackLength += lengthOfVariableLengthFieldForValue(tickOffset);
        
        trackLength++;		// for sysex event type (0xF0)
        trackLength += lengthOfVariableLengthFieldForValue(messageLength);	// for sysex length
        trackLength += messageLength;		// for sysex data
    }
    trackLength += sizeof(endOfTrackEvent);
    smfDataLength += trackLength;

    smfData = [NSMutableData dataWithLength:smfDataLength];
    p = [smfData mutableBytes];

    // Write out SMF header and track header (constant)
    memcpy(p, smfHeader, sizeof(smfHeader));
    p += sizeof(smfHeader);

    // Write out total length of this track (as UInt32 big endian)
    *(UInt32 *)p = CFSwapInt32HostToBig(trackLength);
    p += 4;
    
    // for each message:
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMSystemExclusiveMessage *message;
        UInt32 tickOffset;
        UInt32 messageLength;

        message = [messages objectAtIndex:messageIndex];
        messageLength = (UInt32)[message otherDataLength];	// without 0xF0, with 0xF7

        // write out varlength offset (0 for 1st msg, 500 for laster messages)
        if (messageIndex == 0)
            tickOffset = 0;
        else
            tickOffset = tickOffsetBetweenMessages;
        writeVariableLengthFieldIntoSMF(&p, tickOffset);
            
        // write out 0xF0 (start of sysex)
        *p++ = 0xF0;

        // write out varlength sysex size
        writeVariableLengthFieldIntoSMF(&p, messageLength);
        
        // write out sysex, with 0xF7 ending
        memcpy(p, [message otherDataBuffer], messageLength);
        p += messageLength;
    }

    // write out end-of-track event
    memcpy(p, endOfTrackEvent, sizeof(endOfTrackEvent));
    p += sizeof(endOfTrackEvent);

    // We're done!
    return smfData;
}

Byte lengthOfVariableLengthFieldForValue(UInt32 value)
{
    Byte length = 0;

    if (value >= (1 << 21))
        length++;
    if (value >= (1 << 14))
        length++;
    if (value >= (1 << 7))
        length++;
    length++;

    return length;
}

void writeVariableLengthFieldIntoSMF(Byte **pPtr, const UInt32 value)
{
    Byte *p = *pPtr;

    if (value >= (1 << 21))
        *p++ = (Byte)((value >> 21) & 0x7F) | 0x80;
    if (value >= (1 << 14))
        *p++ = (Byte)((value >> 14) & 0x7F) | 0x80;
    if (value >= (1 << 7))
        *p++ = (Byte)((value >> 7) & 0x7F) | 0x80;
    *p++ = ((Byte)value & 0x7F);

    *pPtr = p;
}


+ (NSArray *)systemExclusiveMessagesInDataBuffer:(const Byte *)buffer withLength:(NSUInteger)byteCount;
{
    // Scan through someData and make messages out of it.
    // Messages must start with 0xF0.  Messages may end in any byte > 0x7F.

    NSMutableArray *messages;
    NSUInteger byteIndex;
    const Byte *p;
    NSRange range = { 0, 0 };
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
    NSUInteger length;
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
