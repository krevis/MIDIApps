//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMMessage.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMEndpoint.h"
#import "SMHostTime.h"


@interface SMMessage (Private)

static NSString *_formatNoteNumberWithBaseOctave(Byte noteNumber, int octave);

@end


@implementation SMMessage

NSString *SMNoteFormatPreferenceKey = @"SMNoteFormat";
NSString *SMControllerFormatPreferenceKey = @"SMControllerFormat";
NSString *SMDataFormatPreferenceKey = @"SMDataFormat";
NSString *SMTimeFormatPreferenceKey = @"SMTimeFormat";

static UInt64 startHostTime;
static NSTimeInterval startTimeInterval;
static NSDateFormatter *timeStampDateFormatter;


+ (void)didLoad
{
    // Establish a base of what host time corresponds to what clock time.
    // TODO We should do this a few times and average the results, and also try to be careful not to get
    // scheduled out during this process. We may need to switch ourself to be a time-constraint thread temporarily
    // in order to do this. See discussion in the CoreAudio-API archives.
    startHostTime = SMGetCurrentHostTime();
    startTimeInterval = [NSDate timeIntervalSinceReferenceDate];

    timeStampDateFormatter = [[NSDateFormatter alloc] initWithDateFormat:@"%H:%M:%S.%F" allowNaturalLanguage:NO];
}

+ (NSString *)formatNoteNumber:(Byte)noteNumber;
{
    return [self formatNoteNumber:noteNumber usingOption:[[OFPreference preferenceForKey:SMNoteFormatPreferenceKey] integerValue]];
}

+ (NSString *)formatNoteNumber:(Byte)noteNumber usingOption:(SMNoteFormattingOption)option;
{
    switch (option) {
        case SMNoteFormatDecimal:
        default:
            return [NSString stringWithFormat:@"%d", noteNumber];

        case SMNoteFormatHexadecimal:
            return [NSString stringWithFormat:@"$%02X", noteNumber];

        case SMNoteFormatNameMiddleC3:
            // Middle C ==  60 == "C3", so base == 0 == "C-2"
            return _formatNoteNumberWithBaseOctave(noteNumber, -2);

        case SMNoteFormatNameMiddleC4:
            // Middle C == 60 == "C2", so base == 0 == "C-1" 
            return _formatNoteNumberWithBaseOctave(noteNumber, -1);
    }
}

+ (NSString *)formatControllerNumber:(Byte)controllerNumber;
{
    return [self formatControllerNumber:controllerNumber usingOption:[[OFPreference preferenceForKey:SMControllerFormatPreferenceKey] integerValue]];
}

+ (NSString *)formatControllerNumber:(Byte)controllerNumber usingOption:(SMControllerFormattingOption)option;
{
    switch (option) {
        case SMControllerFormatDecimal:
        default:
            return [NSString stringWithFormat:@"%d", controllerNumber];
            
        case SMControllerFormatHexadecimal:
            return [NSString stringWithFormat:@"$%02X", controllerNumber];

        case SMControllerFormatName:
            return [self nameForControllerNumber:controllerNumber];
    }
}

+ (NSString *)nameForControllerNumber:(Byte)controllerNumber;
{
    static NSMutableArray *controllerNames = nil;

    OBPRECONDITION(controllerNumber <= 127);
    
    if (!controllerNames) {
        NSString *path;
        NSDictionary *controllerNameDict = nil;
        NSString *unknownName;
        unsigned int controllerIndex;
        
        path = [[self bundle] pathForResource:@"ControllerNames" ofType:@"plist"];
        if (path) {        
            controllerNameDict = [NSDictionary dictionaryWithContentsOfFile:path];
            if (!controllerNameDict)
                NSLog(@"Couldn't read ControllerNames.plist!");
        } else {
            NSLog(@"Couldn't find ControllerNames.plist!");
        }

        // It's lame that property lists must have keys which are strings. We would prefer an integer, in this case.
        // We could create a new string for the controllerNumber and look that up in the dictionary, but that gets expensive to do all the time.
        // Instead, we just scan through the dictionary once, and build an NSArray which is quicker to index into.

        unknownName = NSLocalizedStringFromTableInBundle(@"Controller %u", @"SnoizeMIDI", [self bundle], "format of unknown controller");

        controllerNames = [[NSMutableArray alloc] initWithCapacity:128];
        for (controllerIndex = 0; controllerIndex <= 127; controllerIndex++) {
            NSString *name;
            
            name = [controllerNameDict objectForKey:[NSString stringWithFormat:@"%u", controllerIndex]];
            if (!name)
                name = [NSString stringWithFormat:unknownName, controllerIndex];

            [controllerNames addObject:name];
        }        
    }

    return [controllerNames objectAtIndex:controllerNumber];
}

