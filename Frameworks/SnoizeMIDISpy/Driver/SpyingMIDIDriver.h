#ifndef __SpyingMIDIDriver_h__
#define __SpyingMIDIDriver_h__

#include "MIDIDriverClass.h"
#include "MessagePortBroadcaster.h"


class SpyingMIDIDriver : public MIDIDriver, public MessagePortBroadcasterDelegate {
public:
    SpyingMIDIDriver();
    ~SpyingMIDIDriver();

    // MIDIDriver overrides
    virtual OSStatus	Start(MIDIDeviceListRef devList);
    virtual OSStatus	Stop();
    virtual OSStatus	Monitor(MIDIEndpointRef dest, const MIDIPacketList *pktlist);

    // MessagePortBroadcasterDelegate overrides
    virtual void 	BroadcasterListenerCountChanged(MessagePortBroadcaster *broadcaster, bool hasListeners);
    
    // This needs to be public in order to call it from a C callback. Annoying.
    void 		MonitorInMainThread(MIDIEndpointRef destination, const MIDIPacketList *packetList);

private:
    void		CheckCoreMIDIVersion();
    void		EnableMonitoring(Boolean enable);
    CFDataRef		PackageMonitoredDataForMessageQueue(MIDIEndpointRef endpointRef, const MIDIPacketList *packetList);
    UInt32		SizeOfPacketList(const MIDIPacketList *packetList);
    CFDataRef 	PackageMonitoredDataForBroadcast(const MIDIPacketList *packetList, SInt32 endpointUniqueID);
    
    bool 				mNeedsMonitorPointerWorkaround;
    MessagePortBroadcaster	*mMessagePortBroadcaster;
};

#endif // __SpyingMIDIDriver_h__
