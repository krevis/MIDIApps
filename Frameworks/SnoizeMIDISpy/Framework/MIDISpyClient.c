#include "MIDISpyClient.h"
#include "MIDISpyShared.h"

#include <Carbon/Carbon.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>


//
// Definitions of publicly accessible structures
//

typedef struct __MIDISpyClient
{
    CFMessagePortRef driverPort;
    CFMessagePortRef localPort;
    CFRunLoopSourceRef runLoopSource;
    UInt32 clientIdentifier;
    CFMutableArrayRef ports;
    CFMutableDictionaryRef endpointConnections;
} MIDISpyClient;

typedef struct __MIDISpyPort
{
    MIDISpyClientRef client;
    MIDIReadProc readProc;
    void *refCon;
    CFMutableArrayRef connections;
} MIDISpyPort;


//
// Definitions of private structures
//

typedef struct __MIDISpyPortConnection
{
    MIDISpyPortRef port;
    MIDIEndpointRef endpoint;
    void *refCon;
} MIDISpyPortConnection;


//
// Constant string declarations
//

extern void InitializeConstantStrings(void);
#pragma CALL_ON_MODULE_BIND InitializeConstantStrings

static CFStringRef kSpyingMIDIDriverPlugInName = NULL;
static CFStringRef kSpyingMIDIDriverPlugInIdentifier = NULL;
static CFStringRef kSpyingMIDIDriverPortName = NULL;


//
// Private method declarations
//

static Boolean FindDriverInFramework(CFURLRef *urlPtr, UInt32 *versionPtr);
static Boolean FindInstalledDriver(CFURLRef *urlPtr, UInt32 *versionPtr);
static void CreateBundlesForDriversInDomain(short findFolderDomain, CFMutableArrayRef createdBundles);
static Boolean RemoveInstalledDriver(CFURLRef driverURL);
static Boolean InstallDriver(CFURLRef ourDriverURL);
static Boolean CopyDirectory(CFURLRef sourceDirectoryURL, CFURLRef targetDirectoryURL);

static Boolean ForkAndExec(char * const argv[]);

static void ReceiveMIDINotification(const MIDINotification *message, void *refCon);
static void RebuildEndpointUniqueIDDictionary();
static MIDIEndpointRef EndpointWithUniqueID(SInt32 uniqueID);

static MIDISpyPortConnection *GetPortConnection(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint);
static void DisconnectConnection(MIDISpyPortRef spyPortRef, MIDISpyPortConnection *connection);

static void ClientAddConnection(MIDISpyClientRef clientRef, MIDISpyPortConnection *connection);
static void ClientRemoveConnection(MIDISpyClientRef clientRef, MIDISpyPortConnection *connection);
static CFMutableArrayRef GetConnectionsToEndpoint(MIDISpyClientRef clientRef, MIDIEndpointRef endpoint);

static void SetClientSubscribesToDataFromEndpoint(MIDISpyClientRef clientRef, MIDIEndpointRef endpoint, Boolean subscribes);
static CFDataRef LocalMessagePortCallback(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info);


//
// Static variables
//

static MIDIClientRef sMIDIClientRef = NULL;
static CFMutableDictionaryRef sUniqueIDToEndpointDictionary = NULL;


//
// Public methods
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

    // TODO There might be more than one "installed" driver.
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