+ (NSString *)formatData:(NSData *)data;
{
    return [self formatDataBytes:[data bytes] length:[data length]];
}

+ (NSString *)formatDataBytes:(const Byte *)bytes length:(unsigned int)length;
{
    SMDataFormattingOption option;
    NSMutableString *string;
    unsigned int pos;
    
    option = [[OFPreference preferenceForKey:SMDataFormatPreferenceKey] integerValue];    
    string = [NSMutableString string];
    for (pos = 0; pos < length; pos++) {
        [string appendString:[self formatDataByte:*(bytes + pos) usingOption:option]];
        if (pos + 1 < length)
            [string appendString:@" "];
    }
    
    return string;
}

+ (NSString *)formatDataByte:(Byte)dataByte;
{
    return [self formatDataByte:dataByte usingOption:[[OFPreference preferenceForKey:SMDataFormatPreferenceKey] integerValue]];
}

+ (NSString *)formatDataByte:(Byte)dataByte usingOption:(SMDataFormattingOption)option;
{
    switch (option) {
        case SMDataFormatDecimal:
        default:
            return [NSString stringWithFormat:@"%d", dataByte];

        case SMDataFormatHexadecimal:
            return [NSString stringWithFormat:@"$%02X", dataByte];
    }
}

+ (NSString *)formatSignedDataByte1:(Byte)dataByte1 byte2:(Byte)dataByte2;
{
    return [self formatSignedDataByte1:dataByte1 byte2:dataByte2 usingOption:[[OFPreference preferenceForKey:SMDataFormatPreferenceKey] integerValue]];
}

+ (NSString *)formatSignedDataByte1:(Byte)dataByte1 byte2:(Byte)dataByte2 usingOption:(SMDataFormattingOption)option;
{
    // Combine two 7-bit values into one 14-bit value. Treat the result as signed, if displaying as decimal; 0x2000 is the center.
    int value;

    value = (int)dataByte1 + (((int)dataByte2) << 7);

    switch (option) {
        case SMDataFormatDecimal:
        default:
            return [NSString stringWithFormat:@"%d", value - 0x2000];

        case SMDataFormatHexadecimal:
            return [NSString stringWithFormat:@"$%04X", value];
    }
}

+ (NSString *)formatLength:(unsigned int)length;
{
    return [self formatLength:length usingOption:[[OFPreference preferenceForKey:SMDataFormatPreferenceKey] integerValue]];
}

+ (NSString *)formatLength:(unsigned int)length usingOption:(SMDataFormattingOption)option;
{
    switch (option) {
        case SMDataFormatDecimal:
        default:
            return [NSString stringWithFormat:@"%u", length];

        case SMDataFormatHexadecimal:
            return [NSString stringWithFormat:@"$%X", length];
    }
}

+ (NSString *)nameForManufacturerIdentifier:(NSData *)manufacturerIdentifierData;
{
    static NSDictionary *manufacturerNames = nil;
    NSString *identifierString, *name;

    OBPRECONDITION(manufacturerIdentifierData != nil);
    OBPRECONDITION([manufacturerIdentifierData length] >= 1);
    OBPRECONDITION([manufacturerIdentifierData length] <= 3);
    
    if (!manufacturerNames) {
        NSString *path;
        
        path = [[self bundle] pathForResource:@"ManufacturerNames" ofType:@"plist"];
        if (path) {        
            manufacturerNames = [NSDictionary dictionaryWithContentsOfFile:path];
            if (!manufacturerNames)
                NSLog(@"Couldn't read ManufacturerNames.plist!");
        } else {
            NSLog(@"Couldn't find ManufacturerNames.plist!");
        }
        
        if (!manufacturerNames)
            manufacturerNames = [NSDictionary dictionary];
        [manufacturerNames retain];
    }

    identifierString = [manufacturerIdentifierData unadornedLowercaseHexString];
    if ((name = [manufacturerNames objectForKey:identifierString]))
        return name;
    else
        return NSLocalizedStringFromTableInBundle(@"Unknown Manufacturer", @"SnoizeMIDI", [self bundle], "unknown manufacturer name");
}

+ (NSString *)formatTimeStamp:(MIDITimeStamp)aTimeStamp;
{
    return [self formatTimeStamp:aTimeStamp usingOption:[[OFPreference preferenceForKey:SMTimeFormatPreferenceKey] integerValue]];
}

