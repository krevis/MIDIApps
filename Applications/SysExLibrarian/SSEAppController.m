#import "SSEAppController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SSEMainWindowController.h"
#import "SSEPreferencesWindowController.h"
#import "SSELibrary.h"


@interface SSEAppController (Private)

- (void)importFiles;

@end


@implementation SSEAppController

- (id)init;
{
    if (![super init])
        return nil;

    hasFinishedLaunching = NO;

    return self;
}

//
// Application delegate
//

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
{
    // Make sure we go multithreaded, and that our scheduler starts up
    [OFScheduler mainScheduler];

    // Initialize CoreMIDI while the app's icon is still bouncing, so we don't have a large pause after it stops bouncing
    // but before the app's window opens.  (CoreMIDI needs to find and possibly start its server process, which can take a while.)
    if ([SMClient sharedClient] == nil) {
        NSString *title, *message, *quit;

        title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", [self bundle], "title of error alert");
        message = NSLocalizedStringFromTableInBundle(@"There was a problem initializing the MIDI system. To try to fix this, log out and log back in, or restart the computer.", @"SysExLibrarian", [self bundle], "error message if MIDI initialization fails");
        quit = NSLocalizedStringFromTableInBundle(@"Quit", @"SysExLibrarian", [self bundle], "title of quit button");

        NSRunCriticalAlertPanel(title, @"%@", quit, nil, nil, message);
        [NSApp terminate:nil];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
{
    NSString *preflightError;
    
    hasFinishedLaunching = YES;

    preflightError = [[SSELibrary sharedLibrary] preflightAndLoadEntries];
    if (preflightError) {
        NSString *title, *quit;
        
        title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", [self bundle], "title of error alert");
        quit = NSLocalizedStringFromTableInBundle(@"Quit", @"SysExLibrarian", [self bundle], "title of quit button");

        NSRunCriticalAlertPanel(title, @"%@", quit, nil, nil, preflightError);
        [NSApp terminate:nil];
    } else {
        [self showMainWindow:nil];

        if (filesToImport)
            [self importFiles];
    }
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename;
{
    if (!filesToImport)
        filesToImport = [[NSMutableArray alloc] init];
    [filesToImport addObject:filename];

    if (hasFinishedLaunching) {
        [self showMainWindow:nil];
        [self importFiles];
    }

    return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag;
{
    if (flag) {
        NSWindow *mainWindow;

        mainWindow = [[SSEMainWindowController mainWindowController] window];
        if (mainWindow && [mainWindow isMiniaturized])
            [mainWindow deminiaturize:nil];
    } else {
        [self showMainWindow:nil];
    }

    return NO;
}

//
// Action validation
//

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)theItem;
{
    if ([theItem action] == @selector(showMainWindowAndAddToLibrary:)) {
        // Don't allow adds if the main window is open and has a sheet on it
        NSWindow *mainWindow;

        mainWindow = [[SSEMainWindowController mainWindowController] window];
        return (!mainWindow || [mainWindow attachedSheet] == nil);
    }

    return YES;
}

//
// Actions
//

- (IBAction)showPreferences:(id)sender;
{
    [[SSEPreferencesWindowController preferencesWindowController] showWindow:nil];
}

- (IBAction)showAboutBox:(id)sender;
{
    NSMutableDictionary *optionsDictionary;

    optionsDictionary = [[NSMutableDictionary alloc] init];
    [optionsDictionary setObject:@"" forKey:@"Version"];

    [NSApp orderFrontStandardAboutPanelWithOptions:optionsDictionary];

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
            message = NSLocalizedStringFromTableInBundle(@"The help file could not be opened.", @"SysExLibrarian", [self bundle], "error message if opening the help file fails");
        }
    } else {
        message = NSLocalizedStringFromTableInBundle(@"The help file could not be found.", @"SysExLibrarian", [self bundle], "error message if help file can't be found");
    }

    if (message) {
        NSString *title;

        title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", [self bundle], "title of error alert");
        NSRunAlertPanel(title, @"%@", nil, nil, nil, message);
    }
}

- (IBAction)sendFeedback:(id)sender;
{
    NSString *feedbackEmailAddress, *feedbackEmailSubject;
    NSString *mailToURLString;
    NSURL *mailToURL;
    BOOL success = NO;

    feedbackEmailAddress = @"SysExLibrarian@snoize.com";	// Don't localize this
    feedbackEmailSubject = NSLocalizedStringFromTableInBundle(@"SysEx Librarian Feedback", @"SysExLibrarian", [self bundle], "subject of feedback email");
    mailToURLString = [[NSString stringWithFormat:@"mailto:%@?Subject=%@", feedbackEmailAddress, feedbackEmailSubject] fullyEncodeAsIURI];
    mailToURL = [NSURL URLWithString:mailToURLString];
    if (mailToURL)
        success = [[NSWorkspace sharedWorkspace] openURL:mailToURL];

    if (!success) {
        NSString *message, *title;

        NSLog(@"Couldn't send feedback: url string was <%@>, url was <%@>", mailToURLString, mailToURL);

        title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", [self bundle], "title of error alert");
        message = NSLocalizedStringFromTableInBundle(@"SysEx Librarian could not ask your email application to create a new message, so you will have to do it yourself. Please send your email to this address:\n%@\nThank you!", @"SysExLibrarian", [self bundle], "message of alert when can't send feedback email");

        NSRunAlertPanel(title, message, nil, nil, nil, feedbackEmailAddress);
    }
}

- (IBAction)showMainWindow:(id)sender;
{
    [[SSEMainWindowController mainWindowController] showWindow:nil];
}

- (IBAction)showMainWindowAndAddToLibrary:(id)sender;
{
    SSEMainWindowController *controller;

    controller = [SSEMainWindowController mainWindowController];
    [controller showWindow:nil];
    [controller addToLibrary:sender];
}

@end


@implementation SSEAppController (Private)

- (void)importFiles;
{
    [[SSEMainWindowController mainWindowController] importFiles:filesToImport showingProgress:NO];
    [filesToImport release];
    filesToImport = nil;
}

@end
