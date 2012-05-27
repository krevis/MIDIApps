/*
 Copyright (c) 2001-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SMMAppController.h"

#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SnoizeMIDI.h>
#import <SnoizeMIDISpy/SnoizeMIDISpy.h>

#import "SMMDocument.h"
#import "SMMPreferencesWindowController.h"


@interface SMMAppController (Private)

- (void)doNothing:(id)ignored;
- (void)sourceEndpointsAppeared:(NSNotification *)notification;
- (void)openWindowForNewSources;

@end


@implementation SMMAppController

NSString *SMMOpenWindowsForNewSourcesPreferenceKey = @"SMMOpenWindowsForNewSources";

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
{
    BOOL shouldUseMIDISpy;
    SInt32 spyStatus;
    NSString *midiSpyErrorMessage = nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didFinishRestoringWindows:)
                                                 name:@"NSApplicationDidFinishRestoringWindowsNotification" 
                                               object:NSApp];
    
    // Make sure we go multithreaded
	if (![NSThread isMultiThreaded]) {
		[NSThread detachNewThreadSelector: @selector(doNothing:) toTarget: self withObject: nil];
	}

    // Before CoreMIDI is initialized, make sure the spying driver is installed
    shouldUseMIDISpy = NO;
    spyStatus = MIDISpyInstallDriverIfNecessary();
    switch (spyStatus) {
        case kMIDISpyDriverAlreadyInstalled:
        case kMIDISpyDriverInstalledSuccessfully:
            shouldUseMIDISpy = YES;
            break;

        case kMIDISpyDriverCouldNotRemoveOldDriver:
            midiSpyErrorMessage = NSLocalizedStringFromTableInBundle(@"There is an old version of MIDI Monitor's driver installed, but it could not be removed. To fix this, remove the old driver. (It is probably \"Library/Audio/MIDI Drivers/MIDI Monitor.plugin\" in your home folder.)", @"MIDIMonitor", SMBundleForObject(self), "error message if old MIDI spy driver could not be removed");
            break;

        case kMIDISpyDriverInstallationFailed:
        default:
            midiSpyErrorMessage = NSLocalizedStringFromTableInBundle(@"MIDI Monitor tried to install a MIDI driver in \"Library/Audio/MIDI Drivers\" in your your home folder, but it failed. (Do the privileges allow write access?)", @"MIDIMonitor", SMBundleForObject(self), "error message if MIDI spy driver installation fails");
            break;
    }

    // Initialize CoreMIDI while the app's icon is still bouncing, so we don't have a large pause after it stops bouncing
    // but before the app's window opens.  (CoreMIDI needs to find and possibly start its server process, which can take a while.)
    if ([SMClient sharedClient] == nil) {
        NSString *title, *message, *quit;
        
        shouldOpenUntitledDocument = NO;

        title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", SMBundleForObject(self), "title of error alert");
        message = NSLocalizedStringFromTableInBundle(@"There was a problem initializing the MIDI system. To try to fix this, log out and log back in, or restart the computer.", @"MIDIMonitor", SMBundleForObject(self), "error message if MIDI initialization fails");
        quit = NSLocalizedStringFromTableInBundle(@"Quit", @"MIDIMonitor", SMBundleForObject(self), "title of quit button");

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
            midiSpyErrorMessage = NSLocalizedStringFromTableInBundle(@"MIDI Monitor could not make a connection to its MIDI driver. To fix the problem, quit all MIDI applications (including this one) and launch them again.", @"MIDIMonitor", SMBundleForObject(self), "error message if MIDI spy client creation fails");
        }
    }

    if (midiSpyErrorMessage) {
        NSString *title;
        NSString *message2;

        title = NSLocalizedStringFromTableInBundle(@"Warning", @"MIDIMonitor", SMBundleForObject(self), "title of warning alert");
        message2 = NSLocalizedStringFromTableInBundle(@"For now, MIDI Monitor will not be able to spy on the output of other MIDI applications, but all other features will still work.", @"MIDIMonitor", SMBundleForObject(self), "second line of warning when MIDI spy is unavailable");
        
        NSRunAlertPanel(title, @"%@\n\n%@", nil, nil, nil, midiSpyErrorMessage, message2);
    }    
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender;
{
    return shouldOpenUntitledDocument;
}

- (void)didFinishRestoringWindows:(NSNotification*)notification
{
    // We receive this notification on Lion (10.7) and later.
    // If AppKit has decided, for its own unknowable reasons, to not open an untitled document,
    // and it's appropriate to do so, do it ourself now.
    if ([self applicationShouldOpenUntitledFile:NSApp]) {
        NSDocumentController *dc = [NSDocumentController sharedDocumentController];
        if (dc.documents.count == 0)
            [dc openUntitledDocumentAndDisplay:YES error:NULL];
    }
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
    
    path = [SMBundleForObject(self) pathForResource:@"docs" ofType:@"htmld"];
    if (path) {
        path = [path stringByAppendingPathComponent:@"index.html"];
        if (![[NSWorkspace sharedWorkspace] openFile:path]) {
            message = NSLocalizedStringFromTableInBundle(@"The help file could not be opened.", @"MIDIMonitor", SMBundleForObject(self), "error message if opening the help file fails");
        }
    } else {
        message = NSLocalizedStringFromTableInBundle(@"The help file could not be found.", @"MIDIMonitor", SMBundleForObject(self), "error message if help file can't be found");
    }

    if (message) {
        NSString *title;

        title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", SMBundleForObject(self), "title of error alert");
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
    feedbackEmailSubject = NSLocalizedStringFromTableInBundle(@"MIDI Monitor Feedback", @"MIDIMonitor", SMBundleForObject(self), "subject of feedback email");    
    mailToURLString = [NSString stringWithFormat:@"mailto:%@?Subject=%@", feedbackEmailAddress, feedbackEmailSubject];
	mailToURLString = [(NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)mailToURLString, NULL, NULL, kCFStringEncodingUTF8) autorelease];
    mailToURL = [NSURL URLWithString:mailToURLString];
    if (mailToURL)
        success = [[NSWorkspace sharedWorkspace] openURL:mailToURL];

    if (!success) {
        NSString *message, *title;
        
        NSLog(@"Couldn't send feedback: url string was <%@>, url was <%@>", mailToURLString, mailToURL);

        title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", SMBundleForObject(self), "title of error alert");
        message = NSLocalizedStringFromTableInBundle(@"MIDI Monitor could not ask your email application to create a new message, so you will have to do it yourself. Please send your email to this address:\n%@\nThank you!", @"MIDIMonitor", SMBundleForObject(self), "message of alert when can't send feedback email");
        
        NSRunAlertPanel(title, message, nil, nil, nil, feedbackEmailAddress);
    }
}

- (IBAction)restartMIDI:(id)sender;
{
    OSStatus status = MIDIRestart();
    if (status) {
        // Something went wrong!
        NSString* message;
        NSString* title;        

        message = NSLocalizedStringFromTableInBundle(@"Rescanning the MIDI system resulted in an unexpected error (%d).", @"MIDIMonitor", SMBundleForObject(self), "error message if MIDIRestart() fails");
        title = NSLocalizedStringFromTableInBundle(@"MIDI Error", @"MIDIMonitor", SMBundleForObject(self), "title of MIDI error panel");

        NSRunAlertPanel(title, message, nil, nil, nil, status);        
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

- (void)doNothing:(id)ignored
{
	// do nothing, just a way to go multithreaded
}

- (void)sourceEndpointsAppeared:(NSNotification *)notification;
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SMMOpenWindowsForNewSourcesPreferenceKey])
    {
        NSArray *endpoints;

        endpoints = [[notification userInfo] objectForKey:SMMIDIObjectsThatAppeared];

        if (!newSources) {
            newSources = [[NSMutableSet alloc] init];
            [self performSelector:@selector(openWindowForNewSources) withObject: nil afterDelay:0.1 inModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
        }
        [newSources addObjectsFromArray:endpoints];
    }
}

- (void) openWindowForNewSources
{
    SMMDocument *document;

    document = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MIDI Monitor Document" display:NO];
    [document setSelectedInputSources:newSources];
    [document showWindows];
    [document setAreSourcesShown:YES];
    [document revealInputSources:newSources];

    [newSources release];
    newSources = nil;
}

@end