+ (NSString *)formatTimeStamp:(MIDITimeStamp)aTimeStamp usingOption:(SMTimeFormattingOption)option;
{
    switch (option) {
        case SMTimeFormatHostTimeInteger:
        {
            // We have 2^64 possible values, which comes out to 1.8e19. So we need at most 20 digits. (Add one for the trailing \0.)
            char buf[21];
            
            snprintf(buf, sizeof(buf), "%llu", aTimeStamp);
            return [NSString stringWithCString:buf];
        }

        case SMTimeFormatHostTimeHexInteger:
        {
            // 64 bits at 4 bits/character = 16 characters max. (Add one for the trailing \0.)
            char buf[17];
            
            snprintf(buf, sizeof(buf), "%016llX", aTimeStamp);
            return [NSString stringWithCString:buf];
        }

        case SMTimeFormatHostTimeNanoseconds:
        {
            char buf[21];
            
            snprintf(buf, 21, "%llu", SMConvertHostTimeToNanos(aTimeStamp));
            return [NSString stringWithCString:buf];
        }

        case SMTimeFormatHostTimeSeconds:
            return [NSString stringWithFormat:@"%.3lf", SMConvertHostTimeToNanos(aTimeStamp) / 1.0e9];

        case SMTimeFormatClockTime:
        default:
        {
            if (aTimeStamp == 0) {
                return NSLocalizedStringFromTableInBundle(@"*** ZERO ***", @"SnoizeMIDI", [self bundle], "zero timestamp formatted as clock time");
            } else {
                NSTimeInterval timeStampInterval;
                NSDate *date;
                    
                timeStampInterval = SMConvertHostTimeToNanos(aTimeStamp - startHostTime) / 1.0e9;
                date = [NSDate dateWithTimeIntervalSinceReferenceDate:(startTimeInterval + timeStampInterval)];
                return [timeStampDateFormatter stringForObjectValue:date];
            }
        }
    }
}

- (id)initWithTimeStamp:(MIDITimeStamp)aTimeStamp statusByte:(Byte)aStatusByte
{
    // Designated initializer

    if (!(self = [super init]))
        return nil;

    timeStamp = aTimeStamp;
    statusByte = aStatusByte;
        
    return self;
}

- (id)init
{
    // Use the designated initializer instead
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc;
{
    [originatingEndpoint release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone;
{
    SMMessage *newMessage;
    
    newMessage = [[[self class] allocWithZone:zone] initWithTimeStamp:timeStamp statusByte:statusByte];
    [newMessage setOriginatingEndpoint:originatingEndpoint];
    return newMessage;
}

- (MIDITimeStamp)timeStamp
{
    return timeStamp;
}

- (void)setTimeStamp:(MIDITimeStamp)newTimeStamp
{
    timeStamp = newTimeStamp;
}

- (void)setTimeStampToNow;
{
    [self setTimeStamp:SMGetCurrentHostTime()];
}

- (Byte)statusByte
{
    return statusByte;
}

- (SMMessageType)messageType;
{
    // Must be implemented by subclasses
    OBRejectUnusedImplementation(self, _cmd);
    return SMMessageTypeUnknown;
}

- (BOOL)matchesMessageTypeMask:(SMMessageType)mask;
{
    return ([self messageType] & mask) ? YES : NO;
}

- (unsigned int)otherDataLength;
{
    // Subclasses must override if they have other data
    return 0;
}

- (const Byte *)otherDataBuffer;
{
    // Subclasses must override if they have other data
    return NULL;
}

- (NSData *)otherData
{
    unsigned int length;

    if ((length = [self otherDataLength]))
        return [NSData dataWithBytes:[self otherDataBuffer] length:length];
    else
        return nil;
}

- (SMEndpoint *)originatingEndpoint;
{
    return originatingEndpoint;
}

- (void)setOriginatingEndpoint:(SMEndpoint *)value;
{
    if (originatingEndpoint != value) {
        [originatingEndpoint release];
        originatingEndpoint = [value retain];
    }
}

//
// Display methods
//

- (NSString *)timeStampForDisplay;
{
    return [SMMessage formatTimeStamp:timeStamp];
}

- (NSString *)typeForDisplay;
{
    return [NSString stringWithFormat:@"%@ ($%02X)", NSLocalizedStringFromTableInBundle(@"Unknown", @"SnoizeMIDI", [self bundle], "displayed type of unknown MIDI status byte"), [self statusByte]];
}

- (NSString *)channelForDisplay;
{
    return nil;
}

- (NSString *)dataForDisplay;
{
    return [SMMessage formatData:[self otherData]];
}

@end


@implementation SMMessage (Private)

static NSString *_formatNoteNumberWithBaseOctave(Byte noteNumber, int octave)
{
    // noteNumber 0 is note C in octave provided (should be -2 or -1)

    static char *noteNames[] = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};

    return [NSString stringWithFormat:@"%s%d", noteNames[noteNumber % 12], octave + noteNumber / 12];
}

@end
