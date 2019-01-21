/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMMessageParser.h"

#import "SMMessage.h"
#import "SMVoiceMessage.h"
#import "SMSystemCommonMessage.h"
#import "SMSystemRealTimeMessage.h"
#import "SMSystemExclusiveMessage.h"
#import "SMInvalidMessage.h"


@interface SMMessageParser (Private)

- (NSArray *)messagesForPacket:(const MIDIPacket *)packet;

- (SMSystemExclusiveMessage *)finishSysExMessageWithValidEnd:(BOOL)isEndValid;
- (void)sysExTimedOut;

@end


@implementation SMMessageParser

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    sysExTimeOut = 1.0;	// seconds
    ignoreInvalidData = NO;

    return self;
}

- (void)dealloc;
{
    [readingSysExData release];
    readingSysExData = nil;
    [sysExTimeOutTimer invalidate];
    [sysExTimeOutTimer release];
    sysExTimeOutTimer = nil;
    
    [super dealloc];
}

- (id)delegate;
{
    return nonretainedDelegate;
}

- (void)setDelegate:(id)value;
{
    nonretainedDelegate = value;
}

- (SMEndpoint *)originatingEndpoint;
{
    return nonretainedOriginatingEndpoint;
}

- (void)setOriginatingEndpoint:(SMEndpoint *)value;
{
    nonretainedOriginatingEndpoint = value;
}

- (NSTimeInterval)sysExTimeOut;
{
    return sysExTimeOut;
}

- (void)setSysExTimeOut:(NSTimeInterval)value;
{
    sysExTimeOut = value;
}

- (BOOL)ignoresInvalidData
{
    return ignoreInvalidData;
}

- (void)setIgnoresInvalidData:(BOOL)value
{
    ignoreInvalidData = value;
}

- (void)takePacketList:(const MIDIPacketList *)packetList;
{
    NSMutableArray *messages = nil;
    UInt32 packetCount;
    const MIDIPacket *packet;
    
    packetCount = packetList->numPackets;
    packet = packetList->packet;
    while (packetCount--) {
        NSArray *messagesForPacket;

        messagesForPacket = [self messagesForPacket:packet];
        if (messagesForPacket) {
            if (!messages)
                messages = [NSMutableArray arrayWithArray:messagesForPacket];
            else
                [messages addObjectsFromArray:messagesForPacket];
        }

        packet = MIDIPacketNext(packet);
    }

    if (messages)
        [nonretainedDelegate parser:self didReadMessages:messages];
    
    if (readingSysExData) {
        if (!sysExTimeOutTimer) {
            // Create a timer which will fire after we have received no sysex data for a while.
            // This takes care of interruption in the data (devices being turned off or unplugged) as well as
            // ill-behaved devices which don't terminate their sysex messages with 0xF7.
            NSRunLoop *runLoop;
            NSString *mode;

            runLoop = [NSRunLoop currentRunLoop];
            mode = [runLoop currentMode];
            if (mode) {
                sysExTimeOutTimer = [[NSTimer timerWithTimeInterval:sysExTimeOut target:self selector:@selector(sysExTimedOut) userInfo:nil repeats:NO] retain];
                [runLoop addTimer:sysExTimeOutTimer forMode:mode];
            } else {
#if DEBUG
                NSLog(@"SMMessageParser trying to add timer but the run loop has no mode--giving up");
#endif
            }
        } else {
            // We already have a timer, so just bump its fire date forward.
            [sysExTimeOutTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:sysExTimeOut]];
        }
    } else {
        // Not reading sysex, so if we have a timeout pending, forget about it
        if (sysExTimeOutTimer) {
            [sysExTimeOutTimer invalidate];
            [sysExTimeOutTimer release];
            sysExTimeOutTimer = nil;
        }        
    }
}

- (BOOL)cancelReceivingSysExMessage;
{
    BOOL cancelled = NO;

    if (readingSysExData) {
        [readingSysExData release];
        readingSysExData = nil;
        cancelled = YES;
    }

    return cancelled;
}

@end


@implementation SMMessageParser (Private)

- (NSArray *)messagesForPacket:(const MIDIPacket *)packet;
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
        SMMessage *message = nil;
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
                    message = [SMSystemRealTimeMessage systemRealTimeMessageWithTimeStamp:packet->timeStamp type:byte];
                    break;
        
                default:
                    // Byte is invalid
                    byteIsInvalid = YES;
                    break;
            }
        } else {
            if (byte < 0x80) {
                if (readingSysExData) {
                    NSUInteger length;

                    [readingSysExData appendBytes:&byte length:1];

                    length = 1 + [readingSysExData length];
                    // Tell the delegate we're still reading, every 256 bytes
                    if (length % 256 == 0)
                        [nonretainedDelegate parser:self isReadingSysExWithLength:length];
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
                    byteIsInvalid = YES;
                }
            } else {
                if (readingSysExData)
                    message = [self finishSysExMessageWithValidEnd:(byte == 0xF7)];

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
                                // System exclusive ends--already handled above.
                                // But if this is showing up outside of sysex, it's invalid.
                                if (!message)
                                    byteIsInvalid = YES;
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

        if (!ignoreInvalidData) {
            if (byteIsInvalid) {
                if (!readingInvalidData)
                    readingInvalidData = [NSMutableData data];
                [readingInvalidData appendBytes:&byte length:1];
            }
    
            if (readingInvalidData && (!byteIsInvalid || length == 0)) {
                // We hit the end of a stretch of invalid data.
                message = [SMInvalidMessage invalidMessageWithTimeStamp:packet->timeStamp data:readingInvalidData];
                readingInvalidData = nil;
            }
        }
        
        if (message) {
            [message setOriginatingEndpoint:nonretainedOriginatingEndpoint];
            
            if (!messages)
                messages = [NSMutableArray arrayWithObject:message];
            else
                [messages addObject:message];
        }
    }

    return messages;
}

- (SMSystemExclusiveMessage *)finishSysExMessageWithValidEnd:(BOOL)isEndValid;
{
    SMSystemExclusiveMessage *message = nil;

    // NOTE: If we want, we could refuse sysex messages that don't end in 0xF7.
    // The MIDI spec says that messages should end with this byte, but apparently that is not always the case in practice.

    if (readingSysExData) {
        message = [SMSystemExclusiveMessage systemExclusiveMessageWithTimeStamp:startSysExTimeStamp data:readingSysExData];
        
        [readingSysExData release];
        readingSysExData = nil;
    }

    if (message) {
        [message setOriginatingEndpoint:nonretainedOriginatingEndpoint];
        [message setWasReceivedWithEOX:isEndValid];
        [nonretainedDelegate parser:self finishedReadingSysExMessage:message];
    }

    return message;
}

- (void)sysExTimedOut;
{
    SMSystemExclusiveMessage *message;

    [sysExTimeOutTimer release];
    sysExTimeOutTimer = nil;

    message = [self finishSysExMessageWithValidEnd:NO];
    if (message)
        [nonretainedDelegate parser:self didReadMessages:[NSArray arrayWithObject:message]];
}

@end
