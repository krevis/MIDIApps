#ifndef __SpyingMIDIDriver_h__
#define __SpyingMIDIDriver_h__

#include "MIDIDriverClass.h"
#include "MessagePortBroadcaster.h"
#include <AvailabilityMacros.h>


class SpyingMIDIDriver : public MIDIDriver, public MessagePortBroadcasterDelegate {
public:
    SpyingMIDIDriver();
    virtual ~SpyingMIDIDriver();

    // MIDIDriver overrides
     virtual OSStatus Monitor(MIDIEndpointRef dest, const MIDIPacketList *pktlist);

    // MessagePortBroadcasterDelegate overrides
    virtual void BroadcasterListenerCountChanged(MessagePortBroadcaster *broadcaster, bool hasListeners);
    
private:
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_2
    void CheckCoreMIDIVersion();
#endif

    void EnableMonitoring(Boolean enable);

    CFMutableDataRef PackageMonitoredDataForBroadcast(MIDIEndpointRef destination, const MIDIPacketList *packetList);
    UInt32 SizeOfPacketList(const MIDIPacketList *packetList);


#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_2
    bool mNeedsMonitorPointerWorkaround;
#endif
    MessagePortBroadcaster *mBroadcaster;
};

#endif // __SpyingMIDIDriver_h__
