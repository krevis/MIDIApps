/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

#include "MIDISpyClient.h"

#include <CoreServices/CoreServices.h>
#include <pthread.h>

#include "MIDISpyShared.h"


//
// Definitions of publicly accessible structures
//

typedef struct __MIDISpyClient
{
    CFMessagePortRef driverPort;
    CFMessagePortRef localPort;
    CFRunLoopSourceRef runLoopSource;
    CFRunLoopRef listenerThreadRunLoop;
    SInt32 clientIdentifier;
    CFMutableArrayRef ports;
    CFMutableDictionaryRef endpointConnections;
} MIDISpyClient;

typedef struct __MIDISpyPort
{
    MIDISpyClientRef client;
    MIDIReadBlock readBlock;
    CFMutableArrayRef connections;
} MIDISpyPort;


//
// Definitions of private structures
//

typedef struct __MIDISpyPortConnection
{
    MIDISpyPortRef port;
    MIDIEndpointRef endpoint;
    void *refCon;
} MIDISpyPortConnection;


//
// Constant string declarations and definitions
//

static CFStringRef kSpyingMIDIDriverPortName = NULL;

static void InitializeConstantStrings(void)  __attribute__ ((constructor));
void InitializeConstantStrings(void)
{
    kSpyingMIDIDriverPortName = CFSTR("Spying MIDI Driver");
}


//
// Private function declarations
//

static void SpawnListenerThread(MIDISpyClientRef clientRef);
static void *RunListenerThread(void *refCon);

static void ReceiveMIDINotification(const MIDINotification *message, void *refCon);
static void RebuildEndpointUniqueIDDictionary(void);
static MIDIEndpointRef EndpointWithUniqueID(SInt32 uniqueID);

static MIDISpyPortConnection *GetPortConnection(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint);
static void DisconnectConnection(MIDISpyPortRef spyPortRef, MIDISpyPortConnection *connection);

static void ClientAddConnection(MIDISpyClientRef clientRef, MIDISpyPortConnection *connection);
static void ClientRemoveConnection(MIDISpyClientRef clientRef, MIDISpyPortConnection *connection);
static CFMutableArrayRef GetConnectionsToEndpoint(MIDISpyClientRef clientRef, MIDIEndpointRef endpoint);

static void SetClientSubscribesToDataFromEndpoint(MIDISpyClientRef clientRef, MIDIEndpointRef endpoint, Boolean subscribes);
static CFDataRef LocalMessagePortCallback(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info);


//
// Static variables
//

static MIDIClientRef sMIDIClientRef = (MIDIClientRef)0;
static CFMutableDictionaryRef sUniqueIDToEndpointDictionary = NULL;


//
// Public functions
//

