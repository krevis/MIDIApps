#import "SMMAppController.h"

#import <CoreMIDI/CoreMIDI.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>
#import <SnoizeMIDISpy/SnoizeMIDISpy.h>

#import "SMMDocument.h"
#import "SMMPreferencesWindowController.h"


@interface SMMAppController (Private)

- (void)sourceEndpointsAppeared:(NSNotification *)notification;

@end


@implementation SMMAppController

NSString *SMMOpenWindowsForNewSourcesPreferenceKey = @"SMMOpenWindowsForNewSources";

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
{
    BOOL shouldUseMIDISpy;
    SInt32 spyStatus;
    NSString *midiSpyErrorMessage = nil;
    
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

        case kMIDISpyDriverCouldNotRemoveOldDriver:
            midiSpyErrorMessage = NSLocalizedStringFromTableInBundle(@"There is an old version of MIDI Monitor's driver installed, but it could not be removed. To fix this, remove the old driver. (It is probably \"Library/Audio/MIDI Drivers/MIDI Monitor.plugin\" in your home folder.)", @"MIDIMonitor", [self bundle], "error message if old MIDI spy driver could not be removed");
            break;

        case kMIDISpyDriverInstallationFailed:
        default:
            midiSpyErrorMessage = NSLocalizedStringFromTableInBundle(@"MIDI Monitor tried to install a MIDI driver in \"Library/Audio/MIDI Drivers\" in your your home folder, but it failed. (Do the privileges allow write access?)", @"MIDIMonitor", [self bundle], "error message if MIDI spy driver installation fails");
            break;
    }

    // Initialize CoreMIDI while the app's icon is still bouncing, so we don't have a large pause after it stops bouncing
    // but before the app's window opens.  (CoreMIDI needs to find and possibly start its server process, which can take a while.)
    if ([SMClient sharedClient] == nil) {
        NSString *title, *message, *quit;
        
        shouldOpenUntitledDocument = NO;

        title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", [self bundle], "title of error alert");
        message = NSLocalizedStringFromTableInBundle(@"There was a problem initializing the MIDI system. To try to fix this, log out and log back in, or restart the computer.", @"MIDIMonitor", [self bundle], "error message if MIDI initialization fails");
        quit = NSLocalizedStringFromTableInBundle(@"Quit", @"MIDIMonitor", [self bundle], "title of quit button");

        NSRunCriticalAlertPanel(title, @"%@", quit, nil, nil, message);
        [NSApp terminate:nil];
    } else {
        shouldOpenUntitledDocument = YES;        
    }

    if (shouldUseMIDISpy) {
        OSStatus status;
        
        // Create our client for spying on MIDI output.
        status = MIDISpyClientCreate(&midiSpyClient);
        if (status != noErr) {
            midiSpyErrorMessage = NSLocalizedStringFromTableInBundle(@"MIDI Monitor could not make a connection to its MIDI driver. To fix the problem, quit all MIDI applications (including this one) and launch them again.", @"MIDIMonitor", [self bundle], "error message if MIDI spy client creation fails");
        }
    }

    if (midiSpyErrorMessage) {
        NSString *title;
        NSString *message2;

        title = NSLocalizedStringFromTableInBundle(@"Warning", @"MIDIMonitor", [self bundle], "title of warning alert");
        message2 = NSLocalizedStringFromTableInBundle(@"For now, MIDI Monitor will not be able to spy on the output of other MIDI applications, but all other features will still work.", @"MIDIMonitor", [self bundle], "second line of warning when MIDI spy is unavailable");
        
        NSRunAlertPanel(title, @"%@\n\n%@", nil, nil, nil, midiSpyErrorMessage, message2);
    }    
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender;
{
    return shouldOpenUntitledDocument;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
{
    // Listen for new source endpoints. Don't do this earlier--we only are interested in ones
    // that appear after we've been launched.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sourceEndpointsAppeared:) name:SMMIDIObjectsAppearedNotification object:[SMSourceEndpoint class]];
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
        path = [path stringByAppendingPathComponent:@"index.html"];
        if (![[NSWorkspace sharedWorkspace] openFile:path]) {
            message = NSLocalizedStringFromTableInBundle(@"The help file could not be opened.", @"MIDIMonitor", [self bundle], "error message if opening the help file fails");
        }
    } else {
        message = NSLocalizedStringFromTableInBundle(@"The help file could not be found.", @"MIDIMonitor", [self bundle], "error message if help file can't be found");
    }

    if (message) {
        NSString *title;

        title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", [self bundle], "title of error alert");
        NSRunAlertPanel(title, @"%@", nil, nil, nil, message);
    }
}

