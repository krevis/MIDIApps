#ifndef __SpyingMIDIDriver_h__
#define __SpyingMIDIDriver_h__

#include "MIDIDriverClass.h"
#include "MessagePortBroadcaster.h"


class SpyingMIDIDriver : public MIDIDriver, public MessagePortBroadcasterDelegate {
public:
    SpyingMIDIDriver();
    virtual ~SpyingMIDIDriver();

    // MIDIDriver overrides
     virtual OSStatus Monitor(MIDIEndpointRef dest, const MIDIPacketList *pktlist);

    // MessagePortBroadcasterDelegate overrides
    virtual void BroadcasterListenerCountChanged(MessagePortBroadcaster *broadcaster, bool hasListeners);
    
private:
    void CheckCoreMIDIVersion();

    void EnableMonitoring(Boolean enable);

    CFMutableDataRef PackageMonitoredDataForBroadcast(MIDIEndpointRef destination, const MIDIPacketList *packetList);
    UInt32 SizeOfPacketList(const MIDIPacketList *packetList);

    
    bool mNeedsMonitorPointerWorkaround;
    MessagePortBroadcaster *mBroadcaster;
};

#endif // __SpyingMIDIDriver_h__
