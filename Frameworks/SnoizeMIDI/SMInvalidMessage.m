//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMInvalidMessage.h"

#import "SMUtilities.h"


@implementation SMInvalidMessage : SMMessage

+ (SMInvalidMessage *)invalidMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp data:(NSData *)aData
{
    SMInvalidMessage *message;
    
    message = [[[SMInvalidMessage alloc] initWithTimeStamp:aTimeStamp statusByte:0x00] autorelease];
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

@end