OSStatus MIDISpyClientCreate(MIDISpyClientRef *outClientRefPtr)
{
    MIDISpyClientRef clientRef = NULL;
    CFMessagePortRef driverPort;
    SInt32 sendStatus;
    CFDataRef identifierData = NULL;
    int success = 0;
    
    if (!outClientRefPtr)
        return paramErr;
    *outClientRefPtr = NULL;

    // Create a CoreMIDI client (if we haven't already), so we can receive a notification when the setup changes.
    if (!sMIDIClientRef) {
        OSStatus status;

        status = MIDIClientCreate(CFSTR("MIDISpyClient"), ReceiveMIDINotification, NULL, &sMIDIClientRef);
        if (status != noErr)
            return status;

        RebuildEndpointUniqueIDDictionary();
    }
    
    // Look for the message port which our MIDI driver provides
    driverPort = CFMessagePortCreateRemote(kCFAllocatorDefault, kSpyingMIDIDriverPortName);
    if (!driverPort) {
        debug_string("MIDISpyClientCreate: Couldn't find message port for Spying MIDI Driver");
        return kMIDISpyDriverMissing;
    }

    clientRef = (MIDISpyClientRef)calloc(1, sizeof(MIDISpyClient));
    if (!clientRef)
        return memFullErr;
    clientRef->driverPort = driverPort;
    
    // Ask for an identifier number from the driver
    sendStatus = CFMessagePortSendRequest(driverPort, kSpyingMIDIDriverGetNextListenerIdentifierMessageID, NULL, 300, 300, kCFRunLoopDefaultMode, &identifierData);

    if (sendStatus != kCFMessagePortSuccess) {
        debug_string("MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverGetNextListenerIdentifierMessageID) returned error");
    } else if (!identifierData) {
        debug_string("MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverGetNextListenerIdentifierMessageID) returned no data!");
    } else if (CFDataGetLength(identifierData) != sizeof(UInt32)) {
        debug_string("MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverGetNextListenerIdentifierMessageID) returned wrong number of bytes");
    } else {
        CFStringRef localPortName;
        CFMessagePortContext context = { 0, NULL, NULL, NULL, NULL };

        // Now get the identifier and use it to name a newly created local port
        clientRef->clientIdentifier = *(UInt32 *)CFDataGetBytePtr(identifierData);
        localPortName = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@-%lu"), kSpyingMIDIDriverPortName, clientRef->clientIdentifier);

        context.info = clientRef;
        clientRef->localPort = CFMessagePortCreateLocal(kCFAllocatorDefault, localPortName, LocalMessagePortCallback, &context, FALSE);
        CFRelease(localPortName);

        if (!clientRef->localPort) {
            debug_string("MIDISpyClientCreate: CFMessagePortCreateLocal failed!");
        } else {
            // Add the local port to the current run loop, in common modes
            clientRef->runLoopSource = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, clientRef->localPort, 0);

            if (!clientRef->runLoopSource) {
                debug_string("MIDISpyClientCreate: CFMessagePortCreateRunLoopSource failed!");
            } else {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), clientRef->runLoopSource, kCFRunLoopCommonModes);
    
                // And now tell the spying driver to add us as a listener. Don't wait for a response.
                sendStatus = CFMessagePortSendRequest(driverPort, kSpyingMIDIDriverAddListenerMessageID, identifierData, 300, 0, NULL, NULL);
                if (sendStatus != kCFMessagePortSuccess) {
                    debug_string("MIDISpyClientCreate: CFMessagePortSendRequest(kSpyingMIDIDriverAddListenerMessageID) returned error");
                } else {
                    // Now create the array of ports, and dictionary of connnections for each endpoint
                    clientRef->ports = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
                    clientRef->endpointConnections = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
                    
                    // Success! (probably)
                    success = (clientRef->ports != NULL && clientRef->endpointConnections != NULL);
                }
            }
        }
    }

    if (identifierData)
        CFRelease(identifierData);

    if (!success) {
        MIDISpyClientDispose(clientRef);
        return kMIDISpyDriverCouldNotCommunicate;
    }

    *outClientRefPtr = clientRef;
    return noErr;
}


OSStatus MIDISpyClientDispose(MIDISpyClientRef clientRef)
{
    if (!clientRef)
        return paramErr;

    if (clientRef->endpointConnections) {
        CFRelease(clientRef->endpointConnections);
    }
            
    if (clientRef->ports) {
        CFIndex portIndex;

        portIndex = CFArrayGetCount(clientRef->ports);
        while (portIndex--) {
            MIDISpyPortRef port;

            port = (MIDISpyPortRef)CFArrayGetValueAtIndex(clientRef->ports, portIndex);
            MIDISpyPortDispose(port);
        }
        
        CFRelease(clientRef->ports);
    }
    
    if (clientRef->runLoopSource) {
        CFRunLoopSourceInvalidate(clientRef->runLoopSource);
        CFRelease(clientRef->runLoopSource);
    }

    if (clientRef->localPort) {
        CFMessagePortInvalidate(clientRef->localPort);
        CFRelease(clientRef->localPort);        
    }

    if (clientRef->driverPort) {
        CFMessagePortInvalidate(clientRef->driverPort);
        CFRelease(clientRef->driverPort);
    }
    
    free(clientRef);
    return noErr;
}


