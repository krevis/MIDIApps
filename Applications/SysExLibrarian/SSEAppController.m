/*
 Copyright (c) 2002-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSEAppController.h"

@import SnoizeMIDI;

#import "SysEx_Librarian-Swift.h"
#import "SSEMainWindowController.h"
#import "SSELibrary.h"


@interface SSEAppController (Private)

- (void)importFiles;

@end


@implementation SSEAppController

static NSThread *sMainThread = nil;

@synthesize midiContext = midiContext;

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    hasFinishedLaunching = NO;

    if (!sMainThread) {
        // Assume that the current thread is the main thread
        sMainThread = [NSThread currentThread];
    }
    
    return self;
}

//
// Application delegate
//

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
{    
    // Initialize CoreMIDI while the app's icon is still bouncing, so we don't have a large pause after it stops bouncing
    // but before the app's window opens.  (CoreMIDI needs to find and possibly start its server process, which can take a while.)
    midiContext = [[MIDIContext alloc] init];
    if (!midiContext.connectedToCoreMIDI) {
        NSString *title, *message, *quit;

        title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", SMBundleForObject(self), "title of error alert");
        message = NSLocalizedStringFromTableInBundle(@"There was a problem initializing the MIDI system. To try to fix this, log out and log back in, or restart the computer.", @"SysExLibrarian", SMBundleForObject(self), "error message if MIDI initialization fails");
        quit = NSLocalizedStringFromTableInBundle(@"Quit", @"SysExLibrarian", SMBundleForObject(self), "title of quit button");

        NSRunCriticalAlertPanel(title, @"%@", quit, nil, nil, message);
        [NSApp terminate:nil];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
{
    hasFinishedLaunching = YES;

    NSString *preflightError = [[SSELibrary sharedLibrary] preflightAndLoadEntries];
    if (preflightError) {
        NSString *title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", SMBundleForObject(self), "title of error alert");
        NSString *quit = NSLocalizedStringFromTableInBundle(@"Quit", @"SysExLibrarian", SMBundleForObject(self), "title of quit button");

        NSRunCriticalAlertPanel(title, @"%@", quit, nil, nil, preflightError);
        [NSApp terminate:nil];
    } else {
        [self showMainWindow:nil];

        if (filesToImport) {
            [self importFiles];
        }
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
    [[PreferencesWindowController sharedInstance] showWindow:nil];
}

- (IBAction)showAboutBox:(id)sender;
{
    NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
    options[@"Version"] = @"";

    // The RTF file Credits.rtf has foreground text color = black, but that's wrong for 10.14 dark mode.
    // Similarly the font is not necessarily the systme font. Override both.
    if (@available(macOS 10.13, *)) {
        NSURL *creditsURL = [[NSBundle mainBundle] URLForResource:@"Credits" withExtension:@"rtf"];
        if (creditsURL) {
            NSMutableAttributedString *credits = [[NSMutableAttributedString alloc] initWithURL:creditsURL documentAttributes:NULL];
            NSRange range = NSMakeRange(0, credits.length);
            [credits addAttribute:NSFontAttributeName value:[NSFont labelFontOfSize:[NSFont labelFontSize]] range:range];
            if (@available(macOS 10.14, *)) {
                [credits addAttribute:NSForegroundColorAttributeName value:[NSColor labelColor] range:range];
            }
            options[NSAboutPanelOptionCredits] = credits;
            [credits release];
        }
    }

    [NSApp orderFrontStandardAboutPanelWithOptions:options];

    [options release];
}

- (IBAction)showHelp:(id)sender;
{
    NSString *path;
    NSString *message = nil;

    path = [SMBundleForObject(self) pathForResource:@"docs" ofType:@"htmld"];
    if (path) {
        path = [path stringByAppendingPathComponent:@"index.html"];
        if (![[NSWorkspace sharedWorkspace] openFile:path]) {
            message = NSLocalizedStringFromTableInBundle(@"The help file could not be opened.", @"SysExLibrarian", SMBundleForObject(self), "error message if opening the help file fails");
        }
    } else {
        message = NSLocalizedStringFromTableInBundle(@"The help file could not be found.", @"SysExLibrarian", SMBundleForObject(self), "error message if help file can't be found");
    }

    if (message) {
        NSString *title;

        title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", SMBundleForObject(self), "title of error alert");
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
    feedbackEmailSubject = NSLocalizedStringFromTableInBundle(@"SysEx Librarian Feedback", @"SysExLibrarian", SMBundleForObject(self), "subject of feedback email");
    mailToURLString = [NSString stringWithFormat:@"mailto:%@?Subject=%@", feedbackEmailAddress, feedbackEmailSubject];
	mailToURLString = [(NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)mailToURLString, NULL, NULL, kCFStringEncodingUTF8) autorelease];
    mailToURL = [NSURL URLWithString:mailToURLString];
    if (mailToURL)
        success = [[NSWorkspace sharedWorkspace] openURL:mailToURL];    
    
    if (!success) {
        NSString *message, *title;

        NSLog(@"Couldn't send feedback: url string was <%@>, url was <%@>", mailToURLString, mailToURL);

        title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", SMBundleForObject(self), "title of error alert");
        message = NSLocalizedStringFromTableInBundle(@"SysEx Librarian could not ask your email application to create a new message, so you will have to do it yourself. Please send your email to this address:\n%@\nThank you!", @"SysExLibrarian", SMBundleForObject(self), "message of alert when can't send feedback email");

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

- (BOOL)inMainThread
{
    return ([NSThread currentThread] == sMainThread);
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
