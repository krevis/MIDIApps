#import "SMSystemExclusiveMessage.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


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
    // Scan through someData and make messages out of it.
    // Messages must start with 0xF0.  Messages may end in any byte > 0x7F.

    NSMutableArray *messages;
    unsigned int byteIndex, byteCount;
    const Byte *p;
    NSRange range;
    BOOL inMessage;

    messages = [NSMutableArray array];
    
    byteCount = [someData length];
    inMessage = NO;
    for (p=[someData bytes], byteIndex = 0; byteIndex < byteCount; byteIndex++, p++) {
        if (inMessage && (*p & 0x80)) {
            range.length = byteIndex - range.location;
            if (range.length > 0)
                [messages addObject:[self systemExclusiveMessageWithTimeStamp:0 data:[someData subdataWithRange:range]]];
            inMessage = NO;
        }

        if (*p == 0xF0) {
            inMessage = YES;
            range.location = byteIndex + 1;
        }
    }
    if (inMessage) {
        range.length = byteIndex - range.location;
        if (range.length > 0)
            [messages addObject:[self systemExclusiveMessageWithTimeStamp:0 data:[someData subdataWithRange:range]]];
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
