#import "SSEAppController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SSEMainWindowController.h"
#import "SSEPreferencesWindowController.h"
#import "SSELibrary.h"


@interface SSEAppController (Private)

- (void)_importFiles;

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
        NSRunCriticalAlertPanel(@"Error", @"%@", @"Quit", nil, nil, @"There was a problem initializing the MIDI system. To try to fix this, log out and log back in, or restart the computer.");
        [NSApp terminate:nil];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
{
    NSString *preflightError;
    
    hasFinishedLaunching = YES;

    preflightError = [[SSELibrary sharedLibrary] preflightAndLoadEntries];
    if (preflightError) {
        NSRunCriticalAlertPanel(@"Error", @"%@", @"Quit", nil, nil, preflightError);
        [NSApp terminate:nil];
    } else {
        [self showMainWindow:nil];

        if (filesToImport)
            [self _importFiles];
    }
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename;
{
    if (!filesToImport)
        filesToImport = [[NSMutableArray alloc] init];
    [filesToImport addObject:filename];

    if (hasFinishedLaunching)
        [self _importFiles];

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

    [[NSApplication sharedApplication] orderFrontStandardAboutPanelWithOptions:optionsDictionary];

    [optionsDictionary release];
}

- (IBAction)showHelp:(id)sender;
{
    NSString *path;
    
    path = [[self bundle] pathForResource:@"docs" ofType:@"htmld"];
    if (path) {
        path = [path stringByAppendingPathComponent:@"index.html"];
        [[NSWorkspace sharedWorkspace] openFile:path];
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

- (void)_importFiles;
{
    [[SSEMainWindowController mainWindowController] importFiles:filesToImport showingProgress:NO];
    [filesToImport release];
    filesToImport = nil;
}

@end