OSStatus MIDISpyClientCreate(MIDISpyClientRef *outClientRefPtr)
{
    MIDISpyClientRef clientRef = NULL;
    CFMessagePortRef driverPort;
    SInt32 sendStatus;
    CFDataRef identifierData = NULL;
    int success = 0;
    
    if (!outClientRefPtr)
        return paramErr;
    *outClientRefPtr = NULL;

    // Create a CoreMIDI client (if we haven't already), so we can receive a notification when the setup changes.
    if (!sMIDIClientRef) {
        OSStatus status;

        status = MIDIClientCreate(CFSTR("MIDISpyClient"), ReceiveMIDINotification, NULL, &sMIDIClientRef);
        if (status != noErr)
            return status;

        RebuildEndpointUniqueIDDictionary();
    }
    
    // Look for the message port which our MIDI driver provides
    driverPort = CFMessagePortCreateRemote(kCFAllocatorDefault, kSpyingMIDIDriverPortName);
    if (!driverPort) {
        __Debug_String("MIDISpyClientCreate: Couldn't find message port for Spying MIDI Driver");
        return kMIDISpyDriverMissing;
    }

    clientRef = (MIDISpyClientRef)calloc(1, sizeof(MIDISpyClient));
    if (!clientRef) {
        CFMessagePortInvalidate(driverPort);
        CFRelease(driverPort);
        return memFullErr;
    }
    clientRef->driverPort = driverPort;
    
    // Ask for an identifier number from the driver.
    // Use a custom run loop mode while waiting for the reply, not kCFRunLoopDefaultMode,
    // so we don't accidentally run any delayed performs at a bad time during startup.
    CFStringRef replyMode = CFSTR("MIDISpyClientCreateMode");
    sendStatus = CFMessagePortSendRequest(driverPort, kSpyingMIDIDriverGetNextListenerIdentifierMessageID, NULL, 300, 300, replyMode, &identifierData);

    if (sendStatus != kCFMessagePortSuccess) {
        __Debug_String("MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverGetNextListenerIdentifierMessageID) returned error");
    } else if (!identifierData) {
        __Debug_String("MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverGetNextListenerIdentifierMessageID) returned no data!");
    } else if (CFDataGetLength(identifierData) != sizeof(SInt32)) {
        __Debug_String("MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverGetNextListenerIdentifierMessageID) returned wrong number of bytes");
    } else {
        CFStringRef localPortName;
        CFMessagePortContext context = { 0, NULL, NULL, NULL, NULL };

        // Now get the identifier and use it to name a newly created local port
        clientRef->clientIdentifier = *(SInt32 *)CFDataGetBytePtr(identifierData);
        localPortName = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@-%d"), kSpyingMIDIDriverPortName, clientRef->clientIdentifier);

        context.info = clientRef;
        clientRef->localPort = CFMessagePortCreateLocal(kCFAllocatorDefault, localPortName, LocalMessagePortCallback, &context, FALSE);
        CFRelease(localPortName);

        if (!clientRef->localPort) {
            __Debug_String("MIDISpyClientCreate: CFMessagePortCreateLocal failed!");
        } else {
            // Create a new thread which listens on the local port
            clientRef->runLoopSource = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, clientRef->localPort, 0);

            if (!clientRef->runLoopSource) {
                __Debug_String("MIDISpyClientCreate: CFMessagePortCreateRunLoopSource failed!");
            } else {
                SpawnListenerThread(clientRef);

                // And now tell the spying driver to add us as a listener. Don't wait for a response.
                sendStatus = CFMessagePortSendRequest(driverPort, kSpyingMIDIDriverAddListenerMessageID, identifierData, 300, 0, NULL, NULL);
                if (sendStatus != kCFMessagePortSuccess) {
                    __Debug_String("MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverAddListenerMessageID) returned error");
                } else {
                    // Now create the array of ports, and dictionary of connnections for each endpoint
                    clientRef->ports = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
                    clientRef->endpointConnections = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
                    
                    // Success! (probably)
                    success = (clientRef->ports != NULL && clientRef->endpointConnections != NULL);
                }
            }
        }
    }

    if (identifierData)
        CFRelease(identifierData);

    if (!success) {
        MIDISpyClientDispose(clientRef);
        return kMIDISpyDriverCouldNotCommunicate;
    }

    *outClientRefPtr = clientRef;
    return noErr;
}


OSStatus MIDISpyClientDispose(MIDISpyClientRef clientRef)
{
    if (!clientRef)
        return paramErr;

    if (clientRef->ports) {
        CFIndex portIndex;

        portIndex = CFArrayGetCount(clientRef->ports);
        while (portIndex--) {
            MIDISpyPortRef port;

            port = (MIDISpyPortRef)CFArrayGetValueAtIndex(clientRef->ports, portIndex);
            MIDISpyPortDispose(port);
        }
        
        CFRelease(clientRef->ports);
    }

    if (clientRef->endpointConnections) {
        CFRelease(clientRef->endpointConnections);
    }

    if (clientRef->runLoopSource) {
        CFRunLoopSourceInvalidate(clientRef->runLoopSource);
        CFRelease(clientRef->runLoopSource);
        clientRef->runLoopSource = NULL;
    }

    if (clientRef->listenerThreadRunLoop) {
        CFRunLoopStop(clientRef->listenerThreadRunLoop);
        clientRef->listenerThreadRunLoop = NULL;
    }

    if (clientRef->localPort) {
        CFMessagePortInvalidate(clientRef->localPort);
        CFRelease(clientRef->localPort);
        clientRef->localPort = NULL;
    }

    if (clientRef->driverPort) {
        CFMessagePortInvalidate(clientRef->driverPort);
        CFRelease(clientRef->driverPort);
        clientRef->driverPort = NULL;
    }
    
    free(clientRef);
    return noErr;
}

