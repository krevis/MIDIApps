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
    // TODO Can we make it a friend instead?
    void		RebuildEndpointUniqueIDMappings();

private:
    void		CheckCoreMIDIVersion();
    void		CreateMIDIClient();
    void		DisposeMIDIClient();
    void		EnableMonitoring(Boolean enable);
    UInt32		SizeOfPacketList(const MIDIPacketList *packetList);
    CFDataRef 	PackageMonitoredDataForBroadcast(const MIDIPacketList *packetList, SInt32 endpointUniqueID);
    
    bool 				mNeedsMonitorPointerWorkaround;
    MessagePortBroadcaster	*mBroadcaster;
    MIDIClientRef			mMIDIClientRef;
    CFMutableDictionaryRef	mEndpointRefToUniqueIDDictionary;
    pthread_mutex_t			mEndpointDictionaryMutex;
};

#endif // __SpyingMIDIDriver_h__
