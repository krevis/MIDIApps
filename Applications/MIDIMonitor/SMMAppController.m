#import "SMMAppController.h"

#import <Cocoa/Cocoa.h>
#import <CoreMIDI/CoreMIDI.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMDocument.h"
#import "SMMPreferencesWindowController.h"


@interface SMMAppController (Private)

- (void)_endpointWasAdded:(NSNotification *)notification;

@end


@implementation SMMAppController

NSString *SMMOpenWindowsForNewSourcesPreferenceKey = @"SMMOpenWindowsForNewSources";


- (void)applicationDidFinishLaunching:(NSNotification *)notification;
{
    // Make sure we go multithreaded, and that our scheduler starts up
    [OFScheduler mainScheduler];
    
    // Listen for new endpoints. Don't do this earlier--we only are interested in ones
    // that appear after we've been launched.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_endpointWasAdded:) name:SMEndpointWasAddedNotification object:nil];
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

- (void)_endpointWasAdded:(NSNotification *)notification;
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

@end
