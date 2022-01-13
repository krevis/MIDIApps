/*
 Copyright (c) 2001-2018, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

#if !defined(__SNOIZE_MIDISPYCLIENT__)
#define __SNOIZE_MIDISPYCLIENT__ 1

#include <AssertMacros.h>
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
extern OSStatus MIDISpyClientDispose(MIDISpyClientRef clientRef);

extern void MIDISpyClientDisposeSharedMIDIClient(void);
    // Use only in special circumstances, if you want to remove the app's connection to the MIDIServer

extern OSStatus MIDISpyPortCreate(MIDISpyClientRef clientRef, MIDIReadBlock readBlock, MIDISpyPortRef *outSpyPortRefPtr);
extern OSStatus MIDISpyPortDispose(MIDISpyPortRef spyPortRef);

extern OSStatus MIDISpyPortConnectDestination(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint, void *connectionRefCon);
extern OSStatus MIDISpyPortDisconnectDestination(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint);


#if defined(__cplusplus)
}
#endif

#endif /* ! __SNOIZE_MIDISPYCLIENT__ */
