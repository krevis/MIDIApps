/*=============================================================================
	MIDIDriverClass.h
	
=============================================================================*/
/*
	Copyright: 	© Copyright 2000 Apple Computer, Inc. All rights reserved.

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
			("Apple") in consideration of your agreement to the following terms, and your
			use, installation, modification or redistribution of this Apple software
			constitutes acceptance of these terms.  If you do not agree with these terms,
			please do not use, install, modify or redistribute this Apple software.

			In consideration of your agreement to abide by the following terms, and subject
			to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
			copyrights in this original Apple software (the "Apple Software"), to use,
			reproduce, modify and redistribute the Apple Software, with or without
			modifications, in source and/or binary forms; provided that if you redistribute
			the Apple Software in its entirety and without modifications, you must retain
			this notice and the following text and disclaimers in all such redistributions of
			the Apple Software.  Neither the name, trademarks, service marks or logos of
			Apple Computer, Inc. may be used to endorse or promote products derived from the
			Apple Software without specific prior written permission from Apple.  Except as
			expressly stated in this notice, no other rights or licenses, express or implied,
			are granted by Apple herein, including but not limited to any patent rights that
			may be infringed by your derivative works or by other works in which the Apple
			Software may be incorporated.

			The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
			WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
			WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
			PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
			COMBINATION WITH YOUR PRODUCTS.

			IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
			CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
			GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
			ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
			OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
			(INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
			ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#ifndef __MIDIDriverClass_h__
#define __MIDIDriverClass_h__

// Use new header; this requires 10.6 SDK and runtime
#include <CoreMIDI/MIDIDriver.h>

#ifndef V1_MIDI_DRIVER_SUPPORT
	#define V1_MIDI_DRIVER_SUPPORT	0
#endif

#ifndef V2_MIDI_DRIVER_SUPPORT
	#define V2_MIDI_DRIVER_SUPPORT	1
#endif

//____________________________________________________________________________
//	MIDIDriver
//
//	Minimal C++ base class for Mac OS X MIDI drivers.
//
//	See the descriptions of the function pointers with the same names in 
//	struct MIDIDriverInterface, CoreMIDIServer/MIDIDriver.h
class MIDIDriver {
public:
	MIDIDriver(CFUUIDRef factoryID);
	virtual ~MIDIDriver();

	virtual OSStatus	FindDevices(MIDIDeviceListRef devList) { return noErr; }
	virtual OSStatus	Start(MIDIDeviceListRef devList) { return noErr; }
	virtual OSStatus	Stop() { return noErr; }
	virtual OSStatus	Configure(MIDIDeviceRef device) { return noErr; }
	virtual OSStatus	Send(const MIDIPacketList *pklist, void *destRefCon1, void *destRefCon2) 
							{ return noErr; }
	virtual OSStatus	EnableSource(MIDIEndpointRef src, Boolean enabled) { return noErr; }

	// below are for V2 only
	virtual OSStatus	Flush(MIDIEndpointRef dest, void *destRefCon1, void *destRefCon2) { return noErr; }
	virtual OSStatus	Monitor(MIDIEndpointRef dest, const MIDIPacketList *pktlist) { return noErr; }
	
	MIDIDriverRef		Self() { return &mInterface; }

public:
	MIDIDriverInterface *	mInterface;		// keep this first
	CFUUIDRef				mFactoryID;
	UInt32					mRefCount;
	int						mVersion;		// which version of the interface the server asked for
};

// inverse of MIDIDriver::Self() method.
// MIDIDriverRef is a pointer to the mInterface member of MIDIDriver
// To avoid assuming that the C++ compiler places this member at offset 0
// of the structure, use this inline function to get from the MIDIDriverRef
// to the MIDIDriver pointer.
inline MIDIDriver *	GetMIDIDriver(MIDIDriverRef ref)
{
	MIDIDriver *p = (MIDIDriver *)ref;
	return (MIDIDriver *)((Byte *)p - ((Byte *)&p->mInterface - (Byte *)p));
}

#if V1_MIDI_DRIVER_SUPPORT && V2_MIDI_DRIVER_SUPPORT
	#define MIDI_WEAK_LINK_TO_V2_CALLS 1
	#include "MIDIBackCompatible.h"
#endif

#endif // __MIDIDriverClass_h__
