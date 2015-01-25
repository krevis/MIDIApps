#import "MessageParser.h"

typedef enum _SMSystemCommonMessageType {
    SMSystemCommonMessageTypeTimeCodeQuarterFrame = 0xF1,
    SMSystemCommonMessageTypeSongPositionPointer = 0xF2,
    SMSystemCommonMessageTypeSongSelect = 0xF3,
    SMSystemCommonMessageTypeTuneRequest = 0xF6
} SMSystemCommonMessageType;

typedef enum _SMSystemRealTimeMessageType {
    SMSystemRealTimeMessageTypeClock = 0xF8,
    SMSystemRealTimeMessageTypeStart = 0xFA,
    SMSystemRealTimeMessageTypeContinue = 0xFB,
    SMSystemRealTimeMessageTypeStop = 0xFC,
    SMSystemRealTimeMessageTypeActiveSense = 0xFE,
    SMSystemRealTimeMessageTypeReset = 0xFF
} SMSystemRealTimeMessageType;

@interface MessageParser ()

@property (nonatomic) NSMutableData *readingSysExData;

@end

@implementation MessageParser

- (void)takePacketList:(const MIDIPacketList *)packetList
{
    if (!packetList || !packetList->numPackets) {
        return;
    }

    NSMutableArray *messages = [NSMutableArray array];

    UInt32 packetCount = packetList->numPackets;
    const MIDIPacket *packet = packetList->packet;
    while (packetCount--) {
        NSArray *messagesForPacket = [self messagesForPacket:packet];
        if (messagesForPacket) {
            [messages addObjectsFromArray:messagesForPacket];
        }

        packet = MIDIPacketNext(packet);
    }

    if (messages.count) {
        [self.delegate parser:self didReadMessages:messages];
    }
}

#pragma mark Private

- (NSArray *)messagesForPacket:(const MIDIPacket *)packet
{
    // Split this packet into separate MIDI messages    
    NSMutableArray *messages = nil;
    const Byte *data;
    UInt16 length;
    Byte byte;
    Byte pendingMessageStatus;
    Byte pendingData[2];
    UInt16 pendingDataIndex, pendingDataLength;
    NSMutableData* readingInvalidData = nil;
    
    pendingMessageStatus = 0;
    pendingDataIndex = pendingDataLength = 0;

    data = packet->data;
    length = packet->length;
    while (length--) {
        NSString *message = nil;
        BOOL byteIsInvalid = NO;
        
        byte = *data++;
    
        if (byte >= 0xF8) {
            // Real Time message    
            switch (byte) {
                case SMSystemRealTimeMessageTypeClock:
                case SMSystemRealTimeMessageTypeStart:
                case SMSystemRealTimeMessageTypeContinue:
                case SMSystemRealTimeMessageTypeStop:
                case SMSystemRealTimeMessageTypeActiveSense:
                case SMSystemRealTimeMessageTypeReset:
                    message = [NSString stringWithFormat:@"SystemRealTime %02X", byte];
                    break;
        
                default:
                    // Byte is invalid
                    byteIsInvalid = YES;
                    break;
            }
        } else {
            if (byte < 0x80) {
                if (self.readingSysExData) {
                    [self.readingSysExData appendBytes:&byte length:1];
                } else if (pendingDataIndex < pendingDataLength) {
                    pendingData[pendingDataIndex] = byte;
                    pendingDataIndex++;

                    if (pendingDataIndex == pendingDataLength) {
                        // This message is now done--send it
                        if (pendingMessageStatus >= 0xF0) {
                            message = [NSString stringWithFormat:@"SystemCommon %02X %@", pendingMessageStatus, [self formatData:pendingData withLength:pendingDataLength]];
                        } else {
                            message = [NSString stringWithFormat:@"Voice %02X %@", pendingMessageStatus, [self formatData:pendingData withLength:pendingDataLength]];
                        }

                        pendingDataLength = 0;
                    }                    
                } else {
                    // Skip this byte -- it is invalid
                    byteIsInvalid = YES;
                }
            } else {
                if (self.readingSysExData) {
                    message = [self finishSysExMessageWithValidEnd:(byte == 0xF7)];
                }

                pendingMessageStatus = byte;
                pendingDataLength = 0;
                pendingDataIndex = 0;
                
                switch (byte & 0xF0) {            
                    case 0x80:	// Note off
                    case 0x90:	// Note on
                    case 0xA0:	// Aftertouch
                    case 0xB0:	// Controller
                    case 0xE0:	// Pitch wheel
                        pendingDataLength = 2;
                        break;
    
                    case 0xC0:	// Program change
                    case 0xD0:	// Channel pressure
                        pendingDataLength = 1;
                        break;
                    
                    case 0xF0: {
                        // System common message
                        switch (byte) {
                            case 0xF0:
                                // System exclusive
                                self.readingSysExData = [[NSMutableData alloc] init];
                                break;
                                
                            case 0xF7:
                                // System exclusive ends--already handled above.
                                // But if this is showing up outside of sysex, it's invalid.
                                if (!message) {
                                    byteIsInvalid = YES;
                                }
                                break;
                            
                            case SMSystemCommonMessageTypeTimeCodeQuarterFrame:
                            case SMSystemCommonMessageTypeSongSelect:
                                pendingDataLength = 1;
                                break;
    
                            case SMSystemCommonMessageTypeSongPositionPointer:
                                pendingDataLength = 2;
                                break;
    
                            case SMSystemCommonMessageTypeTuneRequest:
                                message = [NSString stringWithFormat:@"SystemCommon %02X", byte];
                                break;
                            
                            default:
                                // Invalid message
                                byteIsInvalid = YES;
                                break;
                        }                 
                        break;
                    }
                
                    default:
                        // This can't happen, but handle it anyway
                        byteIsInvalid = YES;
                        break;
                }
            }
        }

        if (byteIsInvalid) {
            if (!readingInvalidData) {
                readingInvalidData = [NSMutableData data];
            }
            [readingInvalidData appendBytes:&byte length:1];
        }

        if (readingInvalidData && (!byteIsInvalid || length == 0)) {
            // We hit the end of a stretch of invalid data.
            message = [NSString stringWithFormat:@"Invalid %@", [self formatData:readingInvalidData]];
            readingInvalidData = nil;
        }

        if (message) {
            if (!messages) {
                messages = [NSMutableArray arrayWithObject:message];
            } else {
                [messages addObject:message];
            }
        }
    }

    return messages;
}

- (NSString *)finishSysExMessageWithValidEnd:(BOOL)isEndValid
{
    NSString *message = nil;

    if (self.readingSysExData) {
        message = [NSString stringWithFormat:@"SysEx %@", [self formatData:self.readingSysExData]];
        self.readingSysExData = nil;
    }

    return message;
}

- (NSString *)formatData:(Byte *)data withLength:(UInt16)length
{
    if (!data) {
        return @"NULL";
    }

    NSMutableString *str = [NSMutableString string];
    for (UInt16 i = 0; i < length; i++) {
        [str appendFormat:@"%02X ", data[i]];
    }
    return str;
}

- (NSString *)formatData:(NSData *)data
{
    if (!data) {
        return @"(nil)";
    }

    Byte* bytes = (Byte *)data.bytes;
    if (!data) {
        return @"NSData with NULL bytes";
    }

    NSMutableString *str = [NSMutableString string];
    for (NSUInteger i = 0; i < data.length; i++) {
        [str appendFormat:@"%02X ", bytes[i]];
    }
    return str;
}

@end