void MIDISpyClientDisposeSharedMIDIClient(void)
{
    if (sMIDIClientRef) {
        MIDIClientDispose(sMIDIClientRef);
        sMIDIClientRef = (MIDIClientRef)0;
    }
}


OSStatus MIDISpyPortCreate(MIDISpyClientRef clientRef, MIDIReadBlock readBlock, MIDISpyPortRef *outSpyPortRefPtr)
{
    MIDISpyPort *spyPortRef;

    if (!clientRef || !readBlock || !outSpyPortRefPtr )
        return paramErr;

    spyPortRef = (MIDISpyPort *)malloc(sizeof(MIDISpyPort));
    if (!spyPortRef)
        return memFullErr;
    
    spyPortRef->client = clientRef;
    spyPortRef->readBlock = readBlock;
    CFRetain(readBlock);

    spyPortRef->connections = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
    if (!spyPortRef->connections) {
        free(spyPortRef);
        return memFullErr;        
    }

    CFArrayAppendValue(clientRef->ports, spyPortRef);

    *outSpyPortRefPtr = spyPortRef;
    return noErr;
}


OSStatus MIDISpyPortDispose(MIDISpyPortRef spyPortRef)
{
    CFMutableArrayRef ports;
    CFIndex portIndex;
            
    if (!spyPortRef)
        return paramErr;

    // Disconnect all of this port's connections
    if (spyPortRef->connections) {
        CFIndex connectionIndex;

        connectionIndex = CFArrayGetCount(spyPortRef->connections);
        while (connectionIndex--) {
            MIDISpyPortConnection *connection;

            connection = (MIDISpyPortConnection *)CFArrayGetValueAtIndex(spyPortRef->connections, connectionIndex);
            DisconnectConnection(spyPortRef, connection);
        }

        CFRelease(spyPortRef->connections);
    }

    // Remove this port from the client's array of ports
    ports = spyPortRef->client->ports;
    portIndex = CFArrayGetFirstIndexOfValue(ports, CFRangeMake(0, CFArrayGetCount(ports)), spyPortRef);
    if (portIndex != kCFNotFound)
        CFArrayRemoveValueAtIndex(ports, portIndex);            

    CFRelease(spyPortRef->readBlock);

    free(spyPortRef);

    return noErr;
}


OSStatus MIDISpyPortConnectDestination(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint, void *connectionRefCon)
{
    MIDISpyPortConnection *connection;

    if (!spyPortRef || !destinationEndpoint)
        return paramErr;

    // See if this port is already connected to this destination. If so, return an error.
    connection = GetPortConnection(spyPortRef, destinationEndpoint);
    if (connection)
        return kMIDISpyConnectionAlreadyExists;
    
    // Create a "connection" record for this port/endpoint pair, with the connectionRefCon in it.
    connection = (MIDISpyPortConnection *)malloc(sizeof(MIDISpyPortConnection));
    connection->port = spyPortRef;
    connection->endpoint = destinationEndpoint;
    connection->refCon = connectionRefCon;

    // Add the connection to the port's array of connections.
    CFArrayAppendValue(spyPortRef->connections, connection);

    ClientAddConnection(spyPortRef->client, connection);

    return noErr;
}


