#import "SMMAppController.h"

#import <CoreMIDI/CoreMIDI.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>
#import <SnoizeMIDISpy/SnoizeMIDISpy.h>

#import "SMMDocument.h"
#import "SMMPreferencesWindowController.h"


@interface SMMAppController (Private)

- (void)_endpointAppeared:(NSNotification *)notification;

@end


@implementation SMMAppController

NSString *SMMOpenWindowsForNewSourcesPreferenceKey = @"SMMOpenWindowsForNewSources";

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
{
    SInt32 spyStatus;
    
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

- (BOOL)shouldUseMIDISpy;
{
    return shouldUseMIDISpy;
}

@end


@implementation SMMAppController (Private)

- (void)_endpointAppeared:(NSNotification *)notification;
{
    // TODO reimplement this
    /*

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
     */
}

@end
