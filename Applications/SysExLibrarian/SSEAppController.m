//
//  SSEAppController.m
//  MIDIMonitor
//
//  Created by krevis on Sun Apr 15 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import "SSEAppController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import "SSEMainWindowController.h"
#import "SSEPreferencesWindowController.h"


@implementation SSEAppController

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
{
    // Make sure we go multithreaded, and that our scheduler starts up
    [OFScheduler mainScheduler];

    [self showMainWindow:nil];
}

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
        path = [path stringByAppendingString:@"/index.html"];
        [[NSWorkspace sharedWorkspace] openFile:path];
    }
}

- (IBAction)showMainWindow:(id)sender;
{
    [[SSEMainWindowController mainWindowController] showWindow:nil];
}

@end
