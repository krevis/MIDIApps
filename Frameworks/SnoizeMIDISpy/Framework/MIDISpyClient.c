#include "MIDISpyClient.h"


typedef struct __MIDISpyClient
{
    MIDISpyClientCallBack clientCallBack;
    void *clientRefCon;
    CFMessagePortRef localPort;
    CFRunLoopSourceRef runLoopSource;
} MIDISpyClient;


static CFStringRef kSpyingMIDIDriverPortName = NULL;
static const SInt32 kSpyingMIDIDriverNextSequenceNumberMessageID = 0; 
static const SInt32 kSpyingMIDIDriverAddListenerMessageID = 1; 

static CFDataRef localMessagePortCallback(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info);


MIDISpyClientRef MIDISpyClientCreate(MIDISpyClientCallBack callBack, void *refCon)
{
    MIDISpyClientRef clientRef = NULL;
    CFMessagePortRef driverPort;
    SInt32 sendStatus;
    CFDataRef sequenceNumberData = NULL;
    int success = 0;

    // TODO There must be a better way to do this.
    if (!kSpyingMIDIDriverPortName)
        kSpyingMIDIDriverPortName = CFSTR("Spying MIDI Driver");
    
    // Look for the message port which our MIDI driver provides
    driverPort = CFMessagePortCreateRemote(kCFAllocatorDefault, kSpyingMIDIDriverPortName);
    if (!driverPort) {
#if DEBUG
        fprintf(stderr, "MIDISpyClientCreate: Couldn't find message port for Spying MIDI Driver\n");
#endif
        return NULL;
    }

    clientRef = (MIDISpyClientRef)malloc(sizeof(MIDISpyClient));
    
    // Ask for the next sequence number
    sendStatus = CFMessagePortSendRequest(driverPort, kSpyingMIDIDriverNextSequenceNumberMessageID, NULL, 300, 300, kCFRunLoopDefaultMode, &sequenceNumberData);
    if (sendStatus != kCFMessagePortSuccess) {
#if DEBUG
        fprintf(stderr, "MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverNextSequenceNumberMessageID) returned error: %ld\n", sendStatus);
#endif
    } else if (!sequenceNumberData) {
#if DEBUG
        fprintf(stderr, "MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverNextSequenceNumberMessageID) returned no data!\n");
#endif
    } else if (CFDataGetLength(sequenceNumberData) != sizeof(UInt32)) {
#if DEBUG
        fprintf(stderr, "MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverNextSequenceNumberMessageID) returned %lu bytes, not %lu!\n", CFDataGetLength(sequenceNumberData), sizeof(UInt32));
#endif
    } else {
        UInt32 sequenceNumber;
        CFStringRef localPortName;
        CFMessagePortContext context = { 0, clientRef, NULL, NULL, NULL };
        CFMessagePortRef localPort;
        CFRunLoopSourceRef runLoopSource;

        // Now get the sequence number and use it to name a newly created local port
        sequenceNumber = *(UInt32 *)CFDataGetBytePtr(sequenceNumberData);
        localPortName = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@-%lu"), kSpyingMIDIDriverPortName, sequenceNumber);

        localPort = CFMessagePortCreateLocal(kCFAllocatorDefault, localPortName, localMessagePortCallback, &context, FALSE);
        CFRelease(localPortName);
        if (!localPort) {
#if DEBUG
            fprintf(stderr, "MIDISpyClientCreate: CFMessagePortCreateLocal failed!\n");
#endif
        } else {
            // Add the local port to the current run loop, in common modes
            runLoopSource = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, localPort, 0);
            if (!runLoopSource) {
#if DEBUG
                fprintf(stderr, "MIDISpyClientCreate: CFMessagePortCreateRunLoopSource failed!\n");
#endif
            } else {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    
                // And now tell the spying driver to add us as a listener. Don't wait for a response.
                sendStatus = CFMessagePortSendRequest(driverPort, kSpyingMIDIDriverAddListenerMessageID, sequenceNumberData, 300, 0, NULL, NULL);
                if (sendStatus != kCFMessagePortSuccess) {
#if DEBUG
                    fprintf(stderr, "MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverAddListenerMessageID) returned error: %ld\n", sendStatus);
#endif
                } else {
                    // Success!
                    success = 1;
                    clientRef->clientCallBack = callBack;
                    clientRef->clientRefCon = refCon;
                    CFRetain(localPort);
                    clientRef->localPort = localPort;
                    CFRetain(runLoopSource);
                    clientRef->runLoopSource = runLoopSource;
                }

                CFRelease(runLoopSource);
            }

            CFRelease(localPort);
        }
    }

    if (sequenceNumberData)
        CFRelease(sequenceNumberData);

    CFRelease(driverPort);

    if (!success) {
        free(clientRef);
        clientRef = NULL;
    }
    
    return clientRef;
}

void MIDISpyClientDispose(MIDISpyClientRef clientRef)
{
    if (clientRef->runLoopSource) {
        CFRunLoopSourceInvalidate(clientRef->runLoopSource);
        CFRelease(clientRef->runLoopSource);
    }

    if (clientRef->localPort) {
        CFMessagePortInvalidate(clientRef->localPort);
        CFRelease(clientRef->localPort);        
    }
    
    free(clientRef);
}


static CFDataRef localMessagePortCallback(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info)
{
    const UInt8 *bytes;
    SInt32 endpointUniqueID;
    const char *endpointNameCString;
    const MIDIPacketList *packetList;
    CFStringRef endpointName;
    MIDISpyClientRef clientRef = (MIDISpyClientRef)info;

    if (!data) {
#if DEBUG
        fprintf(stderr, "MIDISpyClient: Got empty data from driver!\n");
#endif
        return NULL;
    } else if (CFDataGetLength(data) < (sizeof(SInt32) + 1 + sizeof(UInt32))) {
#if DEBUG
        fprintf(stderr, "MIDISpyClient: Got too-small data from driver! (%ld bytes)\n", CFDataGetLength(data));
#endif
        return NULL;
    }

    bytes = CFDataGetBytePtr(data);
    
    endpointUniqueID = *(SInt32 *)bytes;
    endpointNameCString = (const char *)(bytes + sizeof(SInt32));
    packetList = (const MIDIPacketList *)(bytes + sizeof(SInt32) + strlen(endpointNameCString) + 1);

    endpointName = CFStringCreateWithCString(kCFAllocatorDefault, endpointNameCString, kCFStringEncodingUTF8);

    clientRef->clientCallBack(endpointUniqueID, endpointName, packetList, clientRef->clientRefCon);

    CFRelease(endpointName);
    
    return NULL;
}
