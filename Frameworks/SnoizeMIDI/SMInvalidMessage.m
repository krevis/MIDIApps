//
// Copyright 2003 Kurt Revis. All rights reserved.
//

#import "SMInvalidMessage.h"

#import "SMUtilities.h"


@implementation SMInvalidMessage : SMMessage

+ (SMInvalidMessage *)invalidMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp data:(NSData *)aData
{
    SMInvalidMessage *message;
    
    message = [[[SMInvalidMessage alloc] initWithTimeStamp:aTimeStamp statusByte:0x00] autorelease];
    // statusByte is ignored
    [message setData:aData];

    return message;
}

- (void)dealloc
{
    [data release];

    [super dealloc];
}

//
// SMMessage overrides
//

- (id)copyWithZone:(NSZone *)zone;
{
    SMInvalidMessage *newMessage;
    
    newMessage = [super copyWithZone:zone];
    [newMessage setData:data];

    return newMessage;
}

- (SMMessageType)messageType;
{
    return SMMessageTypeInvalid;
}

- (unsigned int)otherDataLength
{
    return [data length];
}

- (const Byte *)otherDataBuffer;
{
    return [[self otherData] bytes];    
}

- (NSData *)otherData
{
    return [self data];
}

- (NSString *)typeForDisplay;
{
    return NSLocalizedStringFromTableInBundle(@"Invalid", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Invalid event");
}

- (NSString*)dataForDisplay
{
    return [self sizeForDisplay];
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
    }
}

- (NSString *)sizeForDisplay;
{
    return [NSString stringWithFormat:
        NSLocalizedStringFromTableInBundle(@"%@ bytes", @"SnoizeMIDI", SMBundleForObject(self), "Invalid message length format string"),
        [SMMessage formatLength:[self otherDataLength]]];
}

@end
