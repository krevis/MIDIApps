#include "SpyingMIDIDriver.h"

#include "MessageQueue.h"
#include "MessagePortBroadcaster.h"
#include <pthread.h>


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
    mNeedsMonitorPointerWorkaround(false),
    mBroadcaster(NULL)
{
    #if DEBUG
        fprintf(stderr, "SpyingMIDIDriver: Creating\n");
    #endif

    mBroadcaster = new MessagePortBroadcaster(CFSTR("Spying MIDI Driver"), this);
    // NOTE This might raise an exception; we let it propagate upwards.

    CreateMessageQueue(messageQueueHandler, mBroadcaster);
    
    CheckCoreMIDIVersion();
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

    #if DEBUG && 0
        fprintf(stderr, "SpyingMIDIDriver: Monitor(destination %p, packet list %p)\n", destination, packetList);
        fprintf(stderr, "SpyingMIDIDriver: Monitor: mNeedsMonitorPointerWorkaround is %d\n", mNeedsMonitorPointerWorkaround);
    #endif

    if (mNeedsMonitorPointerWorkaround) {
        // Under Mac OS X 10.1.3 and earlier, we are really given a pointer to a MIDIEndpointRef, not the MIDIEndpointRef itself.
        // This is Radar #2877457. The bug was fixed in 10.2.
        destination = *(MIDIEndpointRef *)destination;        
    }

    #if DEBUG && 0
        fprintf(stderr, "SpyingMIDIDriver: Monitor: dereferenced pointer successfully\n");
    #endif

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

void SpyingMIDIDriver::CheckCoreMIDIVersion()
{
    CFBundleRef coreMIDIServerBundle;

    // Check the CoreMIDIServer's version to see if we need to work around a bug.
    coreMIDIServerBundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.audio.midi.CoreMIDIServer"));
    if (coreMIDIServerBundle) {
        UInt32 version;

        version =  CFBundleGetVersionNumber(coreMIDIServerBundle);
        if (version < 0x18008000)	// 18.0 release, which is the version in which this bug should be fixed
            mNeedsMonitorPointerWorkaround = true;
        #if DEBUG
            fprintf(stderr, "CoreMIDIServer version is %lx, so needs workaround = %d\n", version, mNeedsMonitorPointerWorkaround);
        #endif
    } else {
        #if DEBUG
            fprintf(stderr, "Couldn't find bundle for CoreMIDIServer (com.apple.audio.midi.CoreMIDIServer)\n");
        #endif
    }   
}

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
