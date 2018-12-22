//
//  SMShowControlMessage.m
//  SnoizeMIDI
//
//  Created by Hugo Trippaers on 11/12/2018.
//

#import "SMShowControlMessage.h"

#import "SMUtilities.h"
#import "SMShowControlUtilities.h"

typedef NS_ENUM(NSInteger, SMShowControlDataType) {
    unknown = 1,                  // Yet undefined data
    cue = 2,                      // optional Cue, optional List, optional Path
    cue_with_timecode = 3,        // timecode, optional Cue, optional List, optional Path
    no_data = 4,                  // No additional data
    set_control = 5,              // Specific for SET
    fire_macro = 6,               // Specific for FIRE
    cue_list = 7,                 // Cue List
    cue_path = 8,                 // Cue Path
    cue_list_with_timecode = 9    // timecode optional Cue list
};

@implementation SMShowControlMessage : SMSystemExclusiveMessage

+ (SMShowControlMessage *)showControlMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp data:(NSData *)aData
{
    SMShowControlMessage *message;
    
    message = [[[SMShowControlMessage alloc] initWithTimeStamp:aTimeStamp statusByte:0xF0] autorelease];
    [message setData:aData];
    [message parseShowControl:aData];
    
    return message;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:data forKey:@"data"];
    [coder encodeBool:[self wasReceivedWithEOX] forKey:@"wasReceivedWithEOX"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super initWithCoder:decoder])) {
        id obj = [decoder decodeObjectForKey:@"data"];
        if (obj && [obj isKindOfClass:[NSData class]]) {
            data = [obj retain];
        } else {
            goto fail;
        }

        [self setWasReceivedWithEOX:[decoder decodeBoolForKey:@"wasReceivedWithEOX"]];
        [self parseShowControl:data];
    }
    
    return self;
    
fail:
    [self release];
    return nil;
}

