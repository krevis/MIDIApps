#import "SMOutputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMEndpoint.h"
#import "SMMessage.h"
#import "SMSystemExclusiveMessage.h"
#import "SMSysExSendRequest.h"


@interface SMOutputStream (Private)

- (void)_splitMessages:(NSArray *)messages intoSysex:(NSArray **)sysExMessagesPtr andNormal:(NSArray **)normalMessagesPtr;

- (void)_sendSysExMessagesAsynchronously:(NSArray *)sysExMessages;
- (void)_sysExSendRequestFinished:(NSNotification *)notification;

- (MIDIPacketList *)_packetListForMessages:(NSArray *)messages;

@end


@implementation SMOutputStream

DEFINE_NSSTRING(SMOutputStreamDoneSendingSysExNotification);


- (id)init;
{
    if (!(self = [super init]))
        return nil;

    flags.ignoresTimeStamps = NO;
    flags.sendsSysExAsynchronously = YES;

    sysExSendRequests = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc;
{
    [sysExSendRequests release];
    sysExSendRequests = nil;
    
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

- (BOOL)sendsSysExAsynchronously;
{
    return flags.sendsSysExAsynchronously;
}

- (void)setSendsSysExAsynchronously:(BOOL)value;
{
    flags.sendsSysExAsynchronously = value;
}

- (MIDITimeStamp)sendImmediatelyTimeStamp;
{
    return 0;
}

- (void)cancelPendingSysExSendRequests;
{
    [sysExSendRequests makeObjectsPerformSelector:@selector(cancel)];
}

- (void)takeMIDIMessages:(NSArray *)messages;
{
    MIDIPacketList *packetList;

    if ([messages count] == 0)
        return;

    if (flags.sendsSysExAsynchronously) {
        NSArray *sysExMessages, *normalMessages;

        [self _splitMessages:messages intoSysex:&sysExMessages andNormal:&normalMessages];

        [self _sendSysExMessagesAsynchronously:sysExMessages];

        messages = normalMessages;
        if ([messages count] == 0)
            return;
    }
    
    packetList = [self _packetListForMessages:messages];
    [self sendMIDIPacketList:packetList];
    NSZoneFree(NSDefaultMallocZone(), packetList);
}

- (void)sendMIDIPacketList:(MIDIPacketList *)packetList;
{
    // Implement this in subclasses
    OBRequestConcreteImplementation(self, _cmd);
}

- (SMEndpoint *)endpoint;
{
    // Implement this in subclasses
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

@end


@implementation SMOutputStream (Private)

- (void)_splitMessages:(NSArray *)messages intoSysex:(NSArray **)sysExMessagesPtr andNormal:(NSArray **)normalMessagesPtr;
{
    unsigned int messageIndex, messageCount;
    NSMutableArray *sysExMessages = nil;
    NSMutableArray *normalMessages = nil;

    messageCount = [messages count];
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMMessage *message;
        NSMutableArray **theArray;

        message = [messages objectAtIndex:messageIndex];
        if ([message isKindOfClass:[SMSystemExclusiveMessage class]])
            theArray = &sysExMessages;
        else
            theArray = &normalMessages;

        if (*theArray == nil)
            *theArray = [NSMutableArray array];
        [*theArray addObject:message];
    }

    if (sysExMessagesPtr)
        *sysExMessagesPtr = sysExMessages;
    if (normalMessagesPtr)
        *normalMessagesPtr = normalMessages;
}

- (void)_sendSysExMessagesAsynchronously:(NSArray *)messages;
{
    MIDIEndpointRef endpointRef;
    unsigned int messageCount, messageIndex;

    if (!(endpointRef = [[self endpoint] endpointRef]))
        return;

    messageCount = [messages count];
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMSystemExclusiveMessage *message;
        SMSysExSendRequest *sendRequest;

        message = [messages objectAtIndex:messageIndex];
        sendRequest = [SMSysExSendRequest sysExSendRequestWithMessage:message endpoint:endpointRef];
        [sysExSendRequests addObject:sendRequest];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_sysExSendRequestFinished:) name:SMSysExSendRequestFinishedNotification object:sendRequest];
        [sendRequest send];
    }
}

- (void)_sysExSendRequestFinished:(NSNotification *)notification;
{
    SMSysExSendRequest *sendRequest;
    NSMutableDictionary *userInfo;

    sendRequest = [notification object];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:sendRequest];

    userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:[NSNumber numberWithUnsignedInt:[sendRequest bytesSent]] forKey:@"bytesSent"];
    [userInfo setObject:[NSNumber numberWithBool:[sendRequest wereAllBytesSent]] forKey:@"valid"];
    [userInfo setObject:[sendRequest message] forKey:@"message"];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMOutputStreamDoneSendingSysExNotification object:self userInfo:userInfo];
    
    [sysExSendRequests removeObjectIdenticalTo:sendRequest];
}


const unsigned int maxPacketSize = 65535;

- (MIDIPacketList *)_packetListForMessages:(NSArray *)messages;
{
    unsigned int messageIndex, messageCount;
    unsigned int packetListSize;
    MIDIPacketList *packetList;
    MIDIPacket *packet;
    MIDITimeStamp sendImmediatelyTimeStamp = 0;

    messageCount = [messages count];
    packetListSize = offsetof(MIDIPacketList, packet);

    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMMessage *message;
        unsigned int otherDataLength;
        unsigned int packetCount;

        message = [messages objectAtIndex:messageIndex];
        otherDataLength = [message otherDataLength];
        // Remember that all messages are at least 1 byte long; otherDataLength is on top of that.

        // Messages > maxPacketSize need to be split across multiple packets
        packetCount = 1 + (1 + otherDataLength) / (maxPacketSize + 1);            
        packetListSize += packetCount * offsetof(MIDIPacket, data) + 1 + otherDataLength;
    }

    packetList = (MIDIPacketList *)NSZoneMalloc(NSDefaultMallocZone(), packetListSize);
    packetList->numPackets = messageCount;

    if (flags.ignoresTimeStamps)
        sendImmediatelyTimeStamp = [self sendImmediatelyTimeStamp];

    packet = &(packetList->packet[0]);
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMMessage *message;
        unsigned int otherDataLength;
        unsigned int packetCount, packetIndex;
        const Byte *messageData;
        unsigned int remainingLength;
        
        message = [messages objectAtIndex:messageIndex];
        otherDataLength = [message otherDataLength];
        packetCount = 1 + (1 + otherDataLength) / (maxPacketSize + 1);

        messageData = [message otherDataBuffer];
        remainingLength = 1 + otherDataLength;

        for (packetIndex = 0; packetIndex < packetCount; packetIndex++) {
            if (flags.ignoresTimeStamps)
                packet->timeStamp = sendImmediatelyTimeStamp;
            else
                packet->timeStamp = [message timeStamp];

            if (packetIndex + 1 == packetCount)		// last packet
                packet->length = remainingLength;
            else
                packet->length = maxPacketSize;
            
            if (packetIndex == 0) {	
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
