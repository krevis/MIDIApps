#import "SMOutputStream.h"

#import <CoreAudio/CoreAudio.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMMessage.h"


@interface SMOutputStream (Private)

- (MIDIPacketList *)_packetListForMessages:(NSArray *)messages;

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
    MIDIPacketList *packetList;

    if ([messages count] == 0)
        return;

    packetList = [self _packetListForMessages:messages];
    [self sendMIDIPacketList:packetList];
    NSZoneFree(NSDefaultMallocZone(), packetList);
}

//
// To be implemented in subclasses
//

- (void)sendMIDIPacketList:(MIDIPacketList *)packetList;
{
    OBRequestConcreteImplementation(self, _cmd);
}

@end


@implementation SMOutputStream (Private)

const unsigned int maxPacketSize = 512;   //1010;
    // NOTE: This should be 65535, since the storage for the packet length is an UInt16. However, large packets (> 1040 bytes) crash the MIDIServer quite reliably under 10.1.2.
    // Also, the MIDIServer splits large packets into packets of <= 1010 bytes, so we might as well not make it do that. (1010 bytes of data in a message, packaged as one packet in a packet list, comes out to 1024 bytes of packet list.)
    // TODO BUT! It seems that sending a single packet list of > 1024 bytes causes crashes, too, no matter how big the individual packets are. This is pretty stupid.  Need to look into it more.

- (MIDIPacketList *)_packetListForMessages:(NSArray *)messages;
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
        now = AudioGetCurrentHostTime();

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

            if (messagePacketIndex + 1 == messagePacketCount)		// last packet for this message
                packet->length = remainingLength;
            else
                packet->length = maxPacketSize;
            
            if (messagePacketIndex == 0) {	
                // First packet needs special copying of status byte
                packet->data[0] = [message statusByte];
                if (packet->length > 1)
                    memcpy(&packet->data[1], messageData, packet->length - 1);
            } else {
                memcpy(&packet->data[0], messageData, packet->length);
            }
            
            messageData += packet->length;
            remainingLength -= packet->length;

            packet = MIDIPacketNext(packet);
        }
    }
    
    return packetList;
}

@end
