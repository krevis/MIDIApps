/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMMessage.h"

#import "SMMessageTimeBase.h"
#import "SMEndpoint.h"
#import "SMHostTime.h"
#import "SMUtilities.h"
#import "NSData-SMExtensions.h"


@interface SMMessage (Private)

static NSString *formatNoteNumberWithBaseOctave(Byte noteNumber, int octave);

- (void)_setTimeStamp:(MIDITimeStamp)aTimeStamp;

@end


@implementation SMMessage

NSString *SMNoteFormatPreferenceKey = @"SMNoteFormat";
NSString *SMControllerFormatPreferenceKey = @"SMControllerFormat";
NSString *SMDataFormatPreferenceKey = @"SMDataFormat";
NSString *SMTimeFormatPreferenceKey = @"SMTimeFormat";
NSString *SMExpertModePreferenceKey = @"SMExpertMode";

+ (NSString *)formatNoteNumber:(Byte)noteNumber;
{
    return [self formatNoteNumber:noteNumber usingOption:(SMNoteFormattingOption)[[NSUserDefaults standardUserDefaults] integerForKey:SMNoteFormatPreferenceKey]];
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
            return formatNoteNumberWithBaseOctave(noteNumber, -2);

        case SMNoteFormatNameMiddleC4:
            // Middle C == 60 == "C2", so base == 0 == "C-1" 
            return formatNoteNumberWithBaseOctave(noteNumber, -1);
    }
}

