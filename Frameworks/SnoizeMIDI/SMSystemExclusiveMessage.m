#import "SMSystemExclusiveMessage.h"

#import <AudioToolbox/MusicPlayer.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface SMSystemExclusiveMessage (Private)

+ (NSArray *)_systemExclusiveMessagesInDataBuffer:(const Byte *)buffer withLength:(unsigned int)byteCount;

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
    return [self _systemExclusiveMessagesInDataBuffer:[someData bytes] withLength:[someData length]];
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

                        eventMessages = [self _systemExclusiveMessagesInDataBuffer:eventData withLength:eventDataSize];
                        if (eventMessages)
                            [messages addObjectsFromArray:eventMessages];
                    }

                    MusicEventIteratorNextEvent(iterator);
                }

                DisposeMusicEventIterator(iterator);
            }
        }

        DisposeMusicSequence(sequence);
    }
    
    return messages;    
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

- (NSData *)fullMessageData;
{
    unsigned int length;
    NSMutableData *fullMessageData;
    Byte *bytes;

    length = [data length];
    fullMessageData = [[NSMutableData alloc] initWithLength:1 + length + 1];
    bytes = [fullMessageData mutableBytes];

    *bytes = 0xF0;
    [data getBytes:bytes+1];
    *(bytes + length + 1) = 0xF7;

    return fullMessageData;
}

- (unsigned int)fullMessageDataLength;
{
    return [data length] + 2;
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

- (NSString *)dataForDisplay;
{
    NSString *manufacturerName, *lengthString;
    
    manufacturerName = [self manufacturerName];
    lengthString = [NSString stringWithFormat:
        NSLocalizedStringFromTableInBundle(@"%@ bytes", @"SnoizeMIDI", [self bundle], "SysEx length format string"),
        [SMMessage formatLength:[[self receivedData] length]]];

    if (manufacturerName)
        return [[manufacturerName stringByAppendingString:@"\t"] stringByAppendingString:lengthString];
    else
        return lengthString;
}

@end


@implementation SMSystemExclusiveMessage (Private)

+ (NSArray *)_systemExclusiveMessagesInDataBuffer:(const Byte *)buffer withLength:(unsigned int)byteCount;
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

@end
