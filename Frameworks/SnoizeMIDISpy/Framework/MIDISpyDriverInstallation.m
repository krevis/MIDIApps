/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
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

static NSError * FindDriverInFramework(CFURLRef *urlPtr, CFStringRef *versionPtr);
static NSURL *MIDIDriversURL(NSSearchPathDomainMask domain, NSError **outErrorPtr);
static BOOL FindInstalledDriver(CFURLRef *urlPtr, CFStringRef *versionPtr);
static void CreateBundlesForDriversInDomain(NSSearchPathDomainMask domain, CFMutableArrayRef createdBundles);
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
    CFStringRef installedDriverVersion = NULL;
    BOOL foundInstalledDriver = FindInstalledDriver(&installedDriverURL, &installedDriverVersion);

    // Then search for the copy of the driver in our framework.
    CFURLRef ourDriverURL = NULL;
    CFStringRef ourDriverVersion = NULL;
    if ((error = FindDriverInFramework(&ourDriverURL, &ourDriverVersion))) {
        goto done;
    }

    // TODO There might be more than one "installed" driver. (What does CFPlugIn do in that case?)
    // TODO Or someone might have left a directory with our plugin name in the way, but w/o proper plugin files in it. Who knows.
    if (foundInstalledDriver) {
        if (installedDriverVersion && ourDriverVersion && CFEqual(installedDriverVersion, ourDriverVersion)) {
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
    if (ourDriverVersion)
        CFRelease(ourDriverVersion);
    if (installedDriverVersion)
        CFRelease(installedDriverVersion);

    return error;
}


//
// Private functions
//

// Driver installation

static NSError * FindDriverInFramework(CFURLRef *urlPtr, CFStringRef *versionPtr)
{
    CFBundleRef frameworkBundle = NULL;
    CFURLRef driverURL = NULL;
    CFStringRef driverVersion = NULL;
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
            // Get the version number without actually creating the bundle.
            // As of Mac OS X Big Sur (11.0.1 Beta, 20B5012d), creating a bundle with the driverURL fails,
            // because "More than one bundle with the same factory UUID detected", because it's seeing
            // the installed bundle in ~/Library/Audio/MIDI Drivers which we created earlier.

            CFDictionaryRef infoDict = CFBundleCopyInfoDictionaryInDirectory(driverURL);
            if (!infoDict) {
                __Debug_String("MIDISpyClient: Couldn't get the InfoDictionary for the copy of the plugin in our framework!");
                CFRelease(driverURL);
                driverURL = NULL;
                NSString *reason = @"Could not get information about the driver.";
                error = [NSError errorWithDomain:MIDISpyDriverInstallationErrorDomain code:MIDISpyDriverInstallationErrorCouldNotGetPlugInInfo userInfo:@{NSLocalizedFailureReasonErrorKey: reason}];
            } else {
                // Return the version of the bundle.
                CFTypeRef possibleVersion = CFDictionaryGetValue(infoDict, kCFBundleVersionKey);
                if (possibleVersion && CFGetTypeID(possibleVersion) == CFStringGetTypeID()) {
                    driverVersion = (CFStringRef)CFRetain(possibleVersion);
                    error = nil;
                }
                else {
                    __Debug_String("MIDISpyClient: Couldn't get the version of the copy of the plugin in our framework!");
                    CFRelease(driverURL);
                    driverURL = NULL;
                    NSString *reason = @"Could not get the version of the driver.";
                    error = [NSError errorWithDomain:MIDISpyDriverInstallationErrorDomain code:MIDISpyDriverInstallationErrorCouldNotGetPlugInVersion userInfo:@{NSLocalizedFailureReasonErrorKey: reason}];
                }

                CFRelease(infoDict);
            }
        }
    }

    *urlPtr = driverURL;
    *versionPtr = driverVersion;
    return error;
}


static BOOL FindInstalledDriver(CFURLRef *urlPtr, CFStringRef *versionPtr)
{
    CFMutableArrayRef createdBundles = NULL;
    CFBundleRef driverBundle = NULL;
    CFURLRef driverURL = NULL;
    CFStringRef driverVersion = NULL;
    BOOL success = NO;

    createdBundles = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    CreateBundlesForDriversInDomain(NSSystemDomainMask, createdBundles);
    CreateBundlesForDriversInDomain(NSLocalDomainMask, createdBundles);
    CreateBundlesForDriversInDomain(NSNetworkDomainMask, createdBundles);
    CreateBundlesForDriversInDomain(NSUserDomainMask, createdBundles);

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
        CFTypeRef possibleVersion = CFBundleGetValueForInfoDictionaryKey(driverBundle, kCFBundleVersionKey);
        if (possibleVersion && CFGetTypeID(possibleVersion) == CFStringGetTypeID()) {
            driverVersion = (CFStringRef)CFRetain(possibleVersion);
        }
        success = YES;
    }

    if (createdBundles)
        CFRelease(createdBundles);   
        
    *urlPtr = driverURL;
    *versionPtr = driverVersion;
    return success;
}


static NSURL *MIDIDriversURL(NSSearchPathDomainMask domain, NSError **outErrorPtr) {
    NSError *error = nil;
    NSURL *libraryURL = [[NSFileManager defaultManager] URLForDirectory:NSLibraryDirectory inDomain:domain appropriateForURL:nil create:NO error:&error];
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
            NSString *reason = @"Could not make a URL for the domain's Library/Audio/MIDI Drivers folder.";
            *outErrorPtr = [NSError errorWithDomain:MIDISpyDriverInstallationErrorDomain code:MIDISpyDriverInstallationErrorCannotMakeDriversURL userInfo:@{NSLocalizedFailureReasonErrorKey: reason}];
        }
        return nil;
    }

    if (outErrorPtr) {
        *outErrorPtr = nil;
    }
    return folderURL;
}


static void CreateBundlesForDriversInDomain(NSSearchPathDomainMask domain, CFMutableArrayRef createdBundles)
{
    NSURL *folderURL = MIDIDriversURL(domain, NULL);
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
    NSURL *folderURL = MIDIDriversURL(NSUserDomainMask, &error);
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
