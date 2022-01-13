/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */


#if !defined(__SNOIZE_MIDISPYDRIVERINSTALLATION__)
#define __SNOIZE_MIDISPYDRIVERINSTALLATION__ 1

#include <AssertMacros.h>
#include <Foundation/Foundation.h>

#if defined(__cplusplus)
extern "C" {
#endif


extern NSError * MIDISpyInstallDriverIfNecessary(void);

extern NSString * const MIDISpyDriverInstallationErrorDomain;

typedef NS_ENUM(NSInteger, MIDISpyDriverInstallationErrorCode) {
    MIDISpyDriverInstallationErrorCouldNotFindBundle,
    MIDISpyDriverInstallationErrorCouldNotFindPlugIn,
    MIDISpyDriverInstallationErrorCouldNotGetPlugInInfo,
    MIDISpyDriverInstallationErrorCouldNotGetPlugInVersion,
    MIDISpyDriverInstallationErrorDriverHasNoName,
    MIDISpyDriverInstallationErrorCannotMakeDriversURL,
    MIDISpyDriverInstallationErrorCannotMakeDriverDestinationURL,
};


#if defined(__cplusplus)
}
#endif

#endif /* ! __SNOIZE_MIDISPYDRIVERINSTALLATION__ */
