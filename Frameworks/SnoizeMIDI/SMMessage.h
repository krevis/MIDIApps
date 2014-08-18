/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMEndpoint;
@class SMMessageTimeBase;


typedef enum _SMMessageType {
    SMMessageTypeUnknown 		= 0,

    // Voice messages
    SMMessageTypeNoteOn		= 1 << 0,
    SMMessageTypeNoteOff		= 1 << 1,
    SMMessageTypeAftertouch		= 1 << 2,
    SMMessageTypeControl		= 1 << 3,
    SMMessageTypeProgram		= 1 << 4,
    SMMessageTypeChannelPressure	= 1 << 5,
    SMMessageTypePitchWheel		= 1 << 6,

    // System common messages
    SMMessageTypeTimeCode		= 1 << 7,
    SMMessageTypeSongPositionPointer	= 1 << 8,
    SMMessageTypeSongSelect		= 1 << 9,
    SMMessageTypeTuneRequest		= 1 << 10,

    // Real time messages
    SMMessageTypeClock			= 1 << 11,
    SMMessageTypeStart			= 1 << 12,
    SMMessageTypeStop			= 1 << 13,
    SMMessageTypeContinue		= 1 << 14,
    SMMessageTypeActiveSense		= 1 << 15,
    SMMessageTypeReset			= 1 << 16,
    
    // System exclusive
    SMMessageTypeSystemExclusive	= 1 << 17,

    // Invalid
    SMMessageTypeInvalid			= 1 << 18,
    
    // Groups
    SMMessageTypeNothingMask			= 0,
    SMMessageTypeAllVoiceMask			= (SMMessageTypeNoteOn | SMMessageTypeNoteOff | SMMessageTypeAftertouch | SMMessageTypeControl | SMMessageTypeProgram | SMMessageTypeChannelPressure | SMMessageTypePitchWheel),
    SMMessageTypeNoteOnAndOffMask		= (SMMessageTypeNoteOn | SMMessageTypeNoteOff),
    SMMessageTypeAllSystemCommonMask	= (SMMessageTypeTimeCode | SMMessageTypeSongPositionPointer | SMMessageTypeSongSelect | SMMessageTypeTuneRequest),
    SMMessageTypeAllRealTimeMask		= (SMMessageTypeClock | SMMessageTypeStart | SMMessageTypeStop | SMMessageTypeContinue | SMMessageTypeActiveSense | SMMessageTypeReset),
    SMMessageTypeStartStopContinueMask	= (SMMessageTypeStart | SMMessageTypeStop | SMMessageTypeContinue),
    SMMessageTypeAllMask			= (SMMessageTypeAllVoiceMask | SMMessageTypeAllSystemCommonMask | SMMessageTypeAllRealTimeMask | SMMessageTypeSystemExclusive | SMMessageTypeInvalid)

} SMMessageType;

typedef enum _SMNoteFormattingOption {
    SMNoteFormatDecimal = 0,
    SMNoteFormatHexadecimal = 1,
    SMNoteFormatNameMiddleC3 = 2,	// Middle C = 60 decimal = C3, aka "Yamaha"
    SMNoteFormatNameMiddleC4 = 3	// Middle C = 60 decimal = C4, aka "Roland"
} SMNoteFormattingOption;

typedef enum _SMControllerFormattingOption {
    SMControllerFormatDecimal = 0,
    SMControllerFormatHexadecimal = 1,
    SMControllerFormatName = 2
} SMControllerFormattingOption;

typedef enum _SMDataFormattingOption {
    SMDataFormatDecimal = 0,
    SMDataFormatHexadecimal = 1
} SMDataFormattingOption;

typedef enum _SMTimeFormattingOption {
    SMTimeFormatHostTimeInteger = 0,
    SMTimeFormatHostTimeNanoseconds = 1,
    SMTimeFormatHostTimeSeconds = 2,
    SMTimeFormatClockTime = 3,
    SMTimeFormatHostTimeHexInteger = 4
} SMTimeFormattingOption;

// Preferences keys
extern NSString *SMNoteFormatPreferenceKey;
extern NSString *SMControllerFormatPreferenceKey;
extern NSString *SMDataFormatPreferenceKey;
extern NSString *SMTimeFormatPreferenceKey;
extern NSString *SMExpertModePreferenceKey;

@interface SMMessage : NSObject <NSCopying, NSCoding>
{
    MIDITimeStamp timeStamp;
    SMMessageTimeBase *timeBase;
    Byte statusByte;
    id originatingEndpointOrName;   // either SMEndpoint or NSString
    BOOL timeStampWasZeroWhenReceived;
}

+ (NSString *)formatNoteNumber:(Byte)noteNumber;
+ (NSString *)formatNoteNumber:(Byte)noteNumber usingOption:(SMNoteFormattingOption)option;
+ (NSString *)formatControllerNumber:(Byte)controllerNumber;
+ (NSString *)formatControllerNumber:(Byte)controllerNumber usingOption:(SMControllerFormattingOption)option;
+ (NSString *)nameForControllerNumber:(Byte)controllerNumber;
+ (NSString *)formatData:(NSData *)data;
+ (NSString *)formatDataBytes:(const Byte *)bytes length:(NSUInteger)length;
+ (NSString *)formatDataByte:(Byte)dataByte;
+ (NSString *)formatDataByte:(Byte)dataByte usingOption:(SMDataFormattingOption)option;
+ (NSString *)formatSignedDataByte1:(Byte)dataByte1 byte2:(Byte)dataByte2;
+ (NSString *)formatSignedDataByte1:(Byte)dataByte1 byte2:(Byte)dataByte2 usingOption:(SMDataFormattingOption)option;
+ (NSString *)formatLength:(NSUInteger)length;
+ (NSString *)formatLength:(NSUInteger)length usingOption:(SMDataFormattingOption)option;
+ (NSString *)nameForManufacturerIdentifier:(NSData *)manufacturerIdentifierData;

- (id)initWithTimeStamp:(MIDITimeStamp)aTimeStamp statusByte:(Byte)aStatusByte;
    // Designated initializer

- (MIDITimeStamp)timeStamp;
- (void)setTimeStamp:(MIDITimeStamp)value;

- (Byte)statusByte;
    // First MIDI byte
    
- (SMMessageType)messageType;
    // Enumerated message type, which doesn't correspond to MIDI value
- (BOOL)matchesMessageTypeMask:(SMMessageType)mask;

- (NSUInteger)otherDataLength;
    // Length of data after the status byte
- (const Byte *)otherDataBuffer;
    // May return NULL, indicating no additional data
- (NSData *)otherData;
    // May return nil, indicating no additional data

- (SMEndpoint *)originatingEndpoint;
- (void)setOriginatingEndpoint:(SMEndpoint *)value;

// Display methods

- (NSString *)timeStampForDisplay;
- (NSString *)channelForDisplay;
- (NSString *)typeForDisplay;
- (NSString *)dataForDisplay;
- (NSString *)expertDataForDisplay;
- (NSString *)originatingEndpointForDisplay;

@end
