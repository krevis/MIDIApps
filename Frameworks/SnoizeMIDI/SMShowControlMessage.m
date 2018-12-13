//
//  SMShowControlMessage.m
//  SnoizeMIDI
//
//  Created by Hugo Trippaers on 11/12/2018.
//

#import "SMShowControlMessage.h"

#import "SMUtilities.h"

typedef NS_ENUM(NSInteger, SMShowControlDataType) {
    unknown = 1,                  // Yet undefined data
    cue_path = 2,                 // optional Cue, optional List, optional Path
    cue_path_with_timestamp = 3,  // timestamp, optional Cue, optional List, optional Path
    no_data = 4                   // No additional data
};

typedef struct {
    NSString *cueNumber;
    NSString *cueList;
    NSString *cuePath;
} Cue;

@interface SMShowControlMessage (Private)

+ (NSString *)nameForShowControlCommand:(Byte)mscCommand;

@end

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
    
    if (dataType == cue_path) {
        Cue cue = [SMShowControlMessage parseCue:[self otherData]];
        if (cue.cueNumber != nil) {
            [result appendFormat:@" Cue %@", cue.cueNumber];
        }
        if (cue.cueList != nil) {
            [result appendFormat:@", List %@", cue.cueList];
        }
        if (cue.cuePath != nil) {
            [result appendFormat:@", Path %@", cue.cuePath];
        }
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
            return cue_path;
        case 0x04:
            return cue_path_with_timestamp;
        case 0x08:
        case 0x09:
        case 0x0A:
            return no_data;
        default:
            return unknown;
    }
}

+ (Cue)parseCue:(NSData *)data;
{
    Cue parsedCue;
    parsedCue.cueList = nil;
    parsedCue.cueNumber = nil;
    parsedCue.cuePath = nil;
    
    const Byte *cueData = data.bytes + 5;
    if (*cueData == 0xF7) {
        // All empty
        return parsedCue;
    }
    
    NSMutableString *cueItem = [[NSMutableString alloc] init];
    while (cueData != data.bytes + [data length]) {
        Byte thingy = *cueData++;
        if (thingy == 0x0 || (thingy == 0xF7 && [cueItem length] > 0)) {
            if (parsedCue.cueNumber == nil) {
                parsedCue.cueNumber = [[NSString alloc] initWithString:cueItem];
            } else if (parsedCue.cueList == nil) {
                parsedCue.cueList = [[NSString alloc] initWithString:cueItem];
            } else {
                parsedCue.cuePath = [[NSString alloc] initWithString:cueItem];
            }
            cueItem = [[NSMutableString alloc] init];
        } else {
            [cueItem appendFormat:@"%c", thingy];
        }
    }
    
    return parsedCue;
}

@end
