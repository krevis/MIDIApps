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
    kMIDISpyDriverMissing = 1,
    kMIDISpyDriverCouldNotCommunicate = 2,
    kMIDISpyConnectionAlreadyExists = 3,
    kMIDISpyConnectionDoesNotExist = 4
};


extern OSStatus MIDISpyClientCreate(MIDISpyClientRef *outClientRefPtr);
extern OSStatus MIDISpyClientInvalidate(MIDISpyClientRef clientRef);
    // NOTE MIDISpyClientInvalidate() is really only present as a bug workaround -- see source for notes
extern OSStatus MIDISpyClientDispose(MIDISpyClientRef clientRef);

extern OSStatus MIDISpyPortCreate(MIDISpyClientRef clientRef, MIDIReadProc readProc, void *refCon, MIDISpyPortRef *outSpyPortRefPtr);
extern OSStatus MIDISpyPortDispose(MIDISpyPortRef spyPortRef);

extern OSStatus MIDISpyPortConnectDestination(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint, void *connectionRefCon);
extern OSStatus MIDISpyPortDisconnectDestination(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint);


#if defined(__cplusplus)
}
#endif

#endif /* ! __SNOIZE_MIDISPYCLIENT__ */
