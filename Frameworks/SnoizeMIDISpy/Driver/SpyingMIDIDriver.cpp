#include "SpyingMIDIDriver.h"
#include "MessagePortBroadcaster.h"
#include "MessageQueue.h"

#define kFactoryUUID CFUUIDGetConstantUUIDWithBytes(NULL, 0x4F, 0xA1, 0x3C, 0x6B, 0x2D, 0x94, 0x11, 0xD6, 0x8C, 0x2F, 0x00, 0x0A, 0x27, 0xB4, 0x96, 0x5C)
// 4FA13C6B-2D94-11D6-8C2F-000A27B4965C


// __________________________________________________________________________________________________


// Implementation of the factory function for this type.
extern "C" void *NewSpyingMIDIDriver(CFAllocatorRef allocator, CFUUIDRef typeID);
extern "C" void *NewSpyingMIDIDriver(CFAllocatorRef allocator, CFUUIDRef typeID) 
{
    if (CFEqual(typeID, kMIDIDriverTypeID)) {
        SpyingMIDIDriver *result = new SpyingMIDIDriver;
        return result->Self();
    } else {
        return NULL;
    }
}

// __________________________________________________________________________________________________

SpyingMIDIDriver::SpyingMIDIDriver() :
    MIDIDriver(kFactoryUUID),
    MessagePortBroadcasterDelegate(),
    mNeedsMonitorPointerWorkaround(false),
    mMessagePortBroadcaster(NULL)
{
#if DEBUG
    fprintf(stderr, "SpyingMIDIDriver: Creating\n");
#endif

    mMessagePortBroadcaster = new MessagePortBroadcaster(CFSTR("Spying MIDI Driver"), this);

    CheckCoreMIDIVersion();
}

SpyingMIDIDriver::~SpyingMIDIDriver()
{
#if DEBUG
    fprintf(stderr, "SpyingMIDIDriver: Deleting\n");
#endif

    delete mMessagePortBroadcaster;
}

// __________________________________________________________________________________________________

extern "C" {
    static void processDataFromMessageQueue(CFDataRef dataFromQueue, void *refCon);   
}


OSStatus SpyingMIDIDriver::Start(MIDIDeviceListRef devList)
{
    CreateMessageQueue(processDataFromMessageQueue, this);
    
    return noErr;    
}

OSStatus SpyingMIDIDriver::Stop()
{
    EnableMonitoring(FALSE);
    DestroyMessageQueue();

    return noErr;
}

OSStatus SpyingMIDIDriver::Monitor(MIDIEndpointRef destination, const MIDIPacketList *packetList)
{
    CFDataRef packagedData;

    if (mNeedsMonitorPointerWorkaround) {
        // Under 10.1.3 and earlier, we are really given a pointer to a MIDIEndpointRef, not the MIDIEndpointRef itself.
        // This is Radar #2877457; Doug Wyatt claims the bug will be fixed "in the next rev".
        destination = *(MIDIEndpointRef *)destination;        
    }
    
#if DEBUG && 0
    {
        UInt32 packetIndex;
        const MIDIPacket *packet;
        
        printf("Monitor got packet list with destination %p\n", (void *)destination);
        printf("   Packet list has %lu packets\n", packetList->numPackets);

        packet = &packetList->packet[0];
        for (packetIndex = 0; packetIndex < packetList->numPackets; packetIndex++, packet = MIDIPacketNext(packet)) {
            printf("   Packet %lu: time stamp %qu, size %hu\n", packetIndex, packet->timeStamp, packet->length);
        }
    }
#endif

    packagedData = PackageMonitoredDataForMessageQueue(destination, packetList);
    AddToMessageQueue(packagedData);
    CFRelease(packagedData);
    // processDataFromMessageQueue(packagedData, self) will happen in the main thread
        
    return noErr;
}

void SpyingMIDIDriver::BroadcasterListenerCountChanged(MessagePortBroadcaster *broadcaster, bool hasListeners)
{
    EnableMonitoring(hasListeners);
}

// __________________________________________________________________________________________________
//
// Private methods
//

