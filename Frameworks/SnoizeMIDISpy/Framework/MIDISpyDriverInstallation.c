#include "MIDISpyDriverInstallation.h"

#include <Carbon/Carbon.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include "MoreFilesX.h"


//
// Constant string declarations and definitions
//

static CFStringRef kSpyingMIDIDriverPlugInName = NULL;
static CFStringRef kSpyingMIDIDriverPlugInIdentifier = NULL;

static void InitializeConstantStrings(void)  __attribute__ ((constructor));
void InitializeConstantStrings(void)
{
    kSpyingMIDIDriverPlugInName = CFSTR("SpyingMIDIDriver.plugin");
    kSpyingMIDIDriverPlugInIdentifier = CFSTR("com.snoize.SpyingMIDIDriver");
}


//
// Private function declarations
//

static Boolean FindDriverInFramework(CFURLRef *urlPtr, UInt32 *versionPtr);
static Boolean FindInstalledDriver(CFURLRef *urlPtr, UInt32 *versionPtr);
static void CreateBundlesForDriversInDomain(short findFolderDomain, CFMutableArrayRef createdBundles);
static Boolean RemoveInstalledDriver(CFURLRef driverURL);
static Boolean InstallDriver(CFURLRef ourDriverURL);
static Boolean CopyDirectory(CFURLRef sourceDirectoryURL, CFURLRef targetDirectoryURL);

static Boolean ForkAndExec(char * const argv[]);



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
    frameworkBundle = CFBundleGetBundleWithIdentifier(CFSTR("com.snoize.MIDISpyFramework"));
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
    OSErr result;
    FSCatalogInfo catalogInfo;

    if (!CFURLGetFSRef(driverURL, &driverFSRef))
        return FALSE;

    // If this is a directory, delete the contents first
    result = FSGetCatalogInfo(&driverFSRef, kFSCatInfoNodeFlags, &catalogInfo, NULL, NULL, NULL);
    require_noerr(result, FSGetCatalogInfo);
    if (catalogInfo.nodeFlags & kFSNodeIsDirectoryMask) {
        result = FSDeleteContainerContents(&driverFSRef);
        require_noerr(result, FSDeleteContainerContents);
    }

    // Is the top object (directory or file) locked?
    if (catalogInfo.nodeFlags & kFSNodeLockedMask) {
        // Then attempt to unlock it (ignore the result since FSDeleteObject will set it correctly)
        catalogInfo.nodeFlags &= ~kFSNodeLockedMask;
        FSSetCatalogInfo(&driverFSRef, kFSCatInfoNodeFlags, &catalogInfo);
    }

    // Delete the directory or file
    result = FSDeleteObject(&driverFSRef);

FSGetCatalogInfo:
FSDeleteContainerContents:
    return (result == noErr);
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
        CFURLRef folderURL;

        // And copy the driver there.
        folderURL = CFURLCreateFromFSRef(kCFAllocatorDefault, &folderFSRef);
        success = CopyDirectory(ourDriverURL, folderURL);

        CFRelease(folderURL);
    }
 
    return success;
}


static Boolean CopyDirectory(CFURLRef sourceDirectoryURL, CFURLRef targetDirectoryURL)
{
    // Copy (recursively) from the source into the target.
    // I know the driver doesn't contain any files with resource forks or interesting finder info, so we are safe using UNIX commands for this.
    // TODO This is sort of lame, though... but less error-prone than writing it myself, I bet.
    
    char sourcePath[PATH_MAX];
    char targetPath[PATH_MAX];
    char *argv[] = { "/bin/cp", "-Rf", sourcePath, targetPath, NULL };

    if (!CFURLGetFileSystemRepresentation(sourceDirectoryURL, FALSE, (UInt8 *)sourcePath, PATH_MAX)) {
        debug_string("MIDISpy: CFURLGetFileSystemRepresentation(sourceDirectoryURL) failed");
        return FALSE;
    }

    if (!CFURLGetFileSystemRepresentation(targetDirectoryURL, FALSE, (UInt8 *)targetPath, PATH_MAX)) {
        debug_string("MIDISpy: CFURLGetFileSystemRepresentation(targetDirectoryURL) failed");
        return FALSE;
    }

    return ForkAndExec(argv);
}


static Boolean ForkAndExec(char * const argv[])
{
    const char *path;
    pid_t pid;
    int status;

    path = argv[0];
    if (path == NULL)
        return FALSE;

    if ((pid = fork()) < 0) {
        status = -1;
    } else if (pid == 0) {
        // child
        execv(path, argv);
        _exit(127);
    } else {
        // parent
        while (waitpid(pid, &status, 0) < 0) {
            if (errno != EINTR) {
                status = -1;
                break;
            }
        }
    }

    return (status == 0);
}
