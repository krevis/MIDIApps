//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <SnoizeMIDI/SMMessage.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


@interface SMSystemExclusiveMessage : SMMessage
    // TODO Should this be a SMSystemCommonMessage too? Would we gain anything from that?
{
    NSData *data;
    // data does not include the starting 0xF0 or the ending 0xF7 (EOX)
    
    struct {
        unsigned int wasReceivedWithEOX:1;
    } flags;

    NSMutableData *cachedDataWithEOX;
}

+ (SMSystemExclusiveMessage *)systemExclusiveMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp data:(NSData *)aData;
    // data should NOT include the starting 0xF0 or the ending 0xF7 (EOX)

+ (NSArray *)systemExclusiveMessagesInData:(NSData *)someData;
+ (NSArray *)systemExclusiveMessagesInStandardMIDIFile:(NSString *)path;

+ (NSData *)dataForSystemExclusiveMessages:(NSArray *)messages;
+ (BOOL)writeSystemExclusiveMessages:(NSArray *)messages toStandardMIDIFile:(NSString *)path;

    // Data without the starting 0xF0 or the ending 0xF7 (if any)
- (NSData *)data;
- (void)setData:(NSData *)newData;

- (BOOL)wasReceivedWithEOX;
- (void)setWasReceivedWithEOX:(BOOL)value;

    // Data without the starting 0xF0, always with ending 0xF7
- (NSData *)otherData;
- (unsigned int)otherDataLength;

    // Data as received, without starting 0xF0 -- may or may not include 0xF7
- (NSData *)receivedData;
- (unsigned int)receivedDataLength;

    // Data as received, with 0xF0 at start -- may or may not include 0xF7
- (NSData *)receivedDataWithStartByte;
- (unsigned int)receivedDataWithStartByteLength;

    // Data with leading 0xF0 and ending 0xF7
- (NSData *)fullMessageData;
- (unsigned int)fullMessageDataLength;

- (NSData *)manufacturerIdentifier;
    // May be 1 to 3 bytes in length, or nil if a value can't be determined
- (NSString *)manufacturerName;

- (NSString *)sizeForDisplay;
    // "<receivedDataWithStartByteLength> bytes"

@end