- (NSString *)typeForDisplay;
{
    return NSLocalizedStringFromTableInBundle(@"Show Control", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of System Exclusive Show Control event");
}

- (NSString *)dataForDisplay;
{
    NSString *dataString = [self expertDataForDisplay];
    
    NSMutableString *result = [NSMutableString string];

    NSString *command = [SMShowControlMessage nameForShowControlCommand:mscCommand];
    [result appendString:command];
    
    SMShowControlDataType dataType = [SMShowControlMessage dataTypeForCommand:mscCommand];
    
    int hdrSize = 5;
    NSData *data = [self otherData];
    NSData *parameterData = [NSData dataWithBytes:(data.bytes + hdrSize) length:data.length - hdrSize];
    
    if (dataType == cue) {
        NSString *cueList = [SMShowControlMessage parseCue:parameterData];
        if ([cueList length] > 0) {
                [result appendFormat:@" %@", cueList];
        }
    } else if (dataType == cue_with_timecode) {
        NSData *cueBytes = [NSData dataWithBytes:(parameterData.bytes + 5) length:parameterData.length - 5];
        NSString *cueList = [SMShowControlMessage parseCue:cueBytes];
        if ([cueList length] > 0) {
            [result appendFormat:@" %@", cueList];
        }
        
        [result appendString:@" @ "];
        
        NSData *timecodeBytes = [NSData dataWithBytes:parameterData.bytes length:5];
        [result appendString:[SMShowControlMessage parseTimecode:timecodeBytes]];
    } else if (dataType == cue_path) {
        NSString *cueList = [SMShowControlMessage parseCuePath:parameterData];
        if ([cueList length] > 0) {
            [result appendFormat:@" %@", cueList];
        }
    } else if (dataType == cue_list) {
        NSString *cueList = [SMShowControlMessage parseCueList:parameterData];
        if ([cueList length] > 0) {
            [result appendFormat:@" %@", cueList];
        }
    } else if (dataType == cue_list_with_timecode) {
        NSData *timecodeBytes = [NSData dataWithBytes:parameterData.bytes length:5];
        [result appendString:@" "];
        [result appendString:[SMShowControlMessage parseTimecode:timecodeBytes]];

        NSData *cueBytes = [NSData dataWithBytes:(parameterData.bytes + 5) length:parameterData.length - 5];
        NSString *cueList = [SMShowControlMessage parseCueList:cueBytes];
        if ([cueList length] > 0) {
            [result appendFormat:@" for %@", cueList];
        }
    } else if (dataType == set_control) {
        // 14 bit number (two bytes with 7 bit LSB first)
        uint16 control = *(uint8 *)parameterData.bytes | *((uint8 *)parameterData.bytes + 1) << 7;
        uint16 value = *((uint8 *)parameterData.bytes + 2) | *((uint8 *)parameterData.bytes + 3) << 7;
        
        [result appendFormat:@" Control %d to value %d", control, value];
        if ([parameterData length] == 10) {
            // Timecode included
            NSData *timecodeBytes = [NSData dataWithBytes:(parameterData.bytes + 4) length:5];
            [result appendString:@" @ "];
            [result appendString:[SMShowControlMessage parseTimecode:timecodeBytes]];
        }
    } else if (dataType == fire_macro) {
        // one 7 bit macro number
        [result appendFormat:@" Macro %d", *(Byte *)parameterData.bytes];
    } else if (dataType == unknown){
        if (dataString) {
            if (result.length > 0) {
                [result appendString:@"\t"];
            }
            [result appendString:dataString];
        }
    }
    
    return result;
}

- (void)setData:(NSData *)newData;
{
    if (data != newData) {
        [data release];
        data = [newData retain];
        
        [cachedDataWithEOX release];
        cachedDataWithEOX = nil;
    }
}

- (void)parseShowControl:(NSData *)newData;
{
    mscCommand = (((Byte *)newData.bytes)[4]);
}

+ (NSString *)nameForShowControlCommand:(Byte)mscCommand;
{
    static NSDictionary *showControlCommands = nil;
    NSString *identifierString, *name;
    
    if (!showControlCommands) {
        NSString *path;
        
        path = [SMBundleForObject(self) pathForResource:@"ShowControlCommandNames" ofType:@"plist"];
        if (path) {
            showControlCommands = [NSDictionary dictionaryWithContentsOfFile:path];
            if (!showControlCommands)
                NSLog(@"Couldn't read ShowControlCommandNames.plist!");
        } else {
            NSLog(@"Couldn't find ShowControlCommandNames.plist!");
        }
        
        if (!showControlCommands)
            showControlCommands = [NSDictionary dictionary];
        [showControlCommands retain];
    }
    
    identifierString = [NSString stringWithFormat:@"%X", mscCommand];
    if ((name = [showControlCommands objectForKey:identifierString]))
        return name;
    else
        return NSLocalizedStringFromTableInBundle(@"Unknown Command", @"SnoizeMIDI", SMBundleForObject(self), "unknown command name");
}

+ (SMShowControlDataType)dataTypeForCommand:(Byte)mscCommand;
{
    switch(mscCommand) {
        case 0x01:
        case 0x02:
        case 0x03:
        case 0x05:
        case 0x0B:
        case 0x10:
            return cue;
        case 0x04:
            return cue_with_timecode;
        case 0x08:
        case 0x09:
        case 0x0A:
            return no_data;
        case 0x06:
            return set_control;
        case 0x07:
            return fire_macro;
        case 0x11:
        case 0x12:
        case 0x13:
        case 0x14:
        case 0x15:
        case 0x16:
        case 0x17:
        case 0x19:
        case 0x1A:
        case 0x1B:
        case 0x1C:
            return cue_list;
        case 0x1D:
        case 0x1E:
            return cue_path;
        case 0x18:
            return cue_list_with_timecode;
        default:
            return unknown;
    }
}

+ (NSString *)parseCue:(NSData *)data;
{
    NSMutableString *result = [NSMutableString string];
    
    NSArray *items = parseCueItemsBytes(data);
    if ([items count] >= 1) {
        [result appendFormat:@"Cue %@", [items objectAtIndex:0]];
    }
    if ([items count] >= 2) {
        [result appendFormat:@", List %@", [items objectAtIndex:1]];
    }
    if ([items count] == 3) {
        [result appendFormat:@", Path %@", [items objectAtIndex:2]];
    }
    
    return result;
}

+ (NSString *)parseCueList:(NSData *)data;
{
    NSMutableString *result = [NSMutableString string];
    
    NSArray *items = parseCueItemsBytes(data);
    if ([items count] >= 1) {
        [result appendFormat:@"Cue List %@", [items objectAtIndex:0]];
    }
    
    return result;
}

+ (NSString *)parseCuePath:(NSData *)data;
{
    NSMutableString *result = [NSMutableString string];
    
    NSArray *items = parseCueItemsBytes(data);
    if ([items count] >= 1) {
        [result appendFormat:@"Cue Path %@", [items objectAtIndex:0]];
    }
    
    return result;
}

+ (NSString *)parseTimecode:(NSData *)data;
{
    NSMutableString *result = [NSMutableString string];
    
    Timecode timecode = parseTimecodeBytes(data);
    
    [result appendFormat:@"%d:%02d:%02d:%02d", timecode.hours, timecode.minutes, timecode.seconds, timecode.frames];
    if (timecode.form == 0) {
        [result appendFormat:@"/%02d", timecode.subframes];
    }
    
    switch (timecode.timecodeType) {
       case 0:
            [result appendString:@" (24 fps)"];
            break;
        case 1:
            [result appendString:@" (25 fps)"];
            break;
        case 2:
            [result appendString:@" (30 fps/drop)"];
            break;
        case 3:
            [result appendString:@" (30 fps/non-drop)"];
            break;
        default:
            [result appendString:@" (unknown)"];
    }
    
    return result;
}

@end
