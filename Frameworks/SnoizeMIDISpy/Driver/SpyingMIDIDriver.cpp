#include "SpyingMIDIDriver.h"

#include "MessagePortBroadcaster.h"
#include <pthread.h>


#define kFactoryUUID CFUUIDGetConstantUUIDWithBytes(NULL, 0x4F, 0xA1, 0x3C, 0x6B, 0x2D, 0x94, 0x11, 0xD6, 0x8C, 0x2F, 0x00, 0x0A, 0x27, 0xB4, 0x96, 0x5C)
// 4FA13C6B-2D94-11D6-8C2F-000A27B4965C


// Implementation of the factory function for this type.
extern "C" void *NewSpyingMIDIDriver(CFAllocatorRef allocator, CFUUIDRef typeID) 
{
    if (CFEqual(typeID, kMIDIDriverTypeID)) {
        SpyingMIDIDriver *result = new SpyingMIDIDriver;
        return result->Self();
    } else {
        return NULL;
    }
}


//
// Public functions
//

SpyingMIDIDriver::SpyingMIDIDriver() :
    MIDIDriver(kFactoryUUID),
    MessagePortBroadcasterDelegate(),
    mNeedsMonitorPointerWorkaround(false),
    mBroadcaster(NULL),
    mMIDIClientRef(NULL),
    mEndpointRefToUniqueIDDictionary(NULL)
{
    #if DEBUG
        fprintf(stderr, "SpyingMIDIDriver: Creating\n");
    #endif

    pthread_mutex_init(&mEndpointDictionaryMutex, NULL);
            
    mBroadcaster = new MessagePortBroadcaster(CFSTR("Spying MIDI Driver"), this);

    CheckCoreMIDIVersion();
}

SpyingMIDIDriver::~SpyingMIDIDriver()
{
    #if DEBUG
        fprintf(stderr, "SpyingMIDIDriver: Deleting\n");
    #endif

    pthread_mutex_destroy(&mEndpointDictionaryMutex);
    
    delete mBroadcaster;
}