OSStatus MIDISpyPortCreate(MIDISpyClientRef clientRef, MIDIReadProc readProc, void *refCon, MIDISpyPortRef *outSpyPortRefPtr)
{
    MIDISpyPort *spyPortRef;

    if (!clientRef || !readProc || !outSpyPortRefPtr )
        return paramErr;

    spyPortRef = (MIDISpyPort *)malloc(sizeof(MIDISpyPort));
    if (!spyPortRef)
        return memFullErr;
    
    spyPortRef->client = clientRef;
    spyPortRef->readProc = readProc;
    spyPortRef->refCon = refCon;

    spyPortRef->connections = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
    if (!spyPortRef->connections) {
        free(spyPortRef);
        return memFullErr;        
    }

    CFArrayAppendValue(clientRef->ports, spyPortRef);

    *outSpyPortRefPtr = spyPortRef;
    return noErr;
}


OSStatus MIDISpyPortDispose(MIDISpyPortRef spyPortRef)
{
    CFMutableArrayRef ports;
    CFIndex portIndex;

    if (!spyPortRef)
        return paramErr;

    // Disconnect all of this port's connections
    if (spyPortRef->connections) {
        CFIndex connectionIndex;

        connectionIndex = CFArrayGetCount(spyPortRef->connections);
        while (connectionIndex--) {
            MIDISpyPortConnection *connection;

            connection = (MIDISpyPortConnection *)CFArrayGetValueAtIndex(spyPortRef->connections, connectionIndex);
            DisconnectConnection(spyPortRef, connection);
        }

        CFRelease(spyPortRef->connections);
    }

    // Remove this port from the client's array of ports    
    ports = spyPortRef->client->ports;
    portIndex = CFArrayGetFirstIndexOfValue(ports, CFRangeMake(0, CFArrayGetCount(ports)), spyPortRef);
    if (portIndex != kCFNotFound)
        CFArrayRemoveValueAtIndex(ports, portIndex);

    free(spyPortRef);

    return noErr;
}


OSStatus MIDISpyPortConnectDestination(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint, void *connectionRefCon)
{
    MIDISpyPortConnection *connection;

    if (!spyPortRef || !destinationEndpoint)
        return paramErr;

    // See if this port is already connected to this destination. If so, return an error.
    connection = GetPortConnection(spyPortRef, destinationEndpoint);
    if (connection)
        return kMIDISpyConnectionAlreadyExists;
    
    // Create a "connection" record for this port/endpoint pair, with the connectionRefCon in it.
    connection = (MIDISpyPortConnection *)malloc(sizeof(MIDISpyPortConnection));
    connection->port = spyPortRef;
    connection->endpoint = destinationEndpoint;
    connection->refCon = connectionRefCon;

    // Add the connection to the port's array of connections.
    CFArrayAppendValue(spyPortRef->connections, connection);

    ClientAddConnection(spyPortRef->client, connection);

    return noErr;
}


OSStatus MIDISpyPortDisconnectDestination(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint)
{
    MIDISpyPortConnection *connection;

    if (!spyPortRef || !destinationEndpoint)
        return paramErr;

    // See if this port is actually connected to this destination. If not, return an error.
    connection = GetPortConnection(spyPortRef, destinationEndpoint);
    if (!connection)
        return kMIDISpyConnectionDoesNotExist;

    DisconnectConnection(spyPortRef, connection);
    
    return noErr;
}


//
// Private functions
//

void InitializeConstantStrings(void)
{
    kSpyingMIDIDriverPlugInName = CFSTR("SpyingMIDIDriver.plugin");   
    kSpyingMIDIDriverPlugInIdentifier = CFSTR("com.snoize.SpyingMIDIDriver");   
    kSpyingMIDIDriverPortName = CFSTR("Spying MIDI Driver");   
}


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
    // TODO it would be better to do a recursive delete ourself.
    // TODO it is possible that something in this path (or the file itself) is an alias (w/resource fork)
    // so we should not use UNIX API/commands to delete it.
    char driverPath[PATH_MAX];
    char *argv[] = { "/bin/rm", "-rf", driverPath, NULL };

    if (!CFURLGetFileSystemRepresentation(driverURL, FALSE, (UInt8 *)driverPath, PATH_MAX)) {
        debug_string("MIDISpy: CFURLGetFileSystemRepresentation(driverPath) failed");
        return FALSE;
    }

    return ForkAndExec(argv);
}