+ (NSString *)formatControllerNumber:(Byte)controllerNumber;
{
    return [self formatControllerNumber:controllerNumber usingOption:(SMControllerFormattingOption)[[NSUserDefaults standardUserDefaults] integerForKey:SMControllerFormatPreferenceKey]];
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

    SMAssert(controllerNumber <= 127);
    
    if (!controllerNames) {
        NSString *path;
        NSDictionary *controllerNameDict = nil;
        NSString *unknownName;
        unsigned int controllerIndex;
        
        path = [SMBundleForObject(self) pathForResource:@"ControllerNames" ofType:@"plist"];
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

        unknownName = NSLocalizedStringFromTableInBundle(@"Controller %u", @"SnoizeMIDI", SMBundleForObject(self), "format of unknown controller");

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

+ (NSString *)formatDataBytes:(const Byte *)bytes length:(NSUInteger)length;
{
    SMDataFormattingOption option;
    NSMutableString *string;
    NSUInteger pos;

    option = (SMDataFormattingOption)[[NSUserDefaults standardUserDefaults] integerForKey:SMDataFormatPreferenceKey];
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
    return [self formatDataByte:dataByte usingOption:(SMDataFormattingOption)[[NSUserDefaults standardUserDefaults] integerForKey:SMDataFormatPreferenceKey]];
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
    return [self formatSignedDataByte1:dataByte1 byte2:dataByte2 usingOption:(SMDataFormattingOption)[[NSUserDefaults standardUserDefaults] integerForKey:SMDataFormatPreferenceKey]];
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

+ (NSString *)formatLength:(NSUInteger)length;
{
    return [self formatLength:length usingOption:(SMDataFormattingOption)[[NSUserDefaults standardUserDefaults] integerForKey:SMDataFormatPreferenceKey]];
}

+ (NSString *)formatLength:(NSUInteger)length usingOption:(SMDataFormattingOption)option;
{
    switch (option) {
        case SMDataFormatDecimal:
        default:
            return [NSString stringWithFormat:@"%lu", (unsigned long)length];

        case SMDataFormatHexadecimal:
            return [NSString stringWithFormat:@"$%lX", (unsigned long)length];
    }
}

+ (NSString *)formatExpertStatusByte:(Byte)statusByte andOtherData:(NSData *)otherData
{
    NSMutableString *result = [NSMutableString string];

    [result appendFormat:@"%02X", statusByte];

    if (otherData.length) {
        const unsigned char *bytes = otherData.bytes;
        NSUInteger i;
        NSUInteger length = otherData.length;
        for (i = 0; i < 31 && i < length; i++) {
            [result appendFormat:@" %02X", bytes[i]];
        }
        if (i < length) {
            [result appendString:@"…"];
        }
    }

    return result;
}

+ (NSString *)nameForManufacturerIdentifier:(NSData *)manufacturerIdentifierData;
{
    static NSDictionary *manufacturerNames = nil;
    NSString *identifierString, *name;

    SMAssert(manufacturerIdentifierData != nil);
    SMAssert([manufacturerIdentifierData length] >= 1);
    SMAssert([manufacturerIdentifierData length] <= 3);
    
    if (!manufacturerNames) {
        NSString *path;
        
        path = [SMBundleForObject(self) pathForResource:@"ManufacturerNames" ofType:@"plist"];
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

    identifierString = [manufacturerIdentifierData SnoizeMIDI_lowercaseHexString];
    if ((name = [manufacturerNames objectForKey:identifierString]))
        return name;
    else
        return NSLocalizedStringFromTableInBundle(@"Unknown Manufacturer", @"SnoizeMIDI", SMBundleForObject(self), "unknown manufacturer name");
}

- (id)initWithTimeStamp:(MIDITimeStamp)aTimeStamp statusByte:(Byte)aStatusByte
{
    // Designated initializer

    if (!(self = [super init]))
        return nil;

    [self _setTimeStamp:aTimeStamp];
    timeBase = [[SMMessageTimeBase currentTimeBase] retain];
    statusByte = aStatusByte;
        
    return self;
}

- (id)init
{
    // Use the designated initializer instead
    SMRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [timeBase release];
    [originatingEndpointOrName release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone;
{
    SMMessage *newMessage;
    
    newMessage = [[[self class] allocWithZone:zone] initWithTimeStamp:timeStamp statusByte:statusByte];
    [newMessage->timeBase release];
    newMessage->timeBase = [timeBase retain];
    newMessage->originatingEndpointOrName = [originatingEndpointOrName retain];
    return newMessage;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    UInt64 nanos = SMConvertHostTimeToNanos(timeStamp);
    [coder encodeInt64:nanos forKey:@"timeStampInNanos"];
    [coder encodeBool:timeStampWasZeroWhenReceived forKey:@"timeStampWasZeroWhenReceived"];
    
    [coder encodeInt64:(timeStampWasZeroWhenReceived ? 0 : timeStamp) forKey:@"timeStamp"];
        // for backwards compatibility

    [coder encodeObject:timeBase forKey:@"timeBase"];
    [coder encodeInt:statusByte forKey:@"statusByte"];
    [coder encodeObject:[self originatingEndpointForDisplay] forKey:@"originatingEndpoint"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super init])) {
        if ([decoder containsValueForKey:@"timeStampInNanos"]) {
            UInt64 nanos = [decoder decodeInt64ForKey:@"timeStampInNanos"];
            timeStamp = SMConvertNanosToHostTime(nanos);
            timeStampWasZeroWhenReceived = [decoder decodeBoolForKey:@"timeStampWasZeroWhenReceived"];
        } else {
            // fall back to old, inaccurate method
            // (we stored HostTime but not the ratio to convert it to nanoseconds)
            timeStamp = [decoder decodeInt64ForKey:@"timeStamp"];
            timeStampWasZeroWhenReceived = (timeStamp == 0);
        }

        id maybeTimeBase = [decoder decodeObjectForKey:@"timeBase"];
        if ([maybeTimeBase isKindOfClass:[SMMessageTimeBase class]]) {
            timeBase = [maybeTimeBase retain];            
        } else {
            goto fail;
        }
        
        statusByte = [decoder decodeIntForKey:@"statusByte"];
        
        id endpointName = [decoder decodeObjectForKey:@"originatingEndpoint"];
        if ([endpointName isKindOfClass:[NSString class]]) {
            originatingEndpointOrName = [endpointName copy];
        } else {
            goto fail;
        }
    }
    
    return self;
    
fail:
    [self release];
    return nil;
}

- (MIDITimeStamp)timeStamp
{
    return timeStamp;
}

- (void)setTimeStamp:(MIDITimeStamp)newTimeStamp
{
    [self _setTimeStamp:newTimeStamp];
}

- (Byte)statusByte
{
    return statusByte;
}

- (SMMessageType)messageType;
{
    // Must be implemented by subclasses
    SMRejectUnusedImplementation(self, _cmd);
    return SMMessageTypeUnknown;
}

- (BOOL)matchesMessageTypeMask:(SMMessageType)mask;
{
    return ([self messageType] & mask) ? YES : NO;
}

- (NSUInteger)otherDataLength;
{
    // Subclasses must override if they have other data
    return 0;
}

- (const Byte *)otherDataBuffer
{
    // Subclasses must override if they have other data
    return NULL;
}

- (NSData *)otherData
{
    NSUInteger length;

    if ((length = [self otherDataLength]))
        return [NSData dataWithBytes:[self otherDataBuffer] length:length];
    else
        return nil;
}

- (SMEndpoint *)originatingEndpoint
{
    return [originatingEndpointOrName isKindOfClass:[SMEndpoint class]] ? (SMEndpoint*)originatingEndpointOrName : nil;
}

- (void)setOriginatingEndpoint:(SMEndpoint *)value
{
    if (originatingEndpointOrName != value) {
        [originatingEndpointOrName release];
        originatingEndpointOrName = [value retain];
    }
}

//
// Display methods
//

- (NSString *)timeStampForDisplay;
{
    SMTimeFormattingOption option = (SMTimeFormattingOption)[[NSUserDefaults standardUserDefaults] integerForKey:SMTimeFormatPreferenceKey];
    
    BOOL displayZero = timeStampWasZeroWhenReceived && [[NSUserDefaults standardUserDefaults] boolForKey:SMExpertModePreferenceKey];
    MIDITimeStamp displayTimeStamp = displayZero ? 0 : timeStamp;
    
    switch (option) {
        case SMTimeFormatHostTimeInteger:
        {
            // We have 2^64 possible values, which comes out to 1.8e19. So we need at most 20 digits. (Add one for the trailing \0.)
            char buf[21];
            
            snprintf(buf, sizeof(buf), "%llu", displayTimeStamp);
            return [NSString stringWithUTF8String:buf];
        }
            
        case SMTimeFormatHostTimeHexInteger:
        {
            // 64 bits at 4 bits/character = 16 characters max. (Add one for the trailing \0.)
            char buf[17];
            
            snprintf(buf, sizeof(buf), "%016llX", displayTimeStamp);
            return [NSString stringWithUTF8String:buf];
        }
            
        case SMTimeFormatHostTimeNanoseconds:
        {
            char buf[21];
            
            snprintf(buf, 21, "%llu", SMConvertHostTimeToNanos(displayTimeStamp));
            return [NSString stringWithUTF8String:buf];
        }
            
        case SMTimeFormatHostTimeSeconds:
            return [NSString stringWithFormat:@"%.3lf", SMConvertHostTimeToNanos(displayTimeStamp) / 1.0e9];
            
        case SMTimeFormatClockTime:
        default:
        {
            if (displayZero) {
                return @"0";
            } else {
                static NSDateFormatter *timeStampDateFormatter = nil;
                if (!timeStampDateFormatter) {
                    timeStampDateFormatter = [[NSDateFormatter alloc] init];
                    [timeStampDateFormatter setDateFormat:@"HH:mm:ss.SSS"];
                }

                UInt64 timeStampInNanos = SMConvertHostTimeToNanos(displayTimeStamp);
                UInt64 hostTimeBaseInNanos = [timeBase hostTimeInNanos];
                SInt64 timeDelta = timeStampInNanos - hostTimeBaseInNanos;  // may be negative!
                NSTimeInterval timeStampInterval = timeDelta / 1.0e9;
                NSDate* date = [NSDate dateWithTimeIntervalSinceReferenceDate:([timeBase timeInterval] + timeStampInterval)];
                return [timeStampDateFormatter stringForObjectValue:date];
            }
        }
    }
}

- (NSString *)typeForDisplay;
{
    return [NSString stringWithFormat:@"%@ ($%02X)", NSLocalizedStringFromTableInBundle(@"Unknown", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of unknown MIDI status byte"), [self statusByte]];
}

- (NSString *)channelForDisplay;
{
    return @"";
}

- (NSString *)dataForDisplay;
{
    return [SMMessage formatData:[self otherData]];
}

- (NSString *)expertDataForDisplay
{
    return [SMMessage formatExpertStatusByte:self.statusByte andOtherData:self.otherData];
}

- (NSString *)originatingEndpointForDisplay
{
    SMEndpoint *endpoint;
    
    if ((endpoint = [self originatingEndpoint])) {
        static NSString *kFromString = nil;
        static NSString *kToString = nil;
        
        if (!kFromString)
            kFromString = [NSLocalizedStringFromTableInBundle(@"From", @"SnoizeMIDI", SMBundleForObject(self), "Prefix for endpoint name when it's a source") retain];
        if (!kToString)
            kToString = [NSLocalizedStringFromTableInBundle(@"To", @"SnoizeMIDI", SMBundleForObject(self), "Prefix for endpoint name when it's a destination") retain];
        
        NSString* fromOrTo = ([endpoint isKindOfClass:[SMSourceEndpoint class]] ? kFromString : kToString);
        return [[fromOrTo stringByAppendingString:@" "] stringByAppendingString:[endpoint alwaysUniqueName]];
    } else if ([originatingEndpointOrName isKindOfClass:[NSString class]]) {
        return (NSString*)originatingEndpointOrName;
    } else {
        return @"";
    }
}

@end


@implementation SMMessage (Private)

static NSString *formatNoteNumberWithBaseOctave(Byte noteNumber, int octave)
{
    // noteNumber 0 is note C in octave provided (should be -2 or -1)

	static NSArray *noteNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		noteNames = [[NSArray alloc] initWithObjects:@"C", @"C♯", @"D", @"D♯", @"E", @"F", @"F♯", @"G", @"G♯", @"A", @"A♯", @"B", nil];
    });
	
    return [NSString stringWithFormat:@"%@%d", [noteNames objectAtIndex:(noteNumber % 12)], octave + noteNumber / 12];
}

- (void)_setTimeStamp:(MIDITimeStamp)newTimeStamp
{
    timeStampWasZeroWhenReceived = (newTimeStamp == 0);
    timeStamp = timeStampWasZeroWhenReceived ? SMGetCurrentHostTime() : newTimeStamp;
}

@end
