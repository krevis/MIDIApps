//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <SnoizeMIDI/SMMessage.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


typedef enum _SMChannelMask {
    SMChannelMaskNone = 0,
    SMChannelMask1 = (1 << 0),
    SMChannelMask2 = (1 << 1),
    SMChannelMask3 = (1 << 2),
    SMChannelMask4 = (1 << 3),
    SMChannelMask5 = (1 << 4),
    SMChannelMask6 = (1 << 5),
    SMChannelMask7 = (1 << 6),
    SMChannelMask8 = (1 << 7),
    SMChannelMask9 = (1 << 8),
    SMChannelMask10 = (1 << 9),
    SMChannelMask11 = (1 << 10),
    SMChannelMask12 = (1 << 11),
    SMChannelMask13 = (1 << 12),
    SMChannelMask14 = (1 << 13),
    SMChannelMask15 = (1 << 14),
    SMChannelMask16 = (1 << 15),
    SMChannelMaskAll = (1 << 16) - 1
} SMChannelMask;

typedef enum _SMVoiceMessageStatus {
    SMVoiceMessageStatusNoteOff = 0x80,
    SMVoiceMessageStatusNoteOn = 0x90,
    SMVoiceMessageStatusAftertouch = 0xA0,
    SMVoiceMessageStatusControl= 0xB0,
    SMVoiceMessageStatusProgram = 0xC0,
    SMVoiceMessageStatusChannelPressure = 0xD0,
    SMVoiceMessageStatusPitchWheel = 0xE0
} SMVoiceMessageStatus;

@interface SMVoiceMessage : SMMessage
{
    Byte dataBytes[2];
}

+ (SMVoiceMessage *)voiceMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp statusByte:(Byte)aStatusByte data:(const Byte *)aData length:(UInt16)aLength;
    // aLength must be 1 or 2

- (SMVoiceMessageStatus)status;
- (void)setStatus:(SMVoiceMessageStatus)newStatus;

- (Byte)channel;
- (void)setChannel:(Byte)newChannel;
    // NOTE Channel is 1-16, not 0-15

- (Byte)dataByte1;
- (void)setDataByte1:(Byte)newValue;

- (Byte)dataByte2;
- (void)setDataByte2:(Byte)newValue;

- (BOOL)matchesChannelMask:(SMChannelMask)mask;
    // NOTE
    // We could implement -matchesChannelMask on all SMMessages, but I don't know if the default should be YES or NO...
    // I could see it going either way, in different contexts.

- (BOOL)transposeBy:(Byte)transposeAmount;
    // Returns NO if the transposition puts the note out of the representable range

@end