OSStatus MIDISpyPortDisconnectDestination(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint)
{
    MIDISpyPortConnection *connection;

    if (!spyPortRef || !destinationEndpoint)
        return paramErr;

    // See if this port is actually connected to this destination. If not, return an error.
    connection = GetPortConnection(spyPortRef, destinationEndpoint);
    if (!connection)
        return kMIDISpyConnectionDoesNotExist;

    DisconnectConnection(spyPortRef, connection);
    
    return noErr;
}


//
// Private functions
//

// Listener thread

void SpawnListenerThread(MIDISpyClientRef clientRef)
{
    pthread_t thread;

    (void)pthread_create(&thread, NULL, RunListenerThread, clientRef);
}

void *RunListenerThread(void *refCon)
{
    MIDISpyClientRef clientRef = (MIDISpyClientRef)refCon;

    clientRef->listenerThreadRunLoop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(clientRef->listenerThreadRunLoop, clientRef->runLoopSource, kCFRunLoopCommonModes);

    CFRunLoopRun();

    return NULL;
}


// Keeping track of endpoints

void ReceiveMIDINotification(const MIDINotification *message, void *refCon)
{
    static Boolean retryAfterDone = FALSE;
    static Boolean isHandlingNotification = FALSE;

    if (!message || message->messageID != kMIDIMsgSetupChanged)
        return;
        
    if (isHandlingNotification) {
        retryAfterDone = TRUE;
        return;
    }

    do {
        isHandlingNotification = TRUE;
        retryAfterDone = FALSE;

        RebuildEndpointUniqueIDDictionary();

        isHandlingNotification = FALSE;
    } while (retryAfterDone);
}

static inline void* midiObjToVoidPtr(MIDIObjectRef val)
{
#if __LP64__
    return (void*)(uintptr_t)val;
#else
    return (void*)val;
#endif
}

static inline void* sintToVoidPtr(SInt32 val)
{
#if __LP64__
    return (void*)(SInt64)val;
#else
    return (void*)val;
#endif
}

static inline MIDIObjectRef midiObjFromVoidPtr(const void* val)
{
#if __LP64__
    return (MIDIObjectRef)((uintptr_t)val & 0xFFFFFFFFUL);
#else
    return (MIDIObjectRef)val;
#endif
}

void RebuildEndpointUniqueIDDictionary(void)
{
    // Make a dictionary which maps from an endpoint's uniqueID to its MIDIEndpointRef.
    ItemCount endpointIndex, endpointCount;

    endpointCount = MIDIGetNumberOfDestinations();

    if (sUniqueIDToEndpointDictionary)
        CFRelease(sUniqueIDToEndpointDictionary);
    sUniqueIDToEndpointDictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, endpointCount, NULL, NULL);
    
    for (endpointIndex = 0; endpointIndex < endpointCount; endpointIndex++) {
        MIDIEndpointRef endpoint;

        endpoint = MIDIGetDestination(endpointIndex);
        if (endpoint) {
            SInt32 uniqueID;

            if (noErr == MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID))
                CFDictionaryAddValue(sUniqueIDToEndpointDictionary, sintToVoidPtr(uniqueID), midiObjToVoidPtr(endpoint));
        }        
    }
}

MIDIEndpointRef EndpointWithUniqueID(SInt32 uniqueID)
{
    if (sUniqueIDToEndpointDictionary)
        return midiObjFromVoidPtr(CFDictionaryGetValue(sUniqueIDToEndpointDictionary, sintToVoidPtr(uniqueID)));
    else
        return (MIDIEndpointRef)0;
}


// Connection management

MIDISpyPortConnection *GetPortConnection(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint)
{
    CFArrayRef connections;
    CFIndex connectionIndex;

    connections = spyPortRef->connections;
    connectionIndex = CFArrayGetCount(connections);
    while (connectionIndex--) {
        MIDISpyPortConnection *connection;

        connection = (MIDISpyPortConnection *)CFArrayGetValueAtIndex(connections, connectionIndex);
        if (connection->endpoint == destinationEndpoint)
            return connection;
    }

    return NULL;
}

