/*
 Copyright (c) 2001-2006, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */


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
    void EnableMonitoring(Boolean enable);

    CFMutableDataRef PackageMonitoredDataForBroadcast(MIDIEndpointRef destination, const MIDIPacketList *packetList);
    intptr_t SizeOfPacketList(const MIDIPacketList *packetList);

    
    MessagePortBroadcaster *mBroadcaster;
};

#endif // __SpyingMIDIDriver_h__
