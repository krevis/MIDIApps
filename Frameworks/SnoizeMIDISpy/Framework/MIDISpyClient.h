#if !defined(__SNOIZE_MIDISPYCLIENT__)
#define __SNOIZE_MIDISPYCLIENT__ 1

#include <CoreFoundation/CoreFoundation.h>
#include <CoreMIDI/CoreMIDI.h>

#if defined(__cplusplus)
extern "C" {
#endif
    
typedef struct __MIDISpyClient * MIDISpyClientRef;

typedef void (*MIDISpyClientCallBack)(SInt32 endpointUniqueID, CFStringRef endpointName, const MIDIPacketList *packetList, void *refCon);

enum {
    kMIDISpyDriverAlreadyInstalled = 0,
    kMIDISpyDriverInstalledSuccessfully = 1,
    kMIDISpyDriverInstallationFailed = 2
};

SInt32 MIDISpyInstallDriverIfNecessary();

MIDISpyClientRef MIDISpyClientCreate(MIDISpyClientCallBack callBack, void *refCon);
void MIDISpyClientDispose(MIDISpyClientRef clientRef);

// TODO functions for putting the spy driver in place, etc.


#if defined(__cplusplus)
}
#endif

#endif /* ! __SNOIZE_MIDISPYCLIENT__ */
