/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


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