void SpyingMIDIDriver::CheckCoreMIDIVersion()
{
    CFBundleRef coreMIDIServerBundle;

    // Check if CoreMIDIServer is the version in MacOS X 10.1.3 or earlier; if so, then we need to work around a bug.
    coreMIDIServerBundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.audio.midi.CoreMIDIServer"));
    if (coreMIDIServerBundle) {
        UInt32 version;

        version =  CFBundleGetVersionNumber(coreMIDIServerBundle);
        if (version <= 0x15108000)	// 15.1, the version as of 10.1.3
            mNeedsMonitorPointerWorkaround = true;
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
#if DEBUG && 1
    if (status == noErr)
        fprintf(stderr, "SpyingMIDIDriver: MIDIDriverEnableMonitoring(%d) succeeded!\n", enabled);
    else
        fprintf(stderr, "SpyingMIDIDriver: MIDIDriverEnableMonitoring(%d) failed: %ld\n", enabled, status);
#endif
}

CFDataRef SpyingMIDIDriver::PackageMonitoredDataForMessageQueue(MIDIEndpointRef endpointRef, const MIDIPacketList *packetList)
{
    CFMutableDataRef data;
    UInt32 packetListLength, dataLength;

    packetListLength = SizeOfPacketList(packetList);
    dataLength = sizeof(MIDIEndpointRef) + packetListLength;

    data = CFDataCreateMutable(kCFAllocatorDefault, dataLength);
    CFDataAppendBytes(data, (const UInt8 *)&endpointRef, sizeof(MIDIEndpointRef));
    CFDataAppendBytes(data, (const UInt8 *)packetList, packetListLength);

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

static void processDataFromMessageQueue(CFDataRef dataFromQueue, void *refCon)
{
    const UInt8 *dataBytes;
    MIDIEndpointRef destination;
    const MIDIPacketList *packetList;

    // Unpackage the data
    dataBytes = CFDataGetBytePtr(dataFromQueue);
    destination = *(MIDIEndpointRef *)dataBytes;
    packetList = (const MIDIPacketList *)(dataBytes + sizeof(MIDIEndpointRef));

    ((SpyingMIDIDriver *)refCon)->MonitorInMainThread(destination, packetList);
}

void SpyingMIDIDriver::MonitorInMainThread(MIDIEndpointRef destination, const MIDIPacketList *packetList)
{
    OSStatus status;
    SInt32 endpointUniqueID = 0;
    CFDataRef dataToBroadcast = NULL;
    
    status = MIDIObjectGetIntegerProperty(destination, kMIDIPropertyUniqueID, &endpointUniqueID);
    if (status != noErr) {
#if DEBUG
        fprintf(stderr, "SpyingMIDIDriver: MIDIObjectGetIntegerProperty failed: %ld\n", status);
#endif
    }

#if DEBUG && 0
    fprintf(stderr, "got data for destination %p with unique ID %ld\n", (void *)destination, endpointUniqueID);
#endif

    // TODO Need to change the way this broadcaster works.  We should only broadcast to those clients
    // who are interested in this particular endpoint (uniqueID).
    
    dataToBroadcast = PackageMonitoredDataForBroadcast(packetList, endpointUniqueID);
    if (dataToBroadcast) {
        mMessagePortBroadcaster->Broadcast(dataToBroadcast);
        CFRelease(dataToBroadcast);
    }
}

CFDataRef SpyingMIDIDriver::PackageMonitoredDataForBroadcast(const MIDIPacketList *packetList, SInt32 endpointUniqueID)
{
    UInt32 packetListSize, totalSize;
    CFMutableDataRef data;

    packetListSize = SizeOfPacketList(packetList);
    totalSize = packetListSize + sizeof(SInt32);
    
    data = CFDataCreateMutable(kCFAllocatorDefault, totalSize);
    if (data) {
        CFDataAppendBytes(data, (const UInt8 *)&endpointUniqueID, sizeof(SInt32));
        CFDataAppendBytes(data, (const UInt8 *)packetList, packetListSize);
    }

    return data;
}
