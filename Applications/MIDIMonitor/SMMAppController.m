#import "SMMAppController.h"

#import <CoreMIDI/CoreMIDI.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>
#import <SnoizeMIDISpy/SnoizeMIDISpy.h>

#import "SMMDocument.h"
#import "SMMPreferencesWindowController.h"


@interface SMMAppController (Private)

- (void)_endpointsAppeared:(NSNotification *)notification;

@end


@implementation SMMAppController

NSString *SMMOpenWindowsForNewSourcesPreferenceKey = @"SMMOpenWindowsForNewSources";

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
{
    BOOL shouldUseMIDISpy;
    SInt32 spyStatus;
    OSStatus status;
    
    // Make sure we go multithreaded, and that our scheduler starts up
    [OFScheduler mainScheduler];

    // Before CoreMIDI is initialized, make sure the spying driver is installed
    shouldUseMIDISpy = NO;
    spyStatus = MIDISpyInstallDriverIfNecessary();
    switch (spyStatus) {
        case kMIDISpyDriverAlreadyInstalled:
        case kMIDISpyDriverInstalledSuccessfully:
            shouldUseMIDISpy = YES;
            break;

        case kMIDISpyDriverInstallationFailed:
        case kMIDISpyDriverCouldNotRemoveOldDriver:
        default:
            // TODO We need to report this error later on
            break;
    }

    // Initialize CoreMIDI while the app's icon is still bouncing, so we don't have a large pause after it stops bouncing
    // but before the app's window opens.  (CoreMIDI needs to find and possibly start its server process, which can take a while.)
    if ([SMClient sharedClient] == nil) {
        shouldOpenUntitledDocument = NO;
        NSRunCriticalAlertPanel(@"Error", @"%@", @"Quit", nil, nil, @"There was a problem initializing the MIDI system. To try to fix this, log out and log back in, or restart the computer.");
        [NSApp terminate:nil];
    } else {
        shouldOpenUntitledDocument = YES;        
    }

    if (shouldUseMIDISpy) {
        // Create our client for spying on MIDI output.
        status = MIDISpyClientCreate(&midiSpyClient);
        if (status != noErr) {
#if DEBUG
            NSLog(@"Couldn't create a MIDI spy client: error %ld", status);
#endif
            // TODO We need to report this error, too
        }
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_endpointsAppeared:) name:SMEndpointsAppearedNotification object:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification;
{
    if (midiSpyClient) {
        // Just invalidate the client, so the driver loses track of it (and thus gets rid of its internal MIDIClient if necessary).
        // But don't dispose of the client, since we may still have outstanding MIDISpyPorts in documents, and trying to dispose of
        // them after the MIDISpyClient is gone is a bad idea.
        MIDISpyClientInvalidate(midiSpyClient);
        midiSpyClient = NULL;
    }
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
    NSString *message = nil;
    
    path = [[self bundle] pathForResource:@"docs" ofType:@"htmld"];
    if (path) {
        path = [path stringByAppendingString:@"/index.html"];
        if (![[NSWorkspace sharedWorkspace] openFile:path]) {
            message = NSLocalizedStringFromTableInBundle(@"The help file could not be opened.", @"MIDIMonitor", [self bundle], "error message if opening the help file fails");
        }
    } else {
        message = NSLocalizedStringFromTableInBundle(@"The help file could not be found.", @"MIDIMonitor", [self bundle], "error message if help file can't be found");
    }

    if (message) {
        NSString *title;

        title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", [self bundle], "title of error alert");
        NSRunAlertPanel(title, message, nil, nil, nil);
    }
}

- (IBAction)restartMIDI:(id)sender;
{
    OSStatus err;

    err = MIDIRestart();
    if (err) {
        NSString *message, *title;

        message = NSLocalizedStringFromTableInBundle(@"Restarting MIDI resulted in an unexpected error (%d).", @"MIDIMonitor", [self bundle], "error message if MIDIRestart() fails");
        title = NSLocalizedStringFromTableInBundle(@"MIDI Error", @"MIDIMonitor", [self bundle], "title of MIDI error panel");
        NSRunAlertPanel(title, message, nil, nil, nil, err);        
    }
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    if ([anItem action] == @selector(restartMIDI:)) {
        return (NSAppKitVersionNumber > NSAppKitVersionNumber10_0);    
    }

    return YES;
}

- (MIDISpyClientRef)midiSpyClient;
{
    return midiSpyClient;
}

@end


@implementation SMMAppController (Private)

- (void)_endpointsAppeared:(NSNotification *)notification;
{
    NSArray *endpoints;
    unsigned int endpointIndex, endpointCount;
    NSMutableSet *sourceEndpointSet;

    if (![[OFPreference preferenceForKey:SMMOpenWindowsForNewSourcesPreferenceKey] boolValue])
        return;

    endpoints = [notification object];
    endpointCount = [endpoints count];
    sourceEndpointSet = [NSMutableSet setWithCapacity:endpointCount];
    for (endpointIndex = 0; endpointIndex < endpointCount; endpointIndex++) {
        id endpoint;

        endpoint = [endpoints objectAtIndex:endpointIndex];
        if ([endpoint isKindOfClass:[SMSourceEndpoint class]])
            [sourceEndpointSet addObject:endpoint];
    }

    if ([sourceEndpointSet count] > 0) {
        SMMDocument *document;

        document = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MIDI Monitor Document" display:NO];
        [document setSelectedInputSources:sourceEndpointSet];
        [document showWindows];
        [document setAreSourcesShown:YES];
        // TODO it would be cool to have the Sources section of the outline view reveal itself and perhaps scroll to the first of the new sources!
    }
}

@end
