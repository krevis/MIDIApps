#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


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
    
    // Groups
    SMMessageTypeNothingMask			= 0,
    SMMessageTypeAllVoiceMask			= (SMMessageTypeNoteOn | SMMessageTypeNoteOff | SMMessageTypeAftertouch | SMMessageTypeControl | SMMessageTypeProgram | SMMessageTypeChannelPressure | SMMessageTypePitchWheel),
    SMMessageTypeNoteOnAndOffMask		= (SMMessageTypeNoteOn | SMMessageTypeNoteOff),
    SMMessageTypeAllSystemCommonMask	= (SMMessageTypeTimeCode | SMMessageTypeSongPositionPointer | SMMessageTypeSongSelect | SMMessageTypeTuneRequest),
    SMMessageTypeAllRealTimeMask		= (SMMessageTypeClock | SMMessageTypeStart | SMMessageTypeStop | SMMessageTypeContinue | SMMessageTypeActiveSense | SMMessageTypeReset),
    SMMessageTypeStartStopContinueMask	= (SMMessageTypeStart | SMMessageTypeStop | SMMessageTypeContinue),
    SMMessageTypeAllMask			= (SMMessageTypeAllVoiceMask | SMMessageTypeAllSystemCommonMask | SMMessageTypeAllRealTimeMask | SMMessageTypeSystemExclusive)

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


@interface SMMessage : OFObject <NSCopying>
{
    MIDITimeStamp timeStamp;
    Byte statusByte;
}

+ (NSString *)formatNoteNumber:(Byte)noteNumber;
+ (NSString *)formatNoteNumber:(Byte)noteNumber usingOption:(SMNoteFormattingOption)option;
+ (NSString *)formatControllerNumber:(Byte)controllerNumber;
+ (NSString *)formatControllerNumber:(Byte)controllerNumber usingOption:(SMControllerFormattingOption)option;
+ (NSString *)nameForControllerNumber:(Byte)controllerNumber;
+ (NSString *)formatData:(NSData *)data;
+ (NSString *)formatDataBytes:(const Byte *)bytes length:(unsigned int)length;
+ (NSString *)formatDataByte:(Byte)dataByte;
+ (NSString *)formatDataByte:(Byte)dataByte usingOption:(SMDataFormattingOption)option;
+ (NSString *)formatSignedDataByte1:(Byte)dataByte1 byte2:(Byte)dataByte2;
+ (NSString *)formatSignedDataByte1:(Byte)dataByte1 byte2:(Byte)dataByte2 usingOption:(SMDataFormattingOption)option;
+ (NSString *)formatLength:(unsigned int)length;
+ (NSString *)formatLength:(unsigned int)length usingOption:(SMDataFormattingOption)option;
+ (NSString *)nameForManufacturerIdentifier:(NSData *)manufacturerIdentifierData;
+ (NSString *)formatTimeStamp:(MIDITimeStamp)timeStamp;
+ (NSString *)formatTimeStamp:(MIDITimeStamp)timeStamp usingOption:(SMTimeFormattingOption)option;

- (id)initWithTimeStamp:(MIDITimeStamp)aTimeStamp statusByte:(Byte)aStatusByte;
    // Designated initializer

- (MIDITimeStamp)timeStamp;
- (void)setTimeStamp:(MIDITimeStamp)value;
- (void)setTimeStampToNow;

- (Byte)statusByte;
    // First MIDI byte
    
- (SMMessageType)messageType;
    // Enumerated message type, which doesn't correspond to MIDI value
- (BOOL)matchesMessageTypeMask:(SMMessageType)mask;

- (unsigned int)otherDataLength;
    // Length of data after the status byte
- (const Byte *)otherDataBuffer;
    // May return NULL, indicating no additional data
- (NSData *)otherData;
    // May return nil, indicating no additional data

// Display methods

- (NSString *)timeStampForDisplay;
- (NSString *)channelForDisplay;
- (NSString *)typeForDisplay;
- (NSString *)dataForDisplay;

@end
