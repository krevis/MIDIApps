#import <SnoizeMIDI/SMMessage.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


@interface SMSystemExclusiveMessage : SMMessage
    // TODO Should this be a SMSystemCommonMessage too? Would we gain anything from that?
{
    NSData *data;
    // data does not include the ending 0xF7 (EOX)
    
    struct {
        unsigned int wasReceivedWithEOX:1;
    } flags;

    // TODO An endTimeStamp might also be informative... since sysex messages can take a substantial amount of time to transmit.
    // But it would only be useful for incoming messages, not outgoing.
    // (Or perhaps the approximate "sending duration" could be computed based on the data size? that could work, but we'd have to
    // assume the MIDI transmission speed... which is probably reasonably safe since it hasn't changed yet.)

    NSMutableData *cachedDataWithEOX;
}

+ (SMSystemExclusiveMessage *)systemExclusiveMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp data:(NSData *)aData;
    // data should NOT include the ending 0xF7 (EOX)

+ (NSArray *)systemExclusiveMessagesInData:(NSData *)someData;
+ (NSArray *)systemExclusiveMessagesInStandardMIDIFile:(NSString *)path;

+ (NSData *)dataForSystemExclusiveMessages:(NSArray *)messages;
+ (BOOL)writeSystemExclusiveMessages:(NSArray *)messages toStandardMIDIFile:(NSString *)path;

- (NSData *)data;
- (void)setData:(NSData *)newData;

- (BOOL)wasReceivedWithEOX;
- (void)setWasReceivedWithEOX:(BOOL)value;

- (NSData *)receivedData;
    // Data as received -- may or may not include EOX
- (unsigned int)receivedDataLength;

- (NSData *)fullMessageData;
    // Data with leading 0xF0 and ending 0xF7
- (unsigned int)fullMessageDataLength;

- (NSData *)manufacturerIdentifier;
    // May be 1 to 3 bytes in length, or nil if a value can't be determined
- (NSString *)manufacturerName;

@end