void DisconnectConnection(MIDISpyPortRef spyPortRef, MIDISpyPortConnection *connection)
{
    CFMutableArrayRef connections;
    CFIndex connectionIndex;

    connections = spyPortRef->connections;
    connectionIndex = CFArrayGetFirstIndexOfValue(connections, CFRangeMake(0, CFArrayGetCount(connections)), connection);
    if (connectionIndex != kCFNotFound)
        CFArrayRemoveValueAtIndex(connections, connectionIndex);

    ClientRemoveConnection(spyPortRef->client, connection);
    
    free(connection);
}

void ClientAddConnection(MIDISpyClientRef clientRef, MIDISpyPortConnection *connection)
{
    CFMutableArrayRef connections;
    Boolean isFirstConnectionToEndpoint = FALSE;

    connections = GetConnectionsToEndpoint(clientRef, connection->endpoint);
    if (!connections) {
        connections = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
        CFDictionarySetValue(clientRef->endpointConnections, midiObjToVoidPtr(connection->endpoint), connections);
        CFRelease(connections);
        isFirstConnectionToEndpoint = TRUE;
    }
    CFArrayAppendValue(connections, connection);

    if (isFirstConnectionToEndpoint) {
        SetClientSubscribesToDataFromEndpoint(clientRef, connection->endpoint, TRUE);
    }    
}

void ClientRemoveConnection(MIDISpyClientRef clientRef, MIDISpyPortConnection *connection)
{
    CFMutableArrayRef connections;

    connections = GetConnectionsToEndpoint(clientRef, connection->endpoint);
    if (connections) {
        CFIndex connectionIndex;

        connectionIndex = CFArrayGetFirstIndexOfValue(connections, CFRangeMake(0, CFArrayGetCount(connections)), connection);
        if (connectionIndex != kCFNotFound)
            CFArrayRemoveValueAtIndex(connections, connectionIndex);
    }

    if (connections && CFArrayGetCount(connections) == 0) {
        CFDictionaryRemoveValue(clientRef->endpointConnections, midiObjToVoidPtr(connection->endpoint));
        SetClientSubscribesToDataFromEndpoint(clientRef, connection->endpoint, FALSE);
    }    
}

CFMutableArrayRef GetConnectionsToEndpoint(MIDISpyClientRef clientRef, MIDIEndpointRef endpoint)
{
    return (CFMutableArrayRef)CFDictionaryGetValue(clientRef->endpointConnections, midiObjToVoidPtr(endpoint));
}


// Communication with driver

void SetClientSubscribesToDataFromEndpoint(MIDISpyClientRef clientRef, MIDIEndpointRef endpoint, Boolean subscribes)
{
    // Send a request to the driver to start or stop sending info about the endpoint.

    SInt32 msgid;
    SInt32 endpointUniqueID;
    CFIndex dataLength;
    CFMutableDataRef messageData;
    UInt8 *dataBuffer;

    msgid = (subscribes ? kSpyingMIDIDriverConnectDestinationMessageID : kSpyingMIDIDriverDisconnectDestinationMessageID);

    if (noErr != MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &endpointUniqueID))
        return;
    
    dataLength = sizeof(SInt32) + sizeof(SInt32);
    messageData = CFDataCreateMutable(kCFAllocatorDefault, dataLength);
    if (messageData) {
        CFDataSetLength(messageData, dataLength);
        dataBuffer = CFDataGetMutableBytePtr(messageData);
        if (dataBuffer) {
            *(SInt32 *)dataBuffer = clientRef->clientIdentifier;
            *(SInt32 *)(dataBuffer + sizeof(SInt32)) = endpointUniqueID;

            if (clientRef->driverPort) {
                CFMessagePortSendRequest(clientRef->driverPort, msgid, messageData, 300, 0, NULL, NULL);
            }
        }

        CFRelease(messageData);
    }
}