static Boolean InstallDriver(CFURLRef ourDriverURL)
{
    OSErr error;
    FSRef folderFSRef;
    Boolean success = FALSE;

    // Find the directory "~/Library/Audio/MIDI Drivers". If it doesn't exist, create it.
    error = FSFindFolder(kUserDomain, kMIDIDriversFolderType, kCreateFolder, &folderFSRef);
    if (error != noErr) {
        debug_string("MIDISpy: FSFindFolder(kUserDomain, kMIDIDriversFolderType, kCreateFolder) returned error");
    } else {
        CFURLRef folderURL;

        folderURL = CFURLCreateFromFSRef(kCFAllocatorDefault, &folderFSRef);
        success = CopyDirectory(ourDriverURL, folderURL);

        CFRelease(folderURL);
    }
 
    return success;
}


static Boolean CopyDirectory(CFURLRef sourceDirectoryURL, CFURLRef targetDirectoryURL)
{
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

    // Copy (recursively) from the source into the target.
    // I know the driver doesn't contain any files with resource forks, so we are safe using UNIX commands for this.
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


// Keeping track of endpoints

void ReceiveMIDINotification(const MIDINotification *message, void *refCon)
{
    static Boolean retryAfterDone = FALSE;
    static Boolean isHandlingNotification = FALSE;

    if (!message || message->messageID != kMIDIMsgSetupChanged)
        return;
        
    if (isHandlingNotification) {
        retryAfterDone = TRUE;
        return;
    }

    do {
        isHandlingNotification = TRUE;
        retryAfterDone = FALSE;

        RebuildEndpointUniqueIDDictionary();

        isHandlingNotification = FALSE;
    } while (retryAfterDone);
}

void RebuildEndpointUniqueIDDictionary()
{
    // Make a dictionary which maps from an endpoint's uniqueID to its MIDIEndpointRef.
    ItemCount endpointIndex, endpointCount;

    endpointCount = MIDIGetNumberOfDestinations();

    if (sUniqueIDToEndpointDictionary)
        CFRelease(sUniqueIDToEndpointDictionary);
    sUniqueIDToEndpointDictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, endpointCount, NULL, NULL);
    
    for (endpointIndex = 0; endpointIndex < endpointCount; endpointIndex++) {
        MIDIEndpointRef endpoint;

        endpoint = MIDIGetDestination(endpointIndex);
        if (endpoint) {
            SInt32 uniqueID;

            if (noErr == MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID))
                CFDictionaryAddValue(sUniqueIDToEndpointDictionary, (void *)uniqueID, (void *)endpoint);
        }        
    }
}

MIDIEndpointRef EndpointWithUniqueID(SInt32 uniqueID)
{
    if (sUniqueIDToEndpointDictionary)
        return (MIDIEndpointRef)CFDictionaryGetValue(sUniqueIDToEndpointDictionary, (void *)uniqueID);
    else
        return NULL;
}


// Connection management

MIDISpyPortConnection *GetPortConnection(MIDISpyPortRef spyPortRef, MIDIEndpointRef destinationEndpoint)
{
    CFArrayRef connections;
    CFIndex connectionIndex;

    connections = spyPortRef->connections;
    connectionIndex = CFArrayGetCount(connections);
    while (connectionIndex--) {
        MIDISpyPortConnection *connection;

        connection = (MIDISpyPortConnection *)CFArrayGetValueAtIndex(connections, connectionIndex);
        if (connection->endpoint == destinationEndpoint)
            return connection;
    }

    return NULL;
}

void DisconnectConnection(MIDISpyPortRef spyPortRef, MIDISpyPortConnection *connection)
{
    CFMutableArrayRef connections;
    CFIndex connectionIndex;

    connections = spyPortRef->connections;
    connectionIndex = CFArrayGetFirstIndexOfValue(connections, CFRangeMake(0, CFArrayGetCount(connections)), connection);
    if (connectionIndex != kCFNotFound)
        CFArrayRemoveValueAtIndex(connections, connectionIndex);

    ClientRemoveConnection(spyPortRef->client, connection);
    
    free(connection);
}

