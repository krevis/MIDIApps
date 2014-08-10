/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMVoiceMessage.h"

#import "SMUtilities.h"


@implementation SMVoiceMessage : SMMessage

+ (SMVoiceMessage *)voiceMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp statusByte:(Byte)aStatusByte data:(const Byte *)aData length:(UInt16)aLength
{
    SMVoiceMessage *message;
    
    message = [[[SMVoiceMessage alloc] initWithTimeStamp:aTimeStamp statusByte:aStatusByte] autorelease];

    SMAssert(aLength >= 1 && aLength <= 2);
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

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeBytes:dataBytes length:2 forKey:@"dataBytes"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super initWithCoder:decoder])) {
        NSUInteger len;
        const uint8_t *decodedBytes = [decoder decodeBytesForKey:@"dataBytes" returnedLength:&len];
        if (decodedBytes && len == 2) {
            dataBytes[0] = decodedBytes[0];
            dataBytes[1] = decodedBytes[1];
        } else {
            goto fail;
        }
    }
    
    return self;
    
fail:
    [self release];
    return nil;
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

- (NSUInteger)otherDataLength;
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
            // In the MIDI specification, Note On with 0 velocity is defined to have
            // the exact same meaning as Note Off (with 0 velocity).
            // In non-expert mode, show these events as Note Offs.
            // In expert mode, show them as Note Ons.
            if (dataBytes[1] != 0 || [[NSUserDefaults standardUserDefaults] boolForKey:SMExpertModePreferenceKey])
                return NSLocalizedStringFromTableInBundle(@"Note On", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Note On event");
            // else fall through to Note Off

        case SMVoiceMessageStatusNoteOff:
            return NSLocalizedStringFromTableInBundle(@"Note Off", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Note Off event");
            
        case SMVoiceMessageStatusAftertouch:
            return NSLocalizedStringFromTableInBundle(@"Aftertouch", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Aftertouch (poly pressure) event");
            
        case SMVoiceMessageStatusControl:
            return NSLocalizedStringFromTableInBundle(@"Control", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Control event");
            
        case SMVoiceMessageStatusProgram:
            return NSLocalizedStringFromTableInBundle(@"Program", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Program event");
            
        case SMVoiceMessageStatusChannelPressure:
            return NSLocalizedStringFromTableInBundle(@"Channel Pressure", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Channel Pressure (aftertouch) event");
            
        case SMVoiceMessageStatusPitchWheel:
            return NSLocalizedStringFromTableInBundle(@"Pitch Wheel", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Pitch Wheel event");

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
    SMAssert([self otherDataLength] >= 1);
    dataBytes[0] = newValue;
}

- (Byte)dataByte2;
{
    return dataBytes[1];
}

- (void)setDataByte2:(Byte)newValue;
{
    SMAssert([self otherDataLength] >= 2);
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
