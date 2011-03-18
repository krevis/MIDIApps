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

@end


@implementation SMMessage

NSString *SMNoteFormatPreferenceKey = @"SMNoteFormat";
NSString *SMControllerFormatPreferenceKey = @"SMControllerFormat";
NSString *SMDataFormatPreferenceKey = @"SMDataFormat";
NSString *SMTimeFormatPreferenceKey = @"SMTimeFormat";

+ (NSString *)formatNoteNumber:(Byte)noteNumber;
{
    return [self formatNoteNumber:noteNumber usingOption:[[NSUserDefaults standardUserDefaults] integerForKey:SMNoteFormatPreferenceKey]];
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
    return [self formatControllerNumber:controllerNumber usingOption:[[NSUserDefaults standardUserDefaults] integerForKey:SMControllerFormatPreferenceKey]];
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

+ (NSString *)formatDataBytes:(const Byte *)bytes length:(unsigned int)length;
{
    SMDataFormattingOption option;
    NSMutableString *string;
    unsigned int pos;

    option = [[NSUserDefaults standardUserDefaults] integerForKey:SMDataFormatPreferenceKey];
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
    return [self formatDataByte:dataByte usingOption:[[NSUserDefaults standardUserDefaults] integerForKey:SMDataFormatPreferenceKey]];
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
    return [self formatSignedDataByte1:dataByte1 byte2:dataByte2 usingOption:[[NSUserDefaults standardUserDefaults] integerForKey:SMDataFormatPreferenceKey]];
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
    return [self formatLength:length usingOption:[[NSUserDefaults standardUserDefaults] integerForKey:SMDataFormatPreferenceKey]];
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

    timeStamp = aTimeStamp;
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
    [coder encodeInt64:timeStamp forKey:@"timeStamp"];
    [coder encodeObject:timeBase forKey:@"timeBase"];
    [coder encodeInt:statusByte forKey:@"statusByte"];
    [coder encodeObject:[self originatingEndpointForDisplay] forKey:@"originatingEndpoint"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super init])) {
        timeStamp = [decoder decodeInt64ForKey:@"timeStamp"]; 

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
    SMRejectUnusedImplementation(self, _cmd);
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

- (const Byte *)otherDataBuffer
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
    int option = [[NSUserDefaults standardUserDefaults] integerForKey:SMTimeFormatPreferenceKey];
    
    switch (option) {
        case SMTimeFormatHostTimeInteger:
        {
            // We have 2^64 possible values, which comes out to 1.8e19. So we need at most 20 digits. (Add one for the trailing \0.)
            char buf[21];
            
            snprintf(buf, sizeof(buf), "%llu", timeStamp);
            return [NSString stringWithUTF8String:buf];
        }
            
        case SMTimeFormatHostTimeHexInteger:
        {
            // 64 bits at 4 bits/character = 16 characters max. (Add one for the trailing \0.)
            char buf[17];
            
            snprintf(buf, sizeof(buf), "%016llX", timeStamp);
            return [NSString stringWithUTF8String:buf];
        }
            
        case SMTimeFormatHostTimeNanoseconds:
        {
            char buf[21];
            
            snprintf(buf, 21, "%llu", SMConvertHostTimeToNanos(timeStamp));
            return [NSString stringWithUTF8String:buf];
        }
            
        case SMTimeFormatHostTimeSeconds:
            return [NSString stringWithFormat:@"%.3lf", SMConvertHostTimeToNanos(timeStamp) / 1.0e9];
            
        case SMTimeFormatClockTime:
        default:
        {
            if (timeStamp == 0) {
                return NSLocalizedStringFromTableInBundle(@"*** ZERO ***", @"SnoizeMIDI", SMBundleForObject(self), "zero timestamp formatted as clock time");
            } else {
                static NSDateFormatter *timeStampDateFormatter = nil;
                if (!timeStampDateFormatter) {
                    timeStampDateFormatter = [[NSDateFormatter alloc] initWithDateFormat:@"%H:%M:%S.%F" allowNaturalLanguage:NO];
                }
                                
                NSTimeInterval timeStampInterval = SMConvertHostTimeToNanos(timeStamp - [timeBase hostTime]) / 1.0e9;
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

    static char *noteNames[] = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};

    return [NSString stringWithFormat:@"%s%d", noteNames[noteNumber % 12], octave + noteNumber / 12];
}

@end