OSStatus SpyingMIDIDriver::Monitor(MIDIEndpointRef destination, const MIDIPacketList *packetList)
{
    SInt32 endpointUniqueID;
    CFDataRef dataToBroadcast;

    #if DEBUG
        fprintf(stderr, "SpyingMIDIDriver: Monitor(destination %p, packet list %p)\n", destination, packetList);
        fprintf(stderr, "SpyingMIDIDriver: Monitor: mNeedsMonitorPointerWorkaround is %d\n", mNeedsMonitorPointerWorkaround);
    #endif

    if (mNeedsMonitorPointerWorkaround) {
        // Under 10.1.3 and earlier, we are really given a pointer to a MIDIEndpointRef, not the MIDIEndpointRef itself.
        // This is Radar #2877457; Doug Wyatt claims the bug will be fixed "in the next rev".
        destination = *(MIDIEndpointRef *)destination;        
    }

    #if DEBUG
        fprintf(stderr, "SpyingMIDIDriver: Monitor: dereferenced pointer successfully\n");
    #endif
    
    // Look up the unique ID for this destination. Lock around this in case we are modifying the endpoint dictionary in the main thread.
    pthread_mutex_lock(&mEndpointDictionaryMutex);
    if (mEndpointRefToUniqueIDDictionary)
        endpointUniqueID = (SInt32)CFDictionaryGetValue(mEndpointRefToUniqueIDDictionary, destination);
    else
        endpointUniqueID = 0;
    pthread_mutex_unlock(&mEndpointDictionaryMutex);

    #if DEBUG
        fprintf(stderr, "SpyingMIDIDriver: Monitor: unique ID is %ld\n", endpointUniqueID);
    #endif
    
    // Then package up the data (packet list and uniqueID) and broadcast it.
    dataToBroadcast = PackageMonitoredDataForBroadcast(packetList, endpointUniqueID);
    if (dataToBroadcast) {
        #if DEBUG
                fprintf(stderr, "SpyingMIDIDriver: Monitor: broadcasting\n");
        #endif
        mBroadcaster->Broadcast(dataToBroadcast, endpointUniqueID);
        CFRelease(dataToBroadcast);
    }

    #if DEBUG
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

void SpyingMIDIDriver::CreateMIDIClient()
{
    OSStatus status;

    #if DEBUG
        fprintf(stderr, "SpyingMIDIDriver: creating MIDI client\n");
    #endif

    status = MIDIClientCreate(CFSTR("Spying MIDI Driver"), MIDIClientNotificationProc, this, &mMIDIClientRef);
    if (status != noErr) {
        #if DEBUG
            fprintf(stderr, "Spy driver: MIDIClientCreate() returned error: %ld\n", status);
        #endif
    }    
}

void SpyingMIDIDriver::DisposeMIDIClient()
{
    OSStatus status;

    if (!mMIDIClientRef)
        return;
    
    #if DEBUG
        fprintf(stderr, "SpyingMIDIDriver: disposing MIDI client\n");
    #endif
    
    status = MIDIClientDispose(mMIDIClientRef);
    if (status != noErr) {
        #if DEBUG
                fprintf(stderr, "Spy driver: MIDIClientDispose() returned error: %ld\n", status);
        #endif
    }

    mMIDIClientRef = NULL;
}

void MIDIClientNotificationProc(const MIDINotification *message, void *refCon)
{
    #if DEBUG
        fprintf(stderr, "Spy driver: notification proc called\n");
    #endif

    ((SpyingMIDIDriver *)refCon)->RebuildEndpointUniqueIDMappings();

    #if DEBUG
        fprintf(stderr, "Spy driver: notification proc done\n");
    #endif
}

void SpyingMIDIDriver::RebuildEndpointUniqueIDMappings()
{
    CFMutableDictionaryRef newDictionary;
    ItemCount destinationCount, destinationIndex;

    #if DEBUG
        fprintf(stderr, "Spy driver: calling MIDIGetNumberOfDestinations\n");
    #endif
    destinationCount = MIDIGetNumberOfDestinations();
    #if DEBUG
        fprintf(stderr, "Spy driver: got %lu destinations\n", destinationCount);
    #endif
    
    newDictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, destinationCount, NULL, NULL);

    for (destinationIndex = 0; destinationIndex < destinationCount; destinationIndex++) {
        MIDIEndpointRef endpointRef;

        #if DEBUG
            fprintf(stderr, "Spy driver: getting destination at index %lu\n", destinationIndex);
        #endif
        endpointRef = MIDIGetDestination(destinationIndex);
        #if DEBUG
            fprintf(stderr, "Spy driver: destination at index %lu is %p\n", destinationIndex, endpointRef);
        #endif
        if (endpointRef) {
            SInt32 uniqueID;

            #if DEBUG
                fprintf(stderr, "Spy driver: getting unique ID\n");
            #endif
            if (noErr == MIDIObjectGetIntegerProperty(endpointRef, kMIDIPropertyUniqueID, &uniqueID)) {
                #if DEBUG
                    fprintf(stderr, "Spy driver: got unique ID: %ld\n", uniqueID);
                #endif
                CFDictionaryAddValue(newDictionary, (void *)endpointRef, (void *)uniqueID);
            }
        }
    }

    #if DEBUG
        fprintf(stderr, "Spy driver: locking\n");
    #endif
    pthread_mutex_lock(&mEndpointDictionaryMutex);
    #if DEBUG
        fprintf(stderr, "Spy driver: locked\n");
    #endif

    #if DEBUG
        fprintf(stderr, "Spy driver: release old dict\n");
    #endif
    if (mEndpointRefToUniqueIDDictionary)
        CFRelease(mEndpointRefToUniqueIDDictionary);
    mEndpointRefToUniqueIDDictionary = newDictionary;

    #if DEBUG
        fprintf(stderr, "Spy driver: unlocking\n");
    #endif
    pthread_mutex_unlock(&mEndpointDictionaryMutex);
    #if DEBUG
        fprintf(stderr, "Spy driver: unlocked\n");
    #endif
}

void SpyingMIDIDriver::EnableMonitoring(Boolean enabled)
{
    OSStatus status;

    if (enabled) {
        CreateMIDIClient();
        RebuildEndpointUniqueIDMappings();
    } else {        
        DisposeMIDIClient();
    }
    
    status = MIDIDriverEnableMonitoring(Self(), enabled);
    #if DEBUG
        if (status == noErr)
            fprintf(stderr, "SpyingMIDIDriver: MIDIDriverEnableMonitoring(%d) succeeded!\n", enabled);
        else
            fprintf(stderr, "SpyingMIDIDriver: MIDIDriverEnableMonitoring(%d) failed: %ld\n", enabled, status);
    #endif
}

CFDataRef SpyingMIDIDriver::PackageMonitoredDataForBroadcast(const MIDIPacketList *packetList, SInt32 endpointUniqueID)
{
    UInt32 packetListSize, totalSize;
    CFMutableDataRef data;
    UInt8 *dataBuffer;

    packetListSize = SizeOfPacketList(packetList);
    totalSize = packetListSize + sizeof(SInt32);
    
    data = CFDataCreateMutable(kCFAllocatorDefault, totalSize);
    CFDataSetLength(data, totalSize);
    dataBuffer = CFDataGetMutableBytePtr(data);
    if (dataBuffer) {
        *(SInt32 *)dataBuffer = endpointUniqueID;
        memcpy(dataBuffer + sizeof(SInt32), packetList, packetListSize);
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
