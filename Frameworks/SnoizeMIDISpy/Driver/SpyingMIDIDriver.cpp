/*
 Copyright (c) 2001-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "SpyingMIDIDriver.h"

#include "MessageQueue.h"
#include "MessagePortBroadcaster.h"


#define kFactoryUUID CFUUIDGetConstantUUIDWithBytes(NULL, 0x4F, 0xA1, 0x3C, 0x6B, 0x2D, 0x94, 0x11, 0xD6, 0x8C, 0x2F, 0x00, 0x0A, 0x27, 0xB4, 0x96, 0x5C)
// 4FA13C6B-2D94-11D6-8C2F-000A27B4965C


// Implementation of the factory function for this type.
extern "C" void *NewSpyingMIDIDriver(CFAllocatorRef allocator, CFUUIDRef typeID) 
{
    if (CFEqual(typeID, kMIDIDriverTypeID)) {
        try {
            SpyingMIDIDriver *result = new SpyingMIDIDriver;
            return result->Self();
        } catch (...) {
            #if DEBUG
                fprintf(stderr, "MIDI Monitor driver: an exception was raised, so the driver is not being instantiated\n");
            #endif
            return NULL;
        }
    } else {
        return NULL;
    }
}

//
// Internal static functions
//

static void messageQueueHandler(CFTypeRef objectFromQueue, void *refCon);


//
// Public functions
//

SpyingMIDIDriver::SpyingMIDIDriver() :
    MIDIDriver(kFactoryUUID),
    MessagePortBroadcasterDelegate(),
    mBroadcaster(NULL)
{
    #if DEBUG
        fprintf(stderr, "SpyingMIDIDriver: Creating\n");
    #endif

    mBroadcaster = new MessagePortBroadcaster(CFSTR("Spying MIDI Driver"), this);
    // NOTE This might raise an exception; we let it propagate upwards.

    CreateMessageQueue(messageQueueHandler, mBroadcaster);
}

SpyingMIDIDriver::~SpyingMIDIDriver()
{
    #if DEBUG
        fprintf(stderr, "SpyingMIDIDriver: Deleting\n");
    #endif

    DestroyMessageQueue();

    delete mBroadcaster;
}

OSStatus SpyingMIDIDriver::Monitor(MIDIEndpointRef destination, const MIDIPacketList *packetList)
{
    CFMutableDataRef dataToBroadcast;

    // Since we are running in the MIDIServer's processing thread, broadcasting now could bog down MIDI processing badly.
    // (I think that CFMessagePortSendRequest() must block, or somehow take a lot of time.)
    // So instead, use the message queue to cause it to happen in the main thread instead.
    
    // Package up the packet list and destination, and pass them to the main thread.
    // (The main thread will look up the destination's unique ID before broadcasting the data.)
    dataToBroadcast = PackageMonitoredDataForBroadcast(destination, packetList);
    if (dataToBroadcast) {
        AddToMessageQueue(dataToBroadcast);
        CFRelease(dataToBroadcast);
    }
    // TODO The above code needs to create an object which could block on the global malloc lock.
    // It would be better to avoid allocation by using a shared lockless ring buffer.
    // Once we get that working in SnoizeMIDI, we ought to be able to reuse it here.

    #if DEBUG && 0
        fprintf(stderr, "SpyingMIDIDriver: Monitor: done\n");
    #endif
    
    return noErr;
}

void SpyingMIDIDriver::BroadcasterListenerCountChanged(MessagePortBroadcaster *broadcaster, bool hasListeners)
{
    EnableMonitoring(hasListeners);
}


//
// Private functions
//

void SpyingMIDIDriver::EnableMonitoring(Boolean enabled)
{
    OSStatus status;

    status = MIDIDriverEnableMonitoring(Self(), enabled);
    #if DEBUG
        if (status == noErr)
            fprintf(stderr, "SpyingMIDIDriver: MIDIDriverEnableMonitoring(%d) succeeded!\n", enabled);
        else
            fprintf(stderr, "SpyingMIDIDriver: MIDIDriverEnableMonitoring(%d) failed: %ld\n", enabled, status);
    #endif
}

CFMutableDataRef SpyingMIDIDriver::PackageMonitoredDataForBroadcast(MIDIEndpointRef destination, const MIDIPacketList *packetList)
{
    UInt32 packetListSize, totalSize;
    CFMutableDataRef data;
    UInt8 *dataBuffer;

    packetListSize = SizeOfPacketList(packetList);
    totalSize = sizeof(MIDIEndpointRef) + packetListSize;

    data = CFDataCreateMutable(kCFAllocatorDefault, totalSize);
    if (data) {
        CFDataSetLength(data, totalSize);
        dataBuffer = CFDataGetMutableBytePtr(data);
        if (dataBuffer) {
            *(MIDIEndpointRef *)dataBuffer = destination;
            memcpy(dataBuffer + sizeof(MIDIEndpointRef), packetList, packetListSize);
        } else {
            CFRelease(data);
            data = NULL;
        }
    }

    return data;
}

UInt32 SpyingMIDIDriver::SizeOfPacketList(const MIDIPacketList *packetList)
{
    UInt32 packetCount;
    UInt32 packetListSize;
    const MIDIPacket *packet;

    packetListSize = offsetof(MIDIPacketList, packet);

    packetCount = packetList->numPackets;
    packet = &packetList->packet[0];
    while (packetCount--) {
        packetListSize += offsetof(MIDIPacket, data);
        packetListSize += packet->length;
        packet = MIDIPacketNext(packet);
    }

    return packetListSize;
}

void messageQueueHandler(CFTypeRef objectFromQueue, void *refCon)
{
    CFMutableDataRef data = (CFMutableDataRef)objectFromQueue;
    MessagePortBroadcaster *broadcaster = (MessagePortBroadcaster *)refCon;
    UInt8 *dataBuffer;
    MIDIEndpointRef destination;
    SInt32 uniqueID;

    if (!data)
        return;

    dataBuffer = CFDataGetMutableBytePtr(data);
    if (!dataBuffer)
        return;

    // The destination endpoint is stored in the first 4 bytes of the data.
    // This value isn't valid in other processes (like the one that will receive this),
    // so replace it with the unique ID of the endpoint.

    destination = *(MIDIEndpointRef *)dataBuffer;
    if (noErr == MIDIObjectGetIntegerProperty(destination, kMIDIPropertyUniqueID, &uniqueID)) {
        *(SInt32 *)dataBuffer = uniqueID;

        // Now broadcast the data to everyone listening to data for this endpoint.
        broadcaster->Broadcast(data, uniqueID);
    }

    // Don't release the data; the message queue will do that for us.
}
