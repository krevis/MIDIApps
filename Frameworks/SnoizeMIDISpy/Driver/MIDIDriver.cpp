/*=============================================================================
	MIDIDriver.cpp
	
=============================================================================*/
/*
	Copyright: 	© Copyright 2000 Apple Computer, Inc. All rights reserved.

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
			("Apple") in consideration of your agreement to the following terms, and your
			use, installation, modification or redistribution of this Apple software
			constitutes acceptance of these terms.  If you do not agree with these terms,
			please do not use, install, modify or redistribute this Apple software.

			In consideration of your agreement to abide by the following terms, and subject
			to these terms, Apple grants you a personal, non-exclusive license, under AppleÕs
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

// A CFPlugin MIDIDriver using a C interface to CFPlugin, but calling a C++ class to do the work.

#include "MIDIDriverClass.h"

// Implementation of the IUnknown QueryInterface function.
static HRESULT MIDIDriverQueryInterface(void *thisPointer, REFIID iid, LPVOID *ppv) 
{
	MIDIDriverRef ref = (MIDIDriverRef)thisPointer;

	// Create a CoreFoundation UUIDRef for the requested interface.
	CFUUIDRef interfaceID = CFUUIDCreateFromUUIDBytes( NULL, iid );

#if V2_MIDI_DRIVER_SUPPORT
	if (CFEqual(interfaceID, kMIDIDriverInterface2ID)) {
		// If the MIDIDriverInterface was requested, bump the ref count,
		// set the ppv parameter equal to the instance, and
		// return good status.
		MIDIDriver *self = GetMIDIDriver(ref);
		self->mInterface->AddRef(ref);
		*ppv = &self->mInterface;
		CFRelease(interfaceID);
		self->mVersion = 2;
#if MIDI_WEAK_LINK_TO_V2_CALLS
		InitMIDIWeakLinks();
#endif
		return S_OK;
	}
#endif

#if V1_MIDI_DRIVER_SUPPORT
	// Test the requested ID against the valid interfaces.
	if (CFEqual(interfaceID, kMIDIDriverInterfaceID)) {
		// If the MIDIDriverInterface was requested, bump the ref count,
		// set the ppv parameter equal to the instance, and
		// return good status.
		MIDIDriver *self = GetMIDIDriver(ref);
		self->mInterface->AddRef(ref);
		*ppv = &self->mInterface;
		CFRelease(interfaceID);
		self->mVersion = 1;
		return S_OK;
	}
#endif

	if (CFEqual(interfaceID, IUnknownUUID)) {
		MIDIDriver *self = GetMIDIDriver(ref);
		self->mInterface->AddRef(ref);
		*ppv = &self->mInterface;
		CFRelease(interfaceID);
		return S_OK;
	}
	
	// Requested interface unknown, bail with error.
	*ppv = NULL;
	CFRelease(interfaceID);
	return E_NOINTERFACE;
}
// return value ppv is a pointer to a pointer to the interface


// Implementation of reference counting for this type.
// Whenever an interface is requested, bump the refCount for
// the instance. NOTE: returning the refcount is a convention
// but is not required so don't rely on it.
static ULONG MIDIDriverAddRef(void *thisPointer) 
{
	MIDIDriver *self = GetMIDIDriver((MIDIDriverRef)thisPointer);

	return ++self->mRefCount;
}

// When an interface is released, decrement the refCount.
// If the refCount goes to zero, deallocate the instance.
static ULONG MIDIDriverRelease(void *thisPointer) 
{
	MIDIDriver *self = GetMIDIDriver((MIDIDriverRef)thisPointer);

	if (--self->mRefCount == 0) {
		delete self;
		return 0;
	} else
		return self->mRefCount;
}

OSStatus	MIDIDriverFindDevices(MIDIDriverRef self, MIDIDeviceListRef devList)
{
	return GetMIDIDriver(self)->FindDevices(devList);
}

OSStatus	MIDIDriverStart(MIDIDriverRef self, MIDIDeviceListRef devList)
{
	return GetMIDIDriver(self)->Start(devList);
}

OSStatus	MIDIDriverStop(MIDIDriverRef self)
{
	return GetMIDIDriver(self)->Stop();
}

OSStatus	MIDIDriverConfigure(MIDIDriverRef self, MIDIDeviceRef device)
{
	return GetMIDIDriver(self)->Configure(device);
}

OSStatus	MIDIDriverSend(MIDIDriverRef self, const MIDIPacketList *pktlist, 
				void *destRefCon1, void *destRefCon2)
{
	return GetMIDIDriver(self)->Send(pktlist, destRefCon1, destRefCon2);
}

OSStatus	MIDIDriverEnableSource(MIDIDriverRef self, MIDIEndpointRef src, Boolean enabled)
{
	return GetMIDIDriver(self)->EnableSource(src, enabled);
}

OSStatus	MIDIDriverFlush(MIDIDriverRef self, MIDIEndpointRef dest, void *destRefCon1, void *destRefCon2)
{
	return GetMIDIDriver(self)->Flush(dest, destRefCon1, destRefCon2);
}

OSStatus	MIDIDriverMonitor(MIDIDriverRef self, MIDIEndpointRef dest, const MIDIPacketList *pktlist)
{
	return GetMIDIDriver(self)->Monitor(dest, pktlist);
}

// The MIDIDriverInterface function table.
static MIDIDriverInterface MIDIDriverInterfaceFtbl = {
	NULL, // Required padding for COM
	//
	// These are the required COM functions
	MIDIDriverQueryInterface,
	MIDIDriverAddRef,
	MIDIDriverRelease,
	//
	// These are the MIDIDriver methods
	MIDIDriverFindDevices,
	MIDIDriverStart,
	MIDIDriverStop,
	MIDIDriverConfigure,
	MIDIDriverSend,
	MIDIDriverEnableSource,
	MIDIDriverFlush,
	MIDIDriverMonitor
};

MIDIDriver::MIDIDriver(CFUUIDRef factoryID)
{
	// Point to the function table
	mInterface = &MIDIDriverInterfaceFtbl;

	// Retain and keep an open instance refcount for each factory.
	mFactoryID = factoryID;
	CFPlugInAddInstanceForFactory(factoryID);

	mRefCount = 1;
	mVersion = 0;
}

MIDIDriver::~MIDIDriver()
{
	if (mFactoryID) {
		CFPlugInRemoveInstanceForFactory(mFactoryID);
		// CFRelease(mFactoryID); this came from CFUUIDGetConstantUUIDWithBytes which
		// says that it is immortal and should never be released
	}
}
