#import "SMMAppController.h"

#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMDocument.h"
#import "SMMPreferencesWindowController.h"


@interface SMMAppController (Private)

- (void)_endpointAppeared:(NSNotification *)notification;

- (void)_connectToSpyingMIDIDriver;

@end


@implementation SMMAppController

NSString *SMMOpenWindowsForNewSourcesPreferenceKey = @"SMMOpenWindowsForNewSources";

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
{
    // Make sure we go multithreaded, and that our scheduler starts up
    [OFScheduler mainScheduler];

    // Initialize CoreMIDI while the app's icon is still bouncing, so we don't have a large pause after it stops bouncing
    // but before the app's window opens.  (CoreMIDI needs to find and possibly start its server process, which can take a while.)
    if ([SMClient sharedClient] == nil) {
        shouldOpenUntitledDocument = NO;
        NSRunCriticalAlertPanel(@"Error", @"%@", @"Quit", nil, nil, @"There was a problem initializing the MIDI system. To try to fix this, log out and log back in, or restart the computer.");
        [NSApp terminate:nil];
    } else {
        shouldOpenUntitledDocument = YES;        
    }
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender;
{
    return shouldOpenUntitledDocument;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
{
    // Listen for new endpoints. Don't do this earlier--we only are interested in ones
    // that appear after we've been launched.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_endpointAppeared:) name:SMEndpointAppearedNotification object:nil];

    // TODO temporary
    // hook up with the spying MIDI driver, if possible
    [self _connectToSpyingMIDIDriver];
}

- (IBAction)showPreferences:(id)sender;
{
    [[SMMPreferencesWindowController preferencesWindowController] showWindow:nil];
}

- (IBAction)showAboutBox:(id)sender;
{
    NSMutableDictionary *optionsDictionary;

    optionsDictionary = [[NSMutableDictionary alloc] init];
    [optionsDictionary setObject:@"" forKey:@"Version"];

    [[NSApplication sharedApplication] orderFrontStandardAboutPanelWithOptions:optionsDictionary];

    [optionsDictionary release];
}

- (IBAction)showHelp:(id)sender;
{
    NSString *path;
    
    path = [[self bundle] pathForResource:@"docs" ofType:@"htmld"];
    if (path) {
        path = [path stringByAppendingString:@"/index.html"];
        [[NSWorkspace sharedWorkspace] openFile:path];
    }
}

- (IBAction)restartMIDI:(id)sender;
{
    OSStatus err;

    err = MIDIRestart();
    if (err)
        NSRunAlertPanel(@"MIDI Error", @"Restarting MIDI resulted in error %d.", @"OK", nil, nil, err);
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    if ([anItem action] == @selector(restartMIDI:)) {
        return (NSAppKitVersionNumber > NSAppKitVersionNumber10_0);    
    }

    return YES;
}

@end


@implementation SMMAppController (Private)

- (void)_endpointAppeared:(NSNotification *)notification;
{
    if ([[OFPreference preferenceForKey:SMMOpenWindowsForNewSourcesPreferenceKey] boolValue]) {
        SMEndpoint *endpoint;
        
        endpoint = [notification object];
        if ([endpoint isKindOfClass:[SMSourceEndpoint class]]) {
            SMMDocument *document;
            NSArray *sourceDescriptions;
            unsigned int descriptionIndex;
            
            document = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MIDI Monitor Document" display:NO];

            // Find the source description which has this endpoint, and tell the document to use it
            sourceDescriptions = [document sourceDescriptions];
            descriptionIndex = [sourceDescriptions count];
            while (descriptionIndex--) {
                NSDictionary *description;
                SMEndpoint *descriptionEndpoint;
                
                description = [sourceDescriptions objectAtIndex:descriptionIndex];
                descriptionEndpoint = [description objectForKey:@"endpoint"];
                if (descriptionEndpoint && descriptionEndpoint == endpoint) {
                    [document setSourceDescription:description];
                    break;
                }            
            }

            [document showWindows];
        }
    }
}

static CFMessagePortRef localPort = NULL;
static CFRunLoopSourceRef localPortRunLoopSource = NULL;


static CFDataRef localMessagePortCallback(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info)
{
    const UInt8 *bytes;
    SInt32 endpointUniqueID;
    const char *endpointNameCString;
    const MIDIPacketList *packetList;

    if (!data || CFDataGetLength(data) < (sizeof(SInt32) + 1 + sizeof(UInt32))) {
        NSLog(@"no data or not enough data: %@", data);
        return NULL;
    }
    
    bytes = CFDataGetBytePtr(data);

    endpointUniqueID = *(SInt32 *)bytes;
    endpointNameCString = (const char *)(bytes + sizeof(SInt32));
    packetList = (const MIDIPacketList *)(bytes + sizeof(SInt32) + strlen(endpointNameCString) + 1);        

    NSLog(@"got data from Spying MIDI Driver: unique ID %ld, name %s, packet list w/%lu packets",  endpointUniqueID, endpointNameCString, packetList->numPackets);

    return NULL;
}

- (void)_connectToSpyingMIDIDriver;
{
    CFMessagePortRef spyingMIDIDriverMessagePort;
    SInt32 sendStatus;
    CFDataRef sequenceNumberData = NULL;

    spyingMIDIDriverMessagePort = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("Spying MIDI Driver"));
    if (!spyingMIDIDriverMessagePort) {
        NSLog(@"couldn't find message port for Spying MIDI Driver");
        return;
    }

    // ask for the next sequence number
    sendStatus = CFMessagePortSendRequest(spyingMIDIDriverMessagePort, 0, NULL, 300, 300, kCFRunLoopDefaultMode, &sequenceNumberData);
    if (sendStatus != kCFMessagePortSuccess) {
        NSLog(@"CFMessagePortSendRequest(0) returned error: %ld", sendStatus);
    } else if (!sequenceNumberData) {
        NSLog(@"CFMessagePortSendRequest(0) returned no data");
    } else if (CFDataGetLength(sequenceNumberData) != sizeof(UInt32)) {
        NSLog(@"CFMessagePortSendRequest(0) returned %lu bytes, not %lu", CFDataGetLength(sequenceNumberData), sizeof(UInt32));
    } else {
        UInt32 sequenceNumber;
        NSString *localPortName;

        // Now get the sequence number and use it to name a newly created local port
        sequenceNumber = *(UInt32 *)CFDataGetBytePtr(sequenceNumberData);
        localPortName = [NSString stringWithFormat:@"Spying MIDI Driver-%lu", sequenceNumber];

        localPort = CFMessagePortCreateLocal(kCFAllocatorDefault, (CFStringRef)localPortName, localMessagePortCallback, NULL, FALSE);
        if (!localPort) {
            NSLog(@"CFMessagePortCreateLocal failed!");
        } else {
            // Add the local port to the run loop
            localPortRunLoopSource = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, localPort, 0);
            CFRunLoopAddSource(CFRunLoopGetCurrent(), localPortRunLoopSource, kCFRunLoopDefaultMode);
            
            // And now tell the spying driver to add us as a listener (don't wait for a response)
            sendStatus = CFMessagePortSendRequest(spyingMIDIDriverMessagePort, 1, sequenceNumberData, 300, 0, NULL, NULL);
            if (sendStatus != kCFMessagePortSuccess) {
                NSLog(@"CFMessagePortSendRequest(1) returned error: %ld", sendStatus);
            }
        }
    }

    if (sequenceNumberData)
        CFRelease(sequenceNumberData);

    if (spyingMIDIDriverMessagePort)
        CFRelease(spyingMIDIDriverMessagePort);
}

@end