void ClientAddConnection(MIDISpyClientRef clientRef, MIDISpyPortConnection *connection)
{
    CFMutableArrayRef connections;
    Boolean isFirstConnectionToEndpoint = FALSE;

    connections = GetConnectionsToEndpoint(clientRef, connection->endpoint);
    if (!connections) {
        connections = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
        CFDictionarySetValue(clientRef->endpointConnections, connection->endpoint, connections);
        CFRelease(connections);
        isFirstConnectionToEndpoint = TRUE;
    }
    CFArrayAppendValue(connections, connection);

    if (isFirstConnectionToEndpoint) {
        SetClientSubscribesToDataFromEndpoint(clientRef, connection->endpoint, TRUE);
    }    
}

void ClientRemoveConnection(MIDISpyClientRef clientRef, MIDISpyPortConnection *connection)
{
    CFMutableArrayRef connections;

    connections = GetConnectionsToEndpoint(clientRef, connection->endpoint);
    if (connections) {
        CFIndex connectionIndex;

        connectionIndex = CFArrayGetFirstIndexOfValue(connections, CFRangeMake(0, CFArrayGetCount(connections)), connection);
        if (connectionIndex != kCFNotFound)
            CFArrayRemoveValueAtIndex(connections, connectionIndex);
    }

    if (connections && CFArrayGetCount(connections) == 0) {
        CFDictionaryRemoveValue(clientRef->endpointConnections, connection->endpoint);
        SetClientSubscribesToDataFromEndpoint(clientRef, connection->endpoint, FALSE);
    }    
}

CFMutableArrayRef GetConnectionsToEndpoint(MIDISpyClientRef clientRef, MIDIEndpointRef endpoint)
{
    return (CFMutableArrayRef)CFDictionaryGetValue(clientRef->endpointConnections, endpoint);
}


// Communication with driver

void SetClientSubscribesToDataFromEndpoint(MIDISpyClientRef clientRef, MIDIEndpointRef endpoint, Boolean subscribes)
{
    // Send a request to the driver to start or stop sending info about the endpoint.

    SInt32 msgid;
    SInt32 endpointUniqueID;
    CFIndex dataLength;
    CFMutableDataRef messageData;
    UInt8 *dataBuffer;

    msgid = (subscribes ? kSpyingMIDIDriverConnectDestinationMessageID : kSpyingMIDIDriverDisconnectDestinationMessageID);

    if (noErr != MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &endpointUniqueID))
        return;
    
    dataLength = sizeof(UInt32) + sizeof(SInt32);
    messageData = CFDataCreateMutable(kCFAllocatorDefault, dataLength);
    CFDataSetLength(messageData, dataLength);
    dataBuffer = CFDataGetMutableBytePtr(messageData);
    if (!dataBuffer)
        return;
    *(UInt32 *)dataBuffer = clientRef->clientIdentifier;
    *(SInt32 *)(dataBuffer + sizeof(UInt32)) = endpointUniqueID;
        
    CFMessagePortSendRequest(clientRef->driverPort, msgid, messageData, 300, 0, NULL, NULL);
}

static CFDataRef LocalMessagePortCallback(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info)
{
    const UInt8 *bytes;
    SInt32 endpointUniqueID;
    const MIDIPacketList *packetList;
    MIDIEndpointRef endpoint;
    MIDISpyClientRef clientRef = (MIDISpyClientRef)info;

    if (!data) {
        debug_string("MIDISpyClient: Got empty data from driver!");
        return NULL;
    } else if (CFDataGetLength(data) < (sizeof(SInt32) + sizeof(UInt32))) {
        debug_string("MIDISpyClient: Got too-small data from driver!");
        return NULL;
    }

    bytes = CFDataGetBytePtr(data);

    endpointUniqueID = *(SInt32 *)bytes;
    packetList = (const MIDIPacketList *)(bytes + sizeof(SInt32));

    // Find the endpoint with this unique ID.
    // Then find all ports which are connected to this endpoint,
    // and for each, call port->readProc(packetList, port->refCon, connection->refCon)

    endpoint = EndpointWithUniqueID(endpointUniqueID);
    if (endpoint) {
        CFArrayRef connections;

        if ((connections = GetConnectionsToEndpoint(clientRef, endpoint))) {
            CFIndex connectionIndex;

            connectionIndex = CFArrayGetCount(connections);
            while (connectionIndex--) {
                MIDISpyPortConnection *connection;

                connection = (MIDISpyPortConnection *)CFArrayGetValueAtIndex(connections, connectionIndex);
                connection->port->readProc(packetList, connection->port->refCon, connection->refCon);
            }
        }        
    }

    // No reply
    return NULL;
}
