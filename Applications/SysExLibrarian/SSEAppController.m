#import "SSEAppController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SSEMainWindowController.h"
#import "SSEPreferencesWindowController.h"


@interface SSEAppController (Private)

- (void)_openFiles:(NSArray *)filenames;

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
    // Initialize CoreMIDI while the app's icon is still bouncing, so we don't have a large pause after it stops bouncing
    // but before the app's window opens.  (CoreMIDI needs to find and possibly start its server process, which can take a while.)
    [SMClient sharedClient];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
{
    hasFinishedLaunching = YES;
    
    // Make sure we go multithreaded, and that our scheduler starts up
    [OFScheduler mainScheduler];

    [self showMainWindow:nil];

    if (filesToOpenAfterLaunch) {
        [[SSEMainWindowController mainWindowController] importFiles:filesToOpenAfterLaunch];
        [filesToOpenAfterLaunch release];
        filesToOpenAfterLaunch = nil;
    }
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename;
{
    if (hasFinishedLaunching) {
        [[SSEMainWindowController mainWindowController] importFiles:[NSArray arrayWithObject:filename]];
    } else {
        if (!filesToOpenAfterLaunch)
            filesToOpenAfterLaunch = [[NSMutableArray alloc] init];

        [filesToOpenAfterLaunch addObject:filename];
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
