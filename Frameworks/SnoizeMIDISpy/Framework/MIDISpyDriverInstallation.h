#if !defined(__SNOIZE_MIDISPYDRIVERINSTALLATION__)
#define __SNOIZE_MIDISPYDRIVERINSTALLATION__ 1

#include <CoreFoundation/CoreFoundation.h>

#if defined(__cplusplus)
extern "C" {
#endif

    
enum {
    kMIDISpyDriverAlreadyInstalled = 0,
    kMIDISpyDriverInstalledSuccessfully = 1,
    kMIDISpyDriverInstallationFailed = 2,
    kMIDISpyDriverCouldNotRemoveOldDriver = 3
};


extern SInt32 MIDISpyInstallDriverIfNecessary();


#if defined(__cplusplus)
}
#endif

#endif /* ! __SNOIZE_MIDISPYDRIVERINSTALLATION__ */