- (IBAction)sendFeedback:(id)sender;
{
    NSString *feedbackEmailAddress, *feedbackEmailSubject;
    NSString *mailToURLString;
    NSURL *mailToURL;
    BOOL success = NO;

    feedbackEmailAddress = @"MIDIMonitor@snoize.com";	// Don't localize this
    feedbackEmailSubject = NSLocalizedStringFromTableInBundle(@"MIDI Monitor Feedback", @"MIDIMonitor", [self bundle], "subject of feedback email");    
    mailToURLString = [[NSString stringWithFormat:@"mailto:%@?Subject=%@", feedbackEmailAddress, feedbackEmailSubject] fullyEncodeAsIURI];
    mailToURL = [NSURL URLWithString:mailToURLString];
    if (mailToURL)
        success = [[NSWorkspace sharedWorkspace] openURL:mailToURL];

    if (!success) {
        NSString *message, *title;
        
        NSLog(@"Couldn't send feedback: url string was <%@>, url was <%@>", mailToURLString, mailToURL);

        title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", [self bundle], "title of error alert");
        message = NSLocalizedStringFromTableInBundle(@"MIDI Monitor could not ask your email application to create a new message, so you will have to do it yourself. Please send your email to this address:\n%@\nThank you!", @"MIDIMonitor", [self bundle], "message of alert when can't send feedback email");
        
        NSRunAlertPanel(title, message, nil, nil, nil, feedbackEmailAddress);
    }
}

- (IBAction)restartMIDI:(id)sender;
{
    NSString *message, *title, *cancelButtonTitle;
    int alertButton;

    // Ask the user to confirm first
    message = NSLocalizedStringFromTableInBundle(@"Are you sure you want to restart the MIDI system? It may cause an interruption of MIDI input and output, and may also confuse other running MIDI applications.", @"MIDIMonitor", [self bundle], "message for confirmation panel for Restart MIDI");
    title = NSLocalizedStringFromTableInBundle(@"Warning", @"MIDIMonitor", [self bundle], "title of warning alert");
    cancelButtonTitle = NSLocalizedStringFromTableInBundle(@"Cancel", @"MIDIMonitor", [self bundle], "title of cancel button");

    alertButton = NSRunAlertPanel(title, message, nil /* "OK" */, cancelButtonTitle, nil);
    
    if (alertButton == NSAlertDefaultReturn) {
        OSStatus status = MIDIRestart();
        if (status) {
            // Something went wrong!

            message = NSLocalizedStringFromTableInBundle(@"Restarting MIDI resulted in an unexpected error (%d).", @"MIDIMonitor", [self bundle], "error message if MIDIRestart() fails");
            title = NSLocalizedStringFromTableInBundle(@"MIDI Error", @"MIDIMonitor", [self bundle], "title of MIDI error panel");
            NSRunAlertPanel(title, message, nil, nil, nil, status);        
        }
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

- (void)sourceEndpointsAppeared:(NSNotification *)notification;
{
    NSArray *endpoints;
    NSSet *endpointSet;
    SMMDocument *document;

    if (![[OFPreference preferenceForKey:SMMOpenWindowsForNewSourcesPreferenceKey] boolValue])
        return;

    endpoints = [[notification userInfo] objectForKey:SMMIDIObjectsThatAppeared];
    endpointSet = [NSSet setWithArray:endpoints];

    document = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MIDI Monitor Document" display:NO];
    [document setSelectedInputSources:endpointSet];
    [document showWindows];
    [document setAreSourcesShown:YES];
    [document revealInputSources:endpointSet];
}

@end
