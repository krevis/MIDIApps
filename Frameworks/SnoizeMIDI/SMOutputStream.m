/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMOutputStream.h"

#import "SMHostTime.h"
#import "SMMessage.h"
#import "SMUtilities.h"


#define LIMITED_PACKET_LIST_SIZE 1
// Workaround Apple bug #2830198, which is present as of Mac OS X 10.1.2 (and probably earlier).
// This bug causes the CoreMIDI MIDIServer process to crash if we try to use MIDISend() on a packet list which is >= 1024 bytes long. Packet lists should be effectively unlimited in length.
// We work around the problem by splitting into multiple small packet lists.
// Doug Wyatt <dwyatt@apple.com> claims this has been fixed; we'll see.
// TODO make this test at runtime and change our behavior accordingly


@interface SMOutputStream (Private)

#if LIMITED_PACKET_LIST_SIZE
- (void)sendMessagesWithLimitedPacketListSize:(NSArray *)messages;
- (void)addMessage:(SMMessage *)message withDataSize:(NSUInteger)dataSize toPacketList:(MIDIPacketList *)packetList packet:(MIDIPacket *)packet;
#else
- (MIDIPacketList *)packetListForMessages:(NSArray *)messages;
#endif

@end


@implementation SMOutputStream

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    flags.ignoresTimeStamps = NO;
    
    return self;
}

- (void)dealloc;
{
    [super dealloc];
}

- (BOOL)ignoresTimeStamps;
{
    return flags.ignoresTimeStamps;
}

- (void)setIgnoresTimeStamps:(BOOL)value;
{
    flags.ignoresTimeStamps = value;
}

//
// SMMessageDestination protocol
//

- (void)takeMIDIMessages:(NSArray *)messages;
{
#if LIMITED_PACKET_LIST_SIZE

    [self sendMessagesWithLimitedPacketListSize:messages];

#else

    MIDIPacketList *packetList;

    if ([messages count] == 0)
        return;

    packetList = [self packetListForMessages:messages];
    [self sendMIDIPacketList:packetList];
    NSZoneFree(NSDefaultMallocZone(), packetList);    

#endif
}

//
// To be implemented in subclasses
//

- (void)sendMIDIPacketList:(MIDIPacketList *)packetList;
{
    SMRequestConcreteImplementation(self, _cmd);
}

@end


@implementation SMOutputStream (Private)

#if LIMITED_PACKET_LIST_SIZE

static const unsigned int MAX_PACKET_LIST_SIZE = 1024;

- (void)sendMessagesWithLimitedPacketListSize:(NSArray *)messages;
{
    NSUInteger messageIndex, messageCount;
    MIDIPacketList *packetList;
    MIDIPacket *packet;
    NSUInteger packetListSize;

    messageCount = [messages count];
    if (messageCount == 0)
        return;

    packetList = malloc(MAX_PACKET_LIST_SIZE);
    packetList->numPackets = 0;
    packet = &packetList->packet[0];
    packetListSize = offsetof(MIDIPacketList, packet);

    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMMessage *message;
        NSUInteger dataSize, packetSize;

        message = [messages objectAtIndex:messageIndex];
        dataSize = 1 + [message otherDataLength];
        // All messages are at least 1 byte long; otherDataLength is on top of that.
        packetSize = offsetof(MIDIPacket, data) + dataSize;
        // And each packet has some overhead.

        // Is there room in this packet list for the whole of this message?
        if (packetListSize + packetSize <= MAX_PACKET_LIST_SIZE) {
            // Put this message in a packet.
            [self addMessage:message withDataSize:dataSize toPacketList:packetList packet:packet];
            packetListSize += packetSize;
            packet = MIDIPacketNext(packet);

        } else {
            if (dataSize <= 3 || (MAX_PACKET_LIST_SIZE - packetListSize <= offsetof(MIDIPacket, data))) {
                // This is a small message; we don't want to split it up;
                // or, there is not enough space in the packet list for even the header of one more packet.
                // We will start a new packet list, and then put this message in it.

                // We're finished with this packet list, so send it
                [self sendMIDIPacketList:packetList];

                // and start a new one
                packetList->numPackets = 0;
                packet = &packetList->packet[0];
                packetListSize = offsetof(MIDIPacketList, packet);

                // and add this message's packet to it
                [self addMessage:message withDataSize:dataSize toPacketList:packetList packet:packet];
                packetListSize += packetSize;
                packet = MIDIPacketNext(packet);
                SMAssert((Byte *)packet - (Byte *)packetList < MAX_PACKET_LIST_SIZE);

            } else {
                // This is a large sysex message. We can split it up.
                // Put as much as will fit into the current packet list.
                // Then start a new packet list, and put as much as will fit into it.
                // Repeat until we've done all the data in the message.

                const Byte *messageData;
                NSUInteger dataRemaining;
                BOOL isFirstPacket = YES;

                messageData = [message otherDataBuffer];
                dataRemaining = dataSize;
                
                while (dataRemaining > 0) {
                    NSUInteger partialSize;

                    SMAssert((int)MAX_PACKET_LIST_SIZE - packetListSize - offsetof(MIDIPacket, data) > 0);
                    partialSize = MIN(MAX_PACKET_LIST_SIZE - packetListSize - offsetof(MIDIPacket, data), dataRemaining);

                    // add data to packet
                    packet->timeStamp = (flags.ignoresTimeStamps ? SMGetCurrentHostTime() : [message timeStamp]);
                    packet->length = partialSize;
                    if (isFirstPacket) {
                        isFirstPacket = NO;
                        packet->data[0] = [message statusByte];
                        memcpy(&packet->data[1], messageData, partialSize - 1);
                        messageData += partialSize - 1;
                    } else {
                        memcpy(&packet->data[0], messageData, partialSize);
                        messageData += partialSize;
                    }
                    dataRemaining -= partialSize;
                    packetListSize += offsetof(MIDIPacket, data) + partialSize;
                    packetList->numPackets++;

                    SMAssert(packetListSize <= MAX_PACKET_LIST_SIZE);

                    if (MAX_PACKET_LIST_SIZE - packetListSize <= offsetof(MIDIPacket, data)) {
                        // No room for any more packets in this packet list, so send it
                        [self sendMIDIPacketList:packetList];

                        // and start a new one
                        packetList->numPackets = 0;
                        packet = &packetList->packet[0];
                        packetListSize = offsetof(MIDIPacketList, packet);
                    } else {
                        SMAssert(packetListSize + offsetof(MIDIPacket, data) < MAX_PACKET_LIST_SIZE);
                        packet = MIDIPacketNext(packet);
                        SMAssert((Byte *)packet - (Byte *)packetList < MAX_PACKET_LIST_SIZE);
                    }
                }
            }
        }
    }

    // All messages have been processed, but we may still have an unsent packet list.
    if (packetList->numPackets > 0)
        [self sendMIDIPacketList:packetList];
    
    free(packetList);
}

