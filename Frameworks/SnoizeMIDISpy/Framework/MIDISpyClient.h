/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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
extern OSStatus MIDISpyClientDispose(MIDISpyClientRef clientRef);

extern OSStatus MIDISpyPortCreate(MIDISpyClientRef clientRef, MIDIReadProc readProc, void *refCon, MIDISpyPortRef *outSpyPortRefPtr);
extern OSStatus MIDISpyPortDispose(MIDISpyPortRef spyPortRef);

extern OSStatus MIDISpyPortConnectDestination(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint, void *connectionRefCon);
extern OSStatus MIDISpyPortDisconnectDestination(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint);


#if defined(__cplusplus)
}
#endif

#endif /* ! __SNOIZE_MIDISPYCLIENT__ */