static bool SanityCheckMIDIPacketList(const MIDIPacketList *packetList, CFIndex packetListLength)
{
    // Return true if packetListLength is large enough to contain all the messages that
    // the packetList claims to have.
    //
    // Preconditions:
    //    packetListLength >= sizeof(MIDIPacketList.numPackets)
    //    packetList != NULL
    //    packetList is at least 4-byte aligned
    //
    // Be careful because the packetList might be truncated at *any* byte position.
    //
    // For reference:
    //
    //    struct MIDIPacketList
    //    {
    //        UInt32              numPackets;
    //        MIDIPacket          packet[1];  // actually a variable number of packets
    //    };
    //    struct MIDIPacket
    //    {
    //        MIDITimeStamp       timeStamp;
    //        UInt16              length;
    //        Byte                data[256];  // actually `length` bytes
    //    };
    //
    // Note that `MIDIPacket`s are 4-byte aligned on Apple Silicon, so there may
    // be padding between the end of one `MIDIPacket` and the start of the next.
    // `MIDIPacketNext()` accounts for any padding.

    uintptr_t actualEndPtr = (uintptr_t)packetList + packetListLength;

    UInt32 claimedNumPackets = packetList->numPackets;
    const MIDIPacket *nextPacket = &packetList->packet[0];

    for (UInt32 packetIndex = 0; packetIndex < claimedNumPackets; packetIndex++) {
        // Ensure we can see all of nextPacket.

        // First, can we see the header including timeStamp and length?
        if ((uintptr_t)(&nextPacket->data[0]) > actualEndPtr) {
            return false;
        }
        // We're safe to read the length.
        // Second, check that all the data is accessible.
        if ((uintptr_t)(&nextPacket->data[0]) + nextPacket->length > actualEndPtr) {
            return false;
        }

        // All the data is accessible.
        // Advance to the next packet. Use MIDIPacketNext() to account for padding.
        nextPacket = MIDIPacketNext(nextPacket);
    }

    return true;
}

static CFDataRef LocalMessagePortCallback(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info)
{
    const UInt8 *bytes;
    CFIndex dataLength;
    SInt32 endpointUniqueID;
    const MIDIPacketList *packetList;
    CFIndex packetListLength;
    MIDIEndpointRef endpoint;
    MIDISpyClientRef clientRef = (MIDISpyClientRef)info;

    if (!data) {
        __Debug_String("MIDISpyClient: Got empty data from driver!");
        return NULL;
    }

    dataLength = CFDataGetLength(data);
    if (dataLength < (sizeof(SInt32) + sizeof(packetList->numPackets))) {
        __Debug_String("MIDISpyClient: Got too-small data from driver!");
        return NULL;
    }

    bytes = CFDataGetBytePtr(data);     // Guaranteed to be 16-byte aligned by CFData

    endpointUniqueID = *(SInt32 *)bytes;
    packetList = (const MIDIPacketList *)(bytes + sizeof(SInt32));
    packetListLength = dataLength - sizeof(SInt32);

    // Sanity check that this is a valid MIDIPacketList before we send it on.
    // Versions of the spying driver before 1.5.4 sometimes didn't send all of the data,
    // and it's possible that we are connecting to an old driver.
    if (!SanityCheckMIDIPacketList(packetList, packetListLength)) {
        __Debug_String("MIDISpyClient: Message is too small to contain the full packet list, dropping it");
        return NULL;
    }

    // Find the endpoint with this unique ID.
    // Then find all ports which are connected to this endpoint,
    // and for each, call port->readBlock().

    endpoint = EndpointWithUniqueID(endpointUniqueID);
    if (endpoint) {
        CFArrayRef connections;

        if ((connections = GetConnectionsToEndpoint(clientRef, endpoint))) {
            CFIndex connectionIndex;

            connectionIndex = CFArrayGetCount(connections);
            while (connectionIndex--) {
                MIDISpyPortConnection *connection;

                connection = (MIDISpyPortConnection *)CFArrayGetValueAtIndex(connections, connectionIndex);
                connection->port->readBlock(packetList, connection->refCon);
            }
        }        
    }

    // No reply
    return NULL;
}
