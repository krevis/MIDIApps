#if !defined(__SNOIZE_MIDISPYCLIENT__)
#define __SNOIZE_MIDISPYCLIENT__ 1

#include <CoreFoundation/CoreFoundation.h>
#include <CoreMIDI/CoreMIDI.h>

#if defined(__cplusplus)
extern "C" {
#endif

    
typedef struct __MIDISpyClient * MIDISpyClientRef;
typedef struct __MIDISpyPort * MIDISpyPortRef;
    
enum {
    kMIDISpyDriverAlreadyInstalled = 0,
    kMIDISpyDriverInstalledSuccessfully = 1,
    kMIDISpyDriverInstallationFailed = 2,
    kMIDISpyDriverCouldNotRemoveOldDriver = 3
};

enum {
    kMIDISpyDriverMissing = 1,
    kMIDISpyDriverCouldNotCommunicate = 2,
    kMIDISpyConnectionAlreadyExists = 3,
    kMIDISpyConnectionDoesNotExist = 4
};


extern SInt32 MIDISpyInstallDriverIfNecessary();

extern OSStatus MIDISpyClientCreate(MIDISpyClientRef *outClientRefPtr);
extern OSStatus MIDISpyClientDispose(MIDISpyClientRef clientRef);

extern OSStatus MIDISpyPortCreate(MIDISpyClientRef clientRef, MIDIReadProc readProc, void *refCon, MIDISpyPortRef *outSpyPortRefPtr);
extern OSStatus MIDISpyPortDispose(MIDISpyPortRef spyPortRef);

extern OSStatus MIDISpyPortConnectDestination(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint, void *connectionRefCon);
extern OSStatus MIDISpyPortDisconnectDestination(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint);


#if defined(__cplusplus)
}
#endif

#endif /* ! __SNOIZE_MIDISPYCLIENT__ */
