//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMSystemCommonMessage.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@implementation SMSystemCommonMessage

+ (SMSystemCommonMessage *)systemCommonMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp type:(SMSystemCommonMessageType)aType data:(const Byte *)aData length:(UInt16)aLength
{
    SMSystemCommonMessage *message;
    
    message = [[[SMSystemCommonMessage alloc] initWithTimeStamp:aTimeStamp statusByte:aType] autorelease];

    OBASSERT(aLength <= 2);
    if (aLength >= 1)
        message->dataBytes[0] = aData[0];
    if (aLength == 2)
        message->dataBytes[1] = aData[1];
    
    return message;
}

//
// SMMessage overrides
//

- (id)copyWithZone:(NSZone *)zone;
{
    SMSystemCommonMessage *newMessage;
    
    newMessage = [super copyWithZone:zone];
    newMessage->dataBytes[0] = dataBytes[0];
    newMessage->dataBytes[1] = dataBytes[1];

    return newMessage;
}

- (SMMessageType)messageType;
{
    switch ([self type]) {
        case SMSystemCommonMessageTypeTimeCodeQuarterFrame:
            return SMMessageTypeTimeCode;
            
        case SMSystemCommonMessageTypeSongPositionPointer:
            return SMMessageTypeSongPositionPointer;
            
        case SMSystemCommonMessageTypeSongSelect:
            return SMMessageTypeSongSelect;
            
        case SMSystemCommonMessageTypeTuneRequest:
            return SMMessageTypeTuneRequest;

        default:
            return SMMessageTypeUnknown;
    }
}

- (unsigned int)otherDataLength;
{
    switch ([self type]) {
        case SMSystemCommonMessageTypeTuneRequest:
        default:
            return 0;
            break;    

        case SMSystemCommonMessageTypeTimeCodeQuarterFrame:
        case SMSystemCommonMessageTypeSongSelect:
            return 1;
            break;

        case SMSystemCommonMessageTypeSongPositionPointer:
            return 2;
            break;
    }
}

- (const Byte *)otherDataBuffer;
{
    return dataBytes;
}

- (NSString *)typeForDisplay;
{
    switch ([self type]) {
        case SMSystemCommonMessageTypeTimeCodeQuarterFrame:
            return NSLocalizedStringFromTableInBundle(@"MTC Quarter Frame", @"SnoizeMIDI", [self bundle], "displayed type of MTC Quarter Frame event");
            
        case SMSystemCommonMessageTypeSongPositionPointer:
            return NSLocalizedStringFromTableInBundle(@"Song Position Pointer", @"SnoizeMIDI", [self bundle], "displayed type of Song Position Pointer event");
            
        case SMSystemCommonMessageTypeSongSelect:
            return NSLocalizedStringFromTableInBundle(@"Song Select", @"SnoizeMIDI", [self bundle], "displayed type of Song Select event");
            
        case SMSystemCommonMessageTypeTuneRequest:
            return NSLocalizedStringFromTableInBundle(@"Tune Request", @"SnoizeMIDI", [self bundle], "displayed type of Tune Request event");

        default:
            return [super typeForDisplay];
    }
}


//
// Additional API
//

- (SMSystemCommonMessageType)type;
{
    return statusByte;
}

- (void)setType:(SMSystemCommonMessageType)newType;
{
    statusByte = newType;
}

- (Byte)dataByte1;
{
    return dataBytes[0];
}

- (void)setDataByte1:(Byte)newValue;
{
    OBASSERT([self otherDataLength] >= 1);
    dataBytes[0] = newValue;
}

- (Byte)dataByte2;
{
    return dataBytes[1];
}

- (void)setDataByte2:(Byte)newValue;
{
    OBASSERT([self otherDataLength] >= 2);
    dataBytes[1] = newValue;
}

@end
