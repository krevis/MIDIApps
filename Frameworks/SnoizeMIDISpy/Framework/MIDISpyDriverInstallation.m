/*
 Copyright (c) 2001-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "MIDISpyDriverInstallation.h"

#import <Foundation/Foundation.h>

//
// Constant string declarations and definitions
//

static CFStringRef kSpyingMIDIDriverPlugInName = NULL;
static CFStringRef kSpyingMIDIDriverPlugInIdentifier = NULL;
static CFStringRef kSpyingMIDIDriverFrameworkIdentifier = NULL;

static void InitializeConstantStrings(void)  __attribute__ ((constructor));
void InitializeConstantStrings(void)
{
    kSpyingMIDIDriverPlugInName = CFSTR("MIDI Monitor.plugin");
    kSpyingMIDIDriverPlugInIdentifier = CFSTR("com.snoize.MIDIMonitorDriver");
    kSpyingMIDIDriverFrameworkIdentifier = CFSTR("com.snoize.MIDISpyFramework");
}

NSString * const MIDISpyDriverInstallationErrorDomain = @"com.snoize.MIDISpy";


//
// Private function declarations
//

static NSError * FindDriverInFramework(CFURLRef *urlPtr, UInt32 *versionPtr);
static NSURL *UserMIDIDriversURL(NSError **outErrorPtr);
static BOOL FindInstalledDriver(CFURLRef *urlPtr, UInt32 *versionPtr);
static void CreateBundlesForDriversInDomain(short findFolderDomain, CFMutableArrayRef createdBundles);
static NSError * RemoveInstalledDriver(CFURLRef driverURL);
static NSError * InstallDriver(CFURLRef ourDriverURL);


//
// Public functions
//

NSError * MIDISpyInstallDriverIfNecessary(void)
{
    NSError *error;

    // Look for the installed driver first, before we make a bundle for the driver in our framework.
    CFURLRef installedDriverURL = NULL;
    UInt32 installedDriverVersion;
    BOOL foundInstalledDriver = FindInstalledDriver(&installedDriverURL, &installedDriverVersion);

    // Then search for the copy of the driver in our framework.
    CFURLRef ourDriverURL = NULL;
    UInt32 ourDriverVersion;
    if ((error = FindDriverInFramework(&ourDriverURL, &ourDriverVersion))) {
        goto done;
    }

    // TODO There might be more than one "installed" driver. (What does CFPlugIn do in that case?)
    // TODO Or someone might have left a directory with our plugin name in the way, but w/o proper plugin files in it. Who knows.
    if (foundInstalledDriver) {
        if (installedDriverVersion == ourDriverVersion) {
            // Success: Already installed
            error = nil;
            goto done;
        } else {
            if ((error = RemoveInstalledDriver(installedDriverURL))) {
                goto done;
            }            
        }        
    }

    if ((error = InstallDriver(ourDriverURL))) {
        goto done;
    }
    else {
        // Success: Installed
        error = nil;
    }

done:
    if (ourDriverURL)
        CFRelease(ourDriverURL);
    if (installedDriverURL)
        CFRelease(installedDriverURL);

    return error;
}


//
// Private functions
//

// Driver installation

static NSError * FindDriverInFramework(CFURLRef *urlPtr, UInt32 *versionPtr)
{
    CFBundleRef frameworkBundle = NULL;
    CFURLRef driverURL = NULL;
    UInt32 driverVersion = 0;
    NSError *error;

    // Find this framework's bundle
    frameworkBundle = CFBundleGetBundleWithIdentifier(kSpyingMIDIDriverFrameworkIdentifier);
    if (!frameworkBundle) {
        __Debug_String("MIDISpyClient: Couldn't find our own framework's bundle!");
        NSString *reason = @"The driver's framework could not be found inside the app.";
        error = [NSError errorWithDomain:MIDISpyDriverInstallationErrorDomain code:MIDISpyDriverInstallationErrorCouldNotFindBundle userInfo:@{NSLocalizedFailureReasonErrorKey: reason}];
    } else {
        // Find the copy of the plugin in the framework's resources
        driverURL = CFBundleCopyResourceURL(frameworkBundle, kSpyingMIDIDriverPlugInName, NULL, NULL);
        if (!driverURL) {
            __Debug_String("MIDISpyClient: Couldn't find the copy of the plugin in our framework!");
            NSString *reason = @"The driver could not be found inside the app.";
            error = [NSError errorWithDomain:MIDISpyDriverInstallationErrorDomain code:MIDISpyDriverInstallationErrorCouldNotFindPlugIn userInfo:@{NSLocalizedFailureReasonErrorKey: reason}];
        } else {
            // Make a CFBundle with it.
            CFBundleRef driverBundle;

            driverBundle = CFBundleCreate(kCFAllocatorDefault, driverURL);
            if (!driverBundle) {
                __Debug_String("MIDISpyClient: Couldn't create a CFBundle for the copy of the plugin in our framework!");
                CFRelease(driverURL);
                driverURL = NULL;
                NSString *reason = @"Could not make a bundle for the driver.";
                error = [NSError errorWithDomain:MIDISpyDriverInstallationErrorDomain code:MIDISpyDriverInstallationErrorCouldNotMakeBundleForPlugIn userInfo:@{NSLocalizedFailureReasonErrorKey: reason}];
            } else {
                // Remember the version of the bundle.
                driverVersion = CFBundleGetVersionNumber(driverBundle);
                // Then get rid of the bundle--we no longer need it.
                CFRelease(driverBundle);
                error = nil;
            }
        }
    }

    *urlPtr = driverURL;
    *versionPtr = driverVersion;
    return error;
}


static BOOL FindInstalledDriver(CFURLRef *urlPtr, UInt32 *versionPtr)
{
    CFMutableArrayRef createdBundles = NULL;
    CFBundleRef driverBundle = NULL;
    CFURLRef driverURL = NULL;
    UInt32 driverVersion = 0;
    BOOL success = NO;

    createdBundles = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    CreateBundlesForDriversInDomain(kSystemDomain, createdBundles);
    CreateBundlesForDriversInDomain(kLocalDomain, createdBundles);
    CreateBundlesForDriversInDomain(kNetworkDomain, createdBundles);
    CreateBundlesForDriversInDomain(kUserDomain, createdBundles);

    // See if the driver is installed anywhere.
    driverBundle = CFBundleGetBundleWithIdentifier(kSpyingMIDIDriverPlugInIdentifier);
    if (!driverBundle) {
        __Debug_String("MIDISpyClient: Couldn't find an installed driver");
    } else if (!CFArrayContainsValue(createdBundles, CFRangeMake(0, CFArrayGetCount(createdBundles)), driverBundle)) {
        // The driver we found is not in one of the standard locations. Ignore it.
        __Debug_String("MIDISpyClient: Found driver bundle in a non-standard location, ignoring");
    } else {
        // Remember the URL and version of the bundle.
        driverURL = CFBundleCopyBundleURL(driverBundle);
        driverVersion = CFBundleGetVersionNumber(driverBundle);
        success = YES;
    }

    if (createdBundles)
        CFRelease(createdBundles);   
        
    *urlPtr = driverURL;
    *versionPtr = driverVersion;
    return success;
}


static NSURL *UserMIDIDriversURL(NSError **outErrorPtr) {
    NSError *error = nil;
    NSURL *libraryURL = [[NSFileManager defaultManager] URLForDirectory:NSLibraryDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    if (!libraryURL) {
        if (outErrorPtr) {
            *outErrorPtr = error;
        }
        return nil;
    }

    // concatenate Audio/MIDI Drivers
    NSURL *folderURL = [[libraryURL URLByAppendingPathComponent:@"Audio" isDirectory:YES] URLByAppendingPathComponent:@"MIDI Drivers" isDirectory:YES];
    if (!folderURL) {
        if (outErrorPtr) {
            NSString *reason = @"Could not make a URL for the user's Library/Audio/MIDI Drivers folder.";
            *outErrorPtr = [NSError errorWithDomain:MIDISpyDriverInstallationErrorDomain code:MIDISpyDriverInstallationErrorCannotMakeDriversURL userInfo:@{NSLocalizedFailureReasonErrorKey: reason}];
        }
        return nil;
    }

    if (outErrorPtr) {
        *outErrorPtr = nil;
    }
    return folderURL;
}


static void CreateBundlesForDriversInDomain(short findFolderDomain, CFMutableArrayRef createdBundles)
{
    NSURL *folderURL = UserMIDIDriversURL(NULL);
    if (!folderURL) {
        return;
    }

    CFArrayRef newBundles = CFBundleCreateBundlesFromDirectory(kCFAllocatorDefault, (__bridge CFURLRef)folderURL, NULL);
    if (newBundles) {
        CFIndex newBundlesCount = CFArrayGetCount(newBundles);
        if (newBundlesCount > 0) {
            CFArrayAppendArray(createdBundles, newBundles, CFRangeMake(0, newBundlesCount));
        }
        CFRelease(newBundles);
    }
}


static NSError * RemoveInstalledDriver(CFURLRef driverURL)
{
    NSError *error = nil;
    if ([[NSFileManager defaultManager] removeItemAtURL:(__bridge NSURL *)driverURL error:&error]) {
        return nil;
    }
    else {
        return error;
    }
}


static NSError * InstallDriver(CFURLRef ourDriverURL)
{
    NSString *driverName = [(__bridge NSURL *)ourDriverURL lastPathComponent];
    if (!driverName) {
        NSString *reason = @"Could not determine the driver's name.";
        return [NSError errorWithDomain:MIDISpyDriverInstallationErrorDomain code:MIDISpyDriverInstallationErrorDriverHasNoName userInfo:@{NSLocalizedFailureReasonErrorKey: reason}];
    }

    NSError *error = nil;
    NSURL *folderURL = UserMIDIDriversURL(&error);
    if (!folderURL) {
        __Debug_String("MIDISpy: Couldn't get URL to ~/Library/Audio/MIDI Drivers");
        return error;
    }

    BOOL directoryCreatedOrExists = [[NSFileManager defaultManager] createDirectoryAtURL:folderURL withIntermediateDirectories:YES attributes:nil error:&error];
    if (!directoryCreatedOrExists) {
        __Debug_String("MIDISpy: ~/Library/Audio/MIDI Drivers did not exist and couldn't be created");
        return error;
    }

    NSURL *copiedDriverURL = [folderURL URLByAppendingPathComponent:driverName];
    if (!copiedDriverURL) {
        NSString *reason = @"Could not make a URL to copy the driver to, inside the user's Library/Audio/MIDI Drivers folder.";
        return [NSError errorWithDomain:MIDISpyDriverInstallationErrorDomain code:MIDISpyDriverInstallationErrorCannotMakeDriverDestinationURL userInfo:@{NSLocalizedFailureReasonErrorKey: reason}];
    }

    BOOL copied = [[NSFileManager defaultManager] copyItemAtURL:(__bridge NSURL *)ourDriverURL toURL:copiedDriverURL error:&error];
    if (!copied) {
        return error;
    }

    return nil;
}
