#include "MIDISpyDriverInstallation.h"

#include "FSCopyObject.h"

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


//
// Private function declarations
//

static Boolean FindDriverInFramework(CFURLRef *urlPtr, UInt32 *versionPtr);
static Boolean FindInstalledDriver(CFURLRef *urlPtr, UInt32 *versionPtr);
static void CreateBundlesForDriversInDomain(short findFolderDomain, CFMutableArrayRef createdBundles);
static Boolean RemoveInstalledDriver(CFURLRef driverURL);
static Boolean InstallDriver(CFURLRef ourDriverURL);


//
// Public functions
//

SInt32 MIDISpyInstallDriverIfNecessary()
{
    SInt32 returnStatus;
    CFURLRef ourDriverURL = NULL;
    UInt32 ourDriverVersion;
    CFURLRef installedDriverURL = NULL;
    UInt32 installedDriverVersion;

    if (!FindDriverInFramework(&ourDriverURL, &ourDriverVersion)) {
        returnStatus =  kMIDISpyDriverInstallationFailed;
        goto done;
    }

    // TODO There might be more than one "installed" driver. (What does CFPlugIn do in that case?)
    // TODO Or someone might have left a directory with our plugin name in the way, but w/o proper plugin files in it. Who knows.
    if (FindInstalledDriver(&installedDriverURL, &installedDriverVersion)) {
        if (installedDriverVersion == ourDriverVersion) {
            returnStatus = kMIDISpyDriverAlreadyInstalled;
            goto done;
        } else {
            if (!RemoveInstalledDriver(installedDriverURL)) {
                returnStatus = kMIDISpyDriverCouldNotRemoveOldDriver;
                goto done;                
            }            
        }        
    }

    if (InstallDriver(ourDriverURL))
        returnStatus = kMIDISpyDriverInstalledSuccessfully;
    else
        returnStatus = kMIDISpyDriverInstallationFailed;
        
done:
    if (ourDriverURL)
        CFRelease(ourDriverURL);
    if (installedDriverURL)
        CFRelease(installedDriverURL);
        
    return returnStatus;
}


//
// Private functions
//

// Driver installation

static Boolean FindDriverInFramework(CFURLRef *urlPtr, UInt32 *versionPtr)
{
    CFBundleRef frameworkBundle = NULL;
    CFURLRef driverURL = NULL;
    UInt32 driverVersion = 0;
    Boolean success = FALSE;

    // Find this framework's bundle
    frameworkBundle = CFBundleGetBundleWithIdentifier(kSpyingMIDIDriverFrameworkIdentifier);
    if (!frameworkBundle) {
        debug_string("MIDISpyClient: Couldn't find our own framework's bundle!");
    } else {
        // Find the copy of the plugin in the framework's resources
        driverURL = CFBundleCopyResourceURL(frameworkBundle, kSpyingMIDIDriverPlugInName, NULL, NULL);
        if (!driverURL) {
            debug_string("MIDISpyClient: Couldn't find the copy of the plugin in our framework!");
        } else {
            // Make a CFBundle with it.
            CFBundleRef driverBundle;

            driverBundle = CFBundleCreate(kCFAllocatorDefault, driverURL);
            if (!driverBundle) {
                debug_string("MIDISpyClient: Couldn't create a CFBundle for the copy of the plugin in our framework!");
                CFRelease(driverURL);
                driverURL = NULL;
            } else {
                // Remember the version of the bundle.
                driverVersion = CFBundleGetVersionNumber(driverBundle);
                // Then get rid of the bundle--we no longer need it.
                CFRelease(driverBundle);
                success = TRUE;
            }
        }
    }

    *urlPtr = driverURL;
    *versionPtr = driverVersion;
    return success;
}


static Boolean FindInstalledDriver(CFURLRef *urlPtr, UInt32 *versionPtr)
{
    CFMutableArrayRef createdBundles = NULL;
    CFBundleRef driverBundle = NULL;
    CFURLRef driverURL = NULL;
    UInt32 driverVersion = 0;
    Boolean success = FALSE;

    createdBundles = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    CreateBundlesForDriversInDomain(kSystemDomain, createdBundles);
    CreateBundlesForDriversInDomain(kLocalDomain, createdBundles);
    CreateBundlesForDriversInDomain(kNetworkDomain, createdBundles);
    CreateBundlesForDriversInDomain(kUserDomain, createdBundles);

    // See if the driver is installed anywhere.
    driverBundle = CFBundleGetBundleWithIdentifier(kSpyingMIDIDriverPlugInIdentifier);
    if (!driverBundle) {
        debug_string("MIDISpyClient: Couldn't find an installed driver");
    } else {
        // Remember the URL and version of the bundle.
        driverURL = CFBundleCopyBundleURL(driverBundle);
        driverVersion = CFBundleGetVersionNumber(driverBundle);
        success = TRUE;
    }

    if (createdBundles)
        CFRelease(createdBundles);   
        
    *urlPtr = driverURL;
    *versionPtr = driverVersion;
    return success;
}


static void CreateBundlesForDriversInDomain(short findFolderDomain, CFMutableArrayRef createdBundles)
{
    FSRef folderFSRef;
    CFURLRef folderURL;
    CFArrayRef newBundles;
    CFIndex newBundlesCount;

    if (FSFindFolder(findFolderDomain, kMIDIDriversFolderType, kDontCreateFolder, &folderFSRef) != noErr)
        return;

    folderURL = CFURLCreateFromFSRef(kCFAllocatorDefault, &folderFSRef);

    newBundles = CFBundleCreateBundlesFromDirectory(kCFAllocatorDefault, folderURL, NULL);
    if (newBundles) {
        if ((newBundlesCount = CFArrayGetCount(newBundles))) {
            CFArrayAppendArray(createdBundles, newBundles, CFRangeMake(0, newBundlesCount));
        }
        CFRelease(newBundles);
    }

    CFRelease(folderURL);
}


static Boolean RemoveInstalledDriver(CFURLRef driverURL)
{
    FSRef driverFSRef;

    if (!CFURLGetFSRef(driverURL, &driverFSRef))
        return FALSE;
    else
        return (noErr == FSDeleteObjects(&driverFSRef));
}


static Boolean InstallDriver(CFURLRef ourDriverURL)
{
    OSErr error;
    FSRef folderFSRef;
    Boolean success = FALSE;

    // Find the MIDI Drivers directory for the current user. If it doesn't exist, create it.
    error = FSFindFolder(kUserDomain, kMIDIDriversFolderType, kCreateFolder, &folderFSRef);
    if (error != noErr) {
        debug_string("MIDISpy: FSFindFolder(kUserDomain, kMIDIDriversFolderType, kCreateFolder) returned error");
    } else {
        FSRef driverFSRef;

        if (CFURLGetFSRef(ourDriverURL, &driverFSRef)) {
            error = FSCopyObject(&driverFSRef, &folderFSRef, 0, kFSCatInfoNone, false, false, NULL, NULL, NULL);
            success = (error == noErr);
        }
    }
 
    return success;
}
