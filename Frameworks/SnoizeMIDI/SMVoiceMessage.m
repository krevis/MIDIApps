//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMVoiceMessage.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@implementation SMVoiceMessage : SMMessage

+ (SMVoiceMessage *)voiceMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp statusByte:(Byte)aStatusByte data:(const Byte *)aData length:(UInt16)aLength
{
    SMVoiceMessage *message;
    
    message = [[[SMVoiceMessage alloc] initWithTimeStamp:aTimeStamp statusByte:aStatusByte] autorelease];

    OBASSERT(aLength >= 1 && aLength <= 2);
    if (aLength >= 1)
        message->dataBytes[0] = *aData;
    if (aLength == 2)
        message->dataBytes[1] = *(aData + 1);
    
    return message;
}

//
// SMMessage overrides
//

- (id)copyWithZone:(NSZone *)zone;
{
    SMVoiceMessage *newMessage;
    
    newMessage = [super copyWithZone:zone];
    newMessage->dataBytes[0] = dataBytes[0];
    newMessage->dataBytes[1] = dataBytes[1];

    return newMessage;
}

- (SMMessageType)messageType;
{
    switch ([self status]) {
        case SMVoiceMessageStatusNoteOff:
            return SMMessageTypeNoteOff;
            
        case SMVoiceMessageStatusNoteOn:
            return SMMessageTypeNoteOn;
            
        case SMVoiceMessageStatusAftertouch:
            return SMMessageTypeAftertouch;
            
        case SMVoiceMessageStatusControl:
            return SMMessageTypeControl;
            
        case SMVoiceMessageStatusProgram:
            return SMMessageTypeProgram;
            
        case SMVoiceMessageStatusChannelPressure:
            return SMMessageTypeChannelPressure;
            
        case SMVoiceMessageStatusPitchWheel:
            return SMMessageTypePitchWheel;

        default:
            return SMMessageTypeUnknown;
    }
}

- (unsigned int)otherDataLength;
{
    switch ([self status]) {
        case SMVoiceMessageStatusProgram:
        case SMVoiceMessageStatusChannelPressure:
            return 1;
            break;
    
        case SMVoiceMessageStatusNoteOff:
        case SMVoiceMessageStatusNoteOn:
        case SMVoiceMessageStatusAftertouch:
        case SMVoiceMessageStatusControl:
        case SMVoiceMessageStatusPitchWheel:        
            return 2;
            break;

        default:
            return 0;
            break;
    }
}

- (const Byte *)otherDataBuffer;
{
    return dataBytes;
}

- (NSString *)typeForDisplay;
{
    switch ([self status]) {
        case SMVoiceMessageStatusNoteOn:
            if (dataBytes[1] != 0)
                return NSLocalizedStringFromTableInBundle(@"Note On", @"SnoizeMIDI", [self bundle], "displayed type of Note On event");
            // else fall through to Note Off

        case SMVoiceMessageStatusNoteOff:
            return NSLocalizedStringFromTableInBundle(@"Note Off", @"SnoizeMIDI", [self bundle], "displayed type of Note Off event");
            
        case SMVoiceMessageStatusAftertouch:
            return NSLocalizedStringFromTableInBundle(@"Aftertouch", @"SnoizeMIDI", [self bundle], "displayed type of Aftertouch (poly pressure) event");
            
        case SMVoiceMessageStatusControl:
            return NSLocalizedStringFromTableInBundle(@"Control", @"SnoizeMIDI", [self bundle], "displayed type of Control event");
            
        case SMVoiceMessageStatusProgram:
            return NSLocalizedStringFromTableInBundle(@"Program", @"SnoizeMIDI", [self bundle], "displayed type of Program event");
            
        case SMVoiceMessageStatusChannelPressure:
            return NSLocalizedStringFromTableInBundle(@"Channel Pressure", @"SnoizeMIDI", [self bundle], "displayed type of Channel Pressure (aftertouch) event");
            
        case SMVoiceMessageStatusPitchWheel:
            return NSLocalizedStringFromTableInBundle(@"Pitch Wheel", @"SnoizeMIDI", [self bundle], "displayed type of Pitch Wheel event");

        default:
            return [super typeForDisplay];
    }
}

- (NSString *)channelForDisplay;
{
    return [NSString stringWithFormat:@"%u", [self channel]];
}

- (NSString *)dataForDisplay;
{
    NSString *part1 = nil, *part2 = nil;

    switch ([self status]) {
        case SMVoiceMessageStatusNoteOff:
        case SMVoiceMessageStatusNoteOn:
        case SMVoiceMessageStatusAftertouch:
            part1 = [SMMessage formatNoteNumber:dataBytes[0]];
            part2 = [SMMessage formatDataByte:dataBytes[1]];
            break;

        case SMVoiceMessageStatusControl:
            part1 = [SMMessage formatControllerNumber:dataBytes[0]];
            part2 = [SMMessage formatDataByte:dataBytes[1]];
            break;
            
        case SMVoiceMessageStatusProgram:
        case SMVoiceMessageStatusChannelPressure:
            // Use super's implementation
            break;
            
        case SMVoiceMessageStatusPitchWheel:
            part1 = [SMMessage formatSignedDataByte1:dataBytes[0] byte2:dataBytes[1]];
            break;

        default:
            break;
    }
    
    if (part1) {
        if (part2)
            return [[part1 stringByAppendingString:@"\t"] stringByAppendingString:part2];
        else
            return part1;
    } else {
        return [super dataForDisplay];
    }
}


//
// Additional API
//

- (SMVoiceMessageStatus)status;
{
    return statusByte & 0xF0;
}

- (void)setStatus:(SMVoiceMessageStatus)newStatus;
{
    statusByte = newStatus | ([self channel] - 1);
}

- (Byte)channel;
{
    return (statusByte & 0x0F) + 1;
}

- (void)setChannel:(Byte)newChannel;
{
    statusByte = [self status] | (newChannel - 1);
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

- (BOOL)matchesChannelMask:(SMChannelMask)mask;
{
    return (mask & (1 << ([self channel] - 1))) ? YES : NO;
}

- (BOOL)transposeBy:(Byte)transposeAmount;
{
    SMVoiceMessageStatus status;
    
    status = [self status];
    if (status == SMVoiceMessageStatusNoteOff || status == SMVoiceMessageStatusNoteOn || status == SMVoiceMessageStatusAftertouch) {
        int value;
        
        value = (int)[self dataByte1] + transposeAmount;
        if (value < 0 || value > 127)
            return NO;
        
        [self setDataByte1:value];
        return YES;
    }
    
    return NO;
}

@end
