#import "SSEAppController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SSEMainWindowController.h"
#import "SSEPreferencesWindowController.h"


@implementation SSEAppController

//
// Application delegate
//

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
{
    // Make sure we go multithreaded, and that our scheduler starts up
    [OFScheduler mainScheduler];

    [self showMainWindow:nil];
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename;
{
    // TODO
    // If the file is a library, need to use it
    // If the file is a sysex file, need to add it to the library if it's not already there,
    // and then select it in the library  (and perhaps play it?)
    // NOTE: If the user double-clicks a file to launch us, this will get sent before -applicationDidFinishLaunching!
    // So we may need to remember the filename here and do something with it later.
    return NO;
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
