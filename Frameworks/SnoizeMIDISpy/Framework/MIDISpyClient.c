#include "MIDISpyClient.h"

#include <Carbon/Carbon.h>


typedef struct __MIDISpyClient
{
    MIDISpyClientCallBack clientCallBack;
    void *clientRefCon;
    CFMessagePortRef localPort;
    CFRunLoopSourceRef runLoopSource;
} MIDISpyClient;


static CFStringRef kSpyingMIDIDriverPlugInName = NULL;
static CFStringRef kSpyingMIDIDriverPlugInIdentifier = NULL;
static CFStringRef kSpyingMIDIDriverPortName = NULL;
static const SInt32 kSpyingMIDIDriverNextSequenceNumberMessageID = 0; 
static const SInt32 kSpyingMIDIDriverAddListenerMessageID = 1; 

static Boolean FindDriverInFramework(CFURLRef *urlPtr, UInt32 *versionPtr);
static Boolean FindInstalledDriver(CFURLRef *urlPtr, UInt32 *versionPtr);
static void CreateBundlesForDriversInDomain(short findFolderDomain, CFMutableArrayRef createdBundles);
static Boolean InstallDriver(CFURLRef ourDriverURL);

static CFDataRef LocalMessagePortCallback(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info);


SInt32 MIDISpyInstallDriverIfNecessary()
{
    SInt32 returnStatus;
    CFURLRef ourDriverURL = NULL;
    UInt32 ourDriverVersion;
    CFURLRef installedDriverURL = NULL;
    UInt32 installedDriverVersion;

    if (!kSpyingMIDIDriverPlugInName)
        kSpyingMIDIDriverPlugInName = CFSTR("SpyingMIDIDriver.plugin");
    if (!kSpyingMIDIDriverPlugInIdentifier)
        kSpyingMIDIDriverPlugInIdentifier = CFSTR("com.snoize.SpyingMIDIDriver");

    if (!FindDriverInFramework(&ourDriverURL, &ourDriverVersion)) {
        returnStatus =  kMIDISpyDriverInstallationFailed;
        goto done;
    }
    
    if (FindInstalledDriver(&installedDriverURL, &installedDriverVersion)) {
        if (installedDriverVersion == ourDriverVersion) {
            returnStatus = kMIDISpyDriverAlreadyInstalled;
            goto done;
        } else {
            // TODO Try to remove the installed driver; if we fail, do stuff below.
            fprintf(stderr, "MIDISpy: We are not even trying to delete an old copy of the driver\n");
            returnStatus = kMIDISpyDriverInstallationFailed;
            goto done;
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


MIDISpyClientRef MIDISpyClientCreate(MIDISpyClientCallBack callBack, void *refCon)
{
    MIDISpyClientRef clientRef = NULL;
    CFMessagePortRef driverPort;
    SInt32 sendStatus;
    CFDataRef sequenceNumberData = NULL;
    int success = 0;

    // TODO There must be a better way to do this.
    if (!kSpyingMIDIDriverPortName)
        kSpyingMIDIDriverPortName = CFSTR("Spying MIDI Driver");
    
    // Look for the message port which our MIDI driver provides
    driverPort = CFMessagePortCreateRemote(kCFAllocatorDefault, kSpyingMIDIDriverPortName);
    if (!driverPort) {
#if DEBUG
        fprintf(stderr, "MIDISpyClientCreate: Couldn't find message port for Spying MIDI Driver\n");
#endif
        return NULL;
    }

    clientRef = (MIDISpyClientRef)malloc(sizeof(MIDISpyClient));
    
    // Ask for the next sequence number
    sendStatus = CFMessagePortSendRequest(driverPort, kSpyingMIDIDriverNextSequenceNumberMessageID, NULL, 300, 300, kCFRunLoopDefaultMode, &sequenceNumberData);
    if (sendStatus != kCFMessagePortSuccess) {
#if DEBUG
        fprintf(stderr, "MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverNextSequenceNumberMessageID) returned error: %ld\n", sendStatus);
#endif
    } else if (!sequenceNumberData) {
#if DEBUG
        fprintf(stderr, "MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverNextSequenceNumberMessageID) returned no data!\n");
#endif
    } else if (CFDataGetLength(sequenceNumberData) != sizeof(UInt32)) {
#if DEBUG
        fprintf(stderr, "MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverNextSequenceNumberMessageID) returned %lu bytes, not %lu!\n", CFDataGetLength(sequenceNumberData), sizeof(UInt32));
#endif
    } else {
        UInt32 sequenceNumber;
        CFStringRef localPortName;
        CFMessagePortContext context = { 0, clientRef, NULL, NULL, NULL };
        CFMessagePortRef localPort;
        CFRunLoopSourceRef runLoopSource;

        // Now get the sequence number and use it to name a newly created local port
        sequenceNumber = *(UInt32 *)CFDataGetBytePtr(sequenceNumberData);
        localPortName = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@-%lu"), kSpyingMIDIDriverPortName, sequenceNumber);

        localPort = CFMessagePortCreateLocal(kCFAllocatorDefault, localPortName, LocalMessagePortCallback, &context, FALSE);
        CFRelease(localPortName);
        if (!localPort) {
#if DEBUG
            fprintf(stderr, "MIDISpyClientCreate: CFMessagePortCreateLocal failed!\n");
#endif
        } else {
            // Add the local port to the current run loop, in common modes
            runLoopSource = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, localPort, 0);
            if (!runLoopSource) {
#if DEBUG
                fprintf(stderr, "MIDISpyClientCreate: CFMessagePortCreateRunLoopSource failed!\n");
#endif
            } else {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    
                // And now tell the spying driver to add us as a listener. Don't wait for a response.
                sendStatus = CFMessagePortSendRequest(driverPort, kSpyingMIDIDriverAddListenerMessageID, sequenceNumberData, 300, 0, NULL, NULL);
                if (sendStatus != kCFMessagePortSuccess) {
#if DEBUG
                    fprintf(stderr, "MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverAddListenerMessageID) returned error: %ld\n", sendStatus);
#endif
                } else {
                    // Success!
                    success = 1;
                    clientRef->clientCallBack = callBack;
                    clientRef->clientRefCon = refCon;
                    CFRetain(localPort);
                    clientRef->localPort = localPort;
                    CFRetain(runLoopSource);
                    clientRef->runLoopSource = runLoopSource;
                }

                CFRelease(runLoopSource);
            }

            CFRelease(localPort);
        }
    }

    if (sequenceNumberData)
        CFRelease(sequenceNumberData);

    CFRelease(driverPort);

    if (!success) {
        free(clientRef);
        clientRef = NULL;
    }
    
    return clientRef;
}


void MIDISpyClientDispose(MIDISpyClientRef clientRef)
{
    if (clientRef->runLoopSource) {
        CFRunLoopSourceInvalidate(clientRef->runLoopSource);
        CFRelease(clientRef->runLoopSource);
    }

    if (clientRef->localPort) {
        CFMessagePortInvalidate(clientRef->localPort);
        CFRelease(clientRef->localPort);        
    }
    
    free(clientRef);
}


//
// Private functions
//

static Boolean FindDriverInFramework(CFURLRef *urlPtr, UInt32 *versionPtr)
{
    CFBundleRef frameworkBundle = NULL;
    CFURLRef driverURL = NULL;
    UInt32 driverVersion = 0;
    Boolean success = FALSE;

    // Find this framework's bundle
    frameworkBundle = CFBundleGetBundleWithIdentifier(CFSTR("com.snoize.MIDISpyFramework"));
    if (!frameworkBundle) {
#if DEBUG
        fprintf(stderr, "MIDISpyClient: Couldn't find our own framework's bundle!\n");
#endif
    } else {
        // Find the copy of the plugin in the framework's resources
        driverURL = CFBundleCopyResourceURL(frameworkBundle, kSpyingMIDIDriverPlugInName, NULL, NULL);
        if (!driverURL) {
#if DEBUG
            fprintf(stderr, "MIDISpyClient: Couldn't find the copy of the plugin in our framework!\n");
#endif
        } else {
            // Make a CFBundle with it.
            CFBundleRef driverBundle;

            driverBundle = CFBundleCreate(kCFAllocatorDefault, driverURL);
            if (!driverBundle) {
#if DEBUG
                fprintf(stderr, "MIDISpyClient: Couldn't create a CFBundle for the copy of the plugin in our framework!\n");
#endif
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
#if DEBUG
        fprintf(stderr, "MIDISpyClient: Couldn't find an installed driver\n");
#endif
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


static Boolean InstallDriver(CFURLRef ourDriverURL)
{
    OSErr error;
    FSRef folderFSRef;
    Boolean success = FALSE;

    // Find the directory "~/Library/Audio/MIDI Drivers". If it doesn't exist, create it.
    error = FSFindFolder(kUserDomain, kMIDIDriversFolderType, kCreateFolder, &folderFSRef);
    if (error != noErr) {
#if DEBUG
        fprintf(stderr, "MIDISpy: FSFindFolder(kUserDomain, kMIDIDriversFolderType, kCreateFolder) returned error: %hd\n", error);
#endif
    } else {
        CFURLRef folderURL;
        char folderPath[PATH_MAX];

        folderURL = CFURLCreateFromFSRef(kCFAllocatorDefault, &folderFSRef);

        if (!CFURLGetFileSystemRepresentation(folderURL, FALSE, (UInt8 *)folderPath, PATH_MAX)) {
#if DEBUG
            fprintf(stderr, "MIDISpy: CFURLGetFileSystemRepresentation(folderURL) failed\n");
#endif
        } else {
            char driverPath[PATH_MAX];

            if (!CFURLGetFileSystemRepresentation(ourDriverURL, FALSE, (UInt8 *)driverPath, PATH_MAX)) {
#if DEBUG
                fprintf(stderr, "MIDISpy: CFURLGetFileSystemRepresentation(ourDriverURL) failed\n");
#endif
            } else {
                // Copy (recursively) from the directory of the driver in our resources directory.
                // I know the driver doesn't contain any files with resource forks, so we are safe using the UNIX API for this.
                // TODO what a pain, it's not as though there is good UNIX API for this either.
                char command[2 * PATH_MAX + 10];

                snprintf(command, sizeof(command), "cp -Rf \"%s\" \"%s\"", driverPath, folderPath);

                success = (system(command) == 0);
#if DEBUG
                if (!success)
                    fprintf(stderr, "MIDISpy: cp failed\n");
#endif
            }
        }

        CFRelease(folderURL);
    }
 
    return success;
}


static CFDataRef LocalMessagePortCallback(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info)
{
    const UInt8 *bytes;
    SInt32 endpointUniqueID;
    const char *endpointNameCString;
    const MIDIPacketList *packetList;
    CFStringRef endpointName;
    MIDISpyClientRef clientRef = (MIDISpyClientRef)info;

    if (!data) {
#if DEBUG
        fprintf(stderr, "MIDISpyClient: Got empty data from driver!\n");
#endif
        return NULL;
    } else if (CFDataGetLength(data) < (sizeof(SInt32) + 1 + sizeof(UInt32))) {
#if DEBUG
        fprintf(stderr, "MIDISpyClient: Got too-small data from driver! (%ld bytes)\n", CFDataGetLength(data));
#endif
        return NULL;
    }

    bytes = CFDataGetBytePtr(data);
    
    endpointUniqueID = *(SInt32 *)bytes;
    endpointNameCString = (const char *)(bytes + sizeof(SInt32));
    packetList = (const MIDIPacketList *)(bytes + sizeof(SInt32) + strlen(endpointNameCString) + 1);

    endpointName = CFStringCreateWithCString(kCFAllocatorDefault, endpointNameCString, kCFStringEncodingUTF8);

    clientRef->clientCallBack(endpointUniqueID, endpointName, packetList, clientRef->clientRefCon);

    CFRelease(endpointName);
    
    return NULL;
}
