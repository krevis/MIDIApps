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


typedef enum _SMSystemCommonMessageType {
    SMSystemCommonMessageTypeTimeCodeQuarterFrame = 0xF1,
    SMSystemCommonMessageTypeSongPositionPointer = 0xF2,
    SMSystemCommonMessageTypeSongSelect = 0xF3,
    SMSystemCommonMessageTypeTuneRequest = 0xF6
} SMSystemCommonMessageType;

@interface SMSystemCommonMessage : SMMessage
{
    Byte dataBytes[2];
}

+ (SMSystemCommonMessage *)systemCommonMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp type:(SMSystemCommonMessageType)aType data:(const Byte *)aData length:(UInt16)aLength;
    // aLength must be 0, 1, or 2

- (SMSystemCommonMessageType)type;
- (void)setType:(SMSystemCommonMessageType)newType;

- (Byte)dataByte1;
- (void)setDataByte1:(Byte)newValue;

- (Byte)dataByte2;
- (void)setDataByte2:(Byte)newValue;

@end
