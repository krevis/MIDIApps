#import "SMMessageParser.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMMessage.h"
#import "SMVoiceMessage.h"
#import "SMSystemCommonMessage.h"
#import "SMSystemRealTimeMessage.h"
#import "SMSystemExclusiveMessage.h"


@interface SMMessageParser (Private)

- (NSArray *)_messagesForPacket:(const MIDIPacket *)packet;

@end


@implementation SMMessageParser

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    readingSysExLock = [[NSLock alloc] init];
    
    return self;
}

- (void)dealloc;
{
    [readingSysExData release];
    readingSysExData = nil;
    [readingSysExLock release];
    readingSysExLock = nil;
    
    nonretainedMessageDestination = nil;

    [super dealloc];
}

- (id<SMMessageDestination>)messageDestination;
{
    return nonretainedMessageDestination;
}

- (void)setMessageDestination:(id<SMMessageDestination>)aMessageDestination;
{
    nonretainedMessageDestination = aMessageDestination;
}

- (id)delegate;
{
    return nonretainedDelegate;
}

- (void)setDelegate:(id)value;
{
    nonretainedDelegate = value;
}

- (void)takePacketList:(const MIDIPacketList *)packetList;
{
    // NOTE: This function is called in a separate, "high-priority" thread.
    // All downstream processing will also be done in this thread, until someone jumps it into another.

    NSMutableArray *messages = nil;
    unsigned int packetCount;
    const MIDIPacket *packet;

    packetCount = packetList->numPackets;

    packet = packetList->packet;
    while (packetCount--) {
        NSArray *messagesForPacket;

        messagesForPacket = [self _messagesForPacket:packet];
        if (messagesForPacket) {
            if (!messages)
                messages = [NSMutableArray arrayWithArray:messagesForPacket];
            else
                [messages addObjectsFromArray:messagesForPacket];
        }

        packet = MIDIPacketNext(packet);
    }

    if (messages)
        [nonretainedMessageDestination takeMIDIMessages:messages];
}

- (BOOL)cancelReceivingSysExMessage;
{
    BOOL cancelled = NO;

    [readingSysExLock lock];

    if (readingSysExData) {
        [readingSysExData release];
        readingSysExData = nil;
        cancelled = YES;
    }

    [readingSysExLock unlock];

    return cancelled;
}

@end


@implementation SMMessageParser (Private)

- (NSArray *)_messagesForPacket:(const MIDIPacket *)packet;
{
    // Split this packet into separate MIDI messages    
    NSMutableArray *messages = nil;
    const Byte *data;
    UInt16 length;
    Byte byte;
    Byte pendingMessageStatus;
    Byte pendingData[2];
    UInt16 pendingDataIndex, pendingDataLength;
    
    pendingMessageStatus = 0;
    pendingDataIndex = pendingDataLength = 0;

    data = packet->data;
    length = packet->length;
    while (length--) {
        SMMessage *message = nil;
        
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
                    message = [SMSystemRealTimeMessage systemRealTimeMessageWithTimeStamp:packet->timeStamp type:byte];
                    break;
        
                default:
                    // Ignore unrecognized message
                    break;
            }
        } else {
            if (byte < 0x80) {
                if (readingSysExData) {
                    [readingSysExLock lock];
                    if (readingSysExData) {
                        unsigned int length;

                        [readingSysExData appendBytes:&byte length:1];

                        length = 1 + [readingSysExData length];
                        // Tell the delegate we're still reading, every 256 bytes
                        if (length % 256 == 0)
                            [nonretainedDelegate parser:self isReadingSysExWithLength:length];
                    }
                    [readingSysExLock unlock];
                } else if (pendingDataIndex < pendingDataLength) {
                    pendingData[pendingDataIndex] = byte;
                    pendingDataIndex++;

                    if (pendingDataIndex == pendingDataLength) {
                        // This message is now done--send it
                        if (pendingMessageStatus >= 0xF0)
                            message = [SMSystemCommonMessage systemCommonMessageWithTimeStamp:packet->timeStamp type:pendingMessageStatus data:pendingData length:pendingDataLength];
                        else
                            message = [SMVoiceMessage voiceMessageWithTimeStamp:packet->timeStamp statusByte:pendingMessageStatus data:pendingData length:pendingDataLength];

                        pendingDataLength = 0;
                    }                    
                } else {
                    // Skip this byte -- it is invalid
                }
            } else {
                if (readingSysExData) {
                    [readingSysExLock lock];
                    if (readingSysExData) {
                        // NOTE: If we want, we could refuse sysex messages that don't end in 0xF7.
                        // The MIDI spec says that messages should end with this byte, but apparently that is not always the case in practice.
                        BOOL wasValidEOX = (byte == 0xF7);
    
                        message = [SMSystemExclusiveMessage systemExclusiveMessageWithTimeStamp:startSysExTimeStamp data:readingSysExData];
                        [(SMSystemExclusiveMessage *)message setWasReceivedWithEOX:wasValidEOX];
                        [nonretainedDelegate parser:self finishedReadingSysExMessage:(SMSystemExclusiveMessage *)message];
    
                        [readingSysExData release];
                        readingSysExData = nil;
                    }
                    [readingSysExLock unlock];
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
                                readingSysExData = [[NSMutableData alloc] init];  // This is atomic, so there's no need to lock
                                startSysExTimeStamp = packet->timeStamp;
                                [nonretainedDelegate parser:self isReadingSysExWithLength:1];
                                break;
                                
                            case 0xF7:
                                // System exclusive ends--already handled
                                break;
                            
                            case SMSystemCommonMessageTypeTimeCodeQuarterFrame:
                            case SMSystemCommonMessageTypeSongSelect:
                                pendingDataLength = 1;
                                break;
    
                            case SMSystemCommonMessageTypeSongPositionPointer:
                                pendingDataLength = 2;
                                break;
    
                            case SMSystemCommonMessageTypeTuneRequest:
                                message = [SMSystemCommonMessage systemCommonMessageWithTimeStamp:packet->timeStamp type:byte data:NULL length:0];
                                break;
                            
                            default:
                                // Ignore this message
                                break;
                        }                 
                        break;
                    }
                
                    default:
                        // This can't happen
                        break;
                }
            }
        }

        if (message) {
            if (!messages)
                messages = [NSMutableArray arrayWithObject:message];
            else
                [messages addObject:message];
        }
    }

    return messages;
}

@end