- (void)addMessage:(SMMessage *)message withDataSize:(NSUInteger)dataSize toPacketList:(MIDIPacketList *)packetList packet:(MIDIPacket *)packet;
{
    packet->timeStamp = (flags.ignoresTimeStamps ? SMGetCurrentHostTime() : [message timeStamp]);
    packet->length = dataSize;
    packet->data[0] = [message statusByte];
    if (dataSize > 1)
        memcpy(&packet->data[1], [message otherDataBuffer], dataSize - 1);

    packetList->numPackets++;
}

#else  // ! LIMITED_PACKET_LIST_SIZE

const unsigned int maxPacketSize = 65535;

- (MIDIPacketList *)packetListForMessages:(NSArray *)messages;
{
    unsigned int messageIndex, messageCount;
    unsigned int packetListSize;
    unsigned int packetCount;
    MIDIPacketList *packetList;
    MIDIPacket *packet;
    MIDITimeStamp now = 0;

    messageCount = [messages count];
    packetListSize = offsetof(MIDIPacketList, packet);
    packetCount = 0;

    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMMessage *message;
        unsigned int otherDataLength;
        unsigned int messagePacketCount;

        message = [messages objectAtIndex:messageIndex];
        otherDataLength = [message otherDataLength];
        // Remember that all messages are at least 1 byte long; otherDataLength is on top of that.

        // Messages > maxPacketSize need to be split across multiple packets
        messagePacketCount = 1 + (1 + otherDataLength) / (maxPacketSize + 1);            
        packetListSize += messagePacketCount * offsetof(MIDIPacket, data) + 1 + otherDataLength;
        packetCount += messagePacketCount;
    }

    packetList = (MIDIPacketList *)NSZoneMalloc(NSDefaultMallocZone(), packetListSize);
    packetList->numPackets = packetCount;

    if (flags.ignoresTimeStamps)
        now = SMGetCurrentHostTime();

    packet = &(packetList->packet[0]);
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMMessage *message;
        unsigned int otherDataLength;
        unsigned int messagePacketCount, messagePacketIndex;
        const Byte *messageData;
        unsigned int remainingLength;
        
        message = [messages objectAtIndex:messageIndex];
        otherDataLength = [message otherDataLength];
        messagePacketCount = 1 + (1 + otherDataLength) / (maxPacketSize + 1);

        messageData = [message otherDataBuffer];
        remainingLength = 1 + otherDataLength;

        for (messagePacketIndex = 0; messagePacketIndex < messagePacketCount; messagePacketIndex++) {
            if (flags.ignoresTimeStamps)
                packet->timeStamp = now;
            else
                packet->timeStamp = [message timeStamp];

            if (messagePacketIndex + 1 == messagePacketCount)   // last packet for this message
                packet->length = remainingLength;
            else
                packet->length = maxPacketSize;
            
            if (messagePacketIndex == 0) {	
                // First packet needs special copying of status byte
                packet->data[0] = [message statusByte];
                if (packet->length > 1) {
                    memcpy(&packet->data[1], messageData, packet->length - 1);
                    messageData += packet->length - 1;
                }
            } else {
                memcpy(&packet->data[0], messageData, packet->length);
                messageData += packet->length;
            }
            
            remainingLength -= packet->length;

            packet = MIDIPacketNext(packet);
        }
    }
    
    return packetList;
}

#endif

@end
