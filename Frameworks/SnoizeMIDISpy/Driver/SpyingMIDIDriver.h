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

    void CreateMIDIClient();
    void DisposeMIDIClient();
    friend void MIDIClientNotificationProc(const MIDINotification *message, void *refCon);
    void RebuildEndpointUniqueIDMappings();

    void EnableMonitoring(Boolean enable);

    CFDataRef PackageMonitoredDataForBroadcast(const MIDIPacketList *packetList, SInt32 endpointUniqueID);
    UInt32 SizeOfPacketList(const MIDIPacketList *packetList);

    
    bool mNeedsMonitorPointerWorkaround;
    MessagePortBroadcaster *mBroadcaster;
    MIDIClientRef mMIDIClientRef;
    CFMutableDictionaryRef mEndpointRefToUniqueIDDictionary;
    pthread_mutex_t	 mEndpointDictionaryMutex;
};

#endif // __SpyingMIDIDriver_h__
