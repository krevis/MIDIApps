/*
 Copyright (c) 2001-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SMMAppController.h"

#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SnoizeMIDI.h>
#import <Sparkle/Sparkle.h>

#import "SMMDocument.h"
#import "SMMMonitorWindowController.h"
#import "SMMPreferencesWindowController.h"

NSString* const SMMOpenWindowsForNewSourcesPreferenceKey = @"SMMOpenWindowsForNewSources";  // Obsolete
NSString* const SMMAutoConnectNewSourcesPreferenceKey = @"SMMAutoConnectNewSources";

typedef enum {
    SMMAutoConnectOptionDisabled            = 0,
    SMMAutoConnectOptionAddInCurrentWindow  = 1,
    SMMAutoConnectOptionOpenNewWindow       = 2,
} SMMAutoConnectOption;


@interface SMMAppController () <SUUpdaterDelegate>

@property (nonatomic, assign) BOOL shouldOpenUntitledDocument;
@property (nonatomic, retain) NSMutableSet *newlyAppearedSources;

@end

@implementation SMMAppController

- (void)awakeFromNib
{
    // Migrate autoconnect preference, before we show any windows.
    // Old: SMMOpenWindowsForNewSourcesPreferenceKey = BOOL (default: false)
    // New: SMMAutoConnectNewSourcesPreferenceKey = int (SMMAutoConnectOption, default: 1 = SMMAutoConnectOptionAddInCurrentWindow)

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:SMMOpenWindowsForNewSourcesPreferenceKey] != nil) {
        SMMAutoConnectOption option = [defaults boolForKey:SMMOpenWindowsForNewSourcesPreferenceKey] ? SMMAutoConnectOptionOpenNewWindow : SMMAutoConnectOptionDisabled;
        [defaults setInteger:option forKey:SMMAutoConnectNewSourcesPreferenceKey];
        [defaults removeObjectForKey:SMMOpenWindowsForNewSourcesPreferenceKey];
    }
}

- (void)dealloc
{
    // Appease the analyzer
    [_newlyAppearedSources release];
    [super dealloc];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    // Before CoreMIDI is initialized, make sure the spying driver is installed
    NSError* installError = MIDISpyInstallDriverIfNecessary();

    // Initialize CoreMIDI while the app's icon is still bouncing, so we don't have a large pause after it stops bouncing
    // but before the app's window opens.  (CoreMIDI needs to find and possibly start its server process, which can take a while.)
    if ([SMClient sharedClient] == nil) {
        [self failedToInitCoreMIDI];
        return;
    }

    // After this point, we are OK to open documents (untitled or otherwise)
    self.shouldOpenUntitledDocument = YES;

    if (installError) {
        [self failedToInstallSpyDriverWithError:installError];
    }
    else {
        // Create our client for spying on MIDI output.
        OSStatus status = MIDISpyClientCreate(&_midiSpyClient);
        if (status != noErr) {
            [self failedToConnectToSpyClient];
        }
    }
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return self.shouldOpenUntitledDocument;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    // Listen for new source endpoints. Don't do this earlier--we only are interested in ones
    // that appear after we've been launched.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sourceEndpointsAppeared:) name:SMMIDIObjectsAppearedNotification object:[SMSourceEndpoint class]];
}

- (IBAction)showPreferences:(id)sender
{
    [[SMMPreferencesWindowController preferencesWindowController] showWindow:nil];
}

- (IBAction)showAboutBox:(id)sender
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

- (IBAction)showHelp:(id)sender
{
    NSString *message = nil;
    
    NSString *path = [SMBundleForObject(self) pathForResource:@"docs" ofType:@"htmld"];
    if (path) {
        path = [path stringByAppendingPathComponent:@"index.html"];
        if (![[NSWorkspace sharedWorkspace] openFile:path]) {
            message = NSLocalizedStringFromTableInBundle(@"The help file could not be opened.", @"MIDIMonitor", SMBundleForObject(self), "error message if opening the help file fails");
        }
    } else {
        message = NSLocalizedStringFromTableInBundle(@"The help file could not be found.", @"MIDIMonitor", SMBundleForObject(self), "error message if help file can't be found");
    }

    if (message) {
        NSString *title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", SMBundleForObject(self), "title of error alert");
        NSRunAlertPanel(title, @"%@", nil, nil, nil, message);
    }
}

- (IBAction)sendFeedback:(id)sender
{
    BOOL success = NO;

    NSString *feedbackEmailAddress = @"MIDIMonitor@snoize.com";	// Don't localize this
    NSString *feedbackEmailSubject = NSLocalizedStringFromTableInBundle(@"MIDI Monitor Feedback", @"MIDIMonitor", SMBundleForObject(self), "subject of feedback email");
    NSString *mailToURLString = [NSString stringWithFormat:@"mailto:%@?Subject=%@", feedbackEmailAddress, feedbackEmailSubject];
	mailToURLString = [(NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)mailToURLString, NULL, NULL, kCFStringEncodingUTF8) autorelease];
    NSURL *mailToURL = [NSURL URLWithString:mailToURLString];
    if (mailToURL) {
        success = [[NSWorkspace sharedWorkspace] openURL:mailToURL];
    }

    if (!success) {
        NSLog(@"Couldn't send feedback: url string was <%@>, url was <%@>", mailToURLString, mailToURL);

        NSString *title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", SMBundleForObject(self), "title of error alert");
        NSString *message = NSLocalizedStringFromTableInBundle(@"MIDI Monitor could not ask your email application to create a new message, so you will have to do it yourself. Please send your email to this address:\n%@\nThank you!", @"MIDIMonitor", SMBundleForObject(self), "message of alert when can't send feedback email");
        
        NSRunAlertPanel(title, message, nil, nil, nil, feedbackEmailAddress);
    }
}

- (IBAction)restartMIDI:(id)sender
{
    OSStatus status = MIDIRestart();
    if (status) {
        // Something went wrong!
        NSString *message = NSLocalizedStringFromTableInBundle(@"Rescanning the MIDI system resulted in an unexpected error (%d).", @"MIDIMonitor", SMBundleForObject(self), "error message if MIDIRestart() fails");
        NSString *title = NSLocalizedStringFromTableInBundle(@"MIDI Error", @"MIDIMonitor", SMBundleForObject(self), "title of MIDI error panel");

        NSRunAlertPanel(title, message, nil, nil, nil, status);        
    }
}

#pragma mark SUUpdaterDelegate

- (BOOL)updater:(SUUpdater *)updater shouldPostponeRelaunchForUpdate:(SUAppcastItem *)item untilInvoking:(NSInvocation *)invocation
{
    // The update might contain a MIDI driver that needs to get
    // installed. In order for it to work immediately,
    // we want the MIDIServer to shut down now, so we can install
    // the driver and then trigger the MIDIServer to run again.

    // Remove our connections to the MIDIServer first:
    [SMClient disposeSharedClient];
    MIDISpyClientDispose(_midiSpyClient);
    MIDISpyClientDisposeSharedMIDIClient();

    // Wait a few seconds for the MIDIServer to hopefully shut down,
    // then relaunch for the update:
    [invocation retain];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [invocation invoke];
        [invocation release];
    });

    return YES;
}

#pragma mark Private

// Various launch failure paths

- (void)failedToInitCoreMIDI
{
    NSBundle *bundle = SMBundleForObject(self);
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.messageText = NSLocalizedStringFromTableInBundle(@"The MIDI system could not be started.", @"MIDIMonitor", bundle, "error message if MIDI initialization fails");
    alert.informativeText = NSLocalizedStringFromTableInBundle(@"This probably affects all apps that use MIDI, not just MIDI Monitor.\n\nMost likely, the cause is a bad MIDI driver. Remove any MIDI drivers that you don't recognize, then try again.", @"MIDIMonitor", bundle, "informative text if MIDI initialization fails");
    [alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Quit", @"MIDIMonitor", bundle, "title of quit button")];
    [alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Show MIDI Drivers",  @"MIDIMonitor", bundle, "Show MIDI Drivers button after MIDI spy client creation fails")];

    if ([alert runModal] == NSAlertSecondButtonReturn) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:@"/Library/Audio/MIDI Drivers"]];
    }

    [alert release];
    [NSApp terminate:nil];
}

- (void)failedToInstallSpyDriverWithError:(NSError *)installError
{
    // Failure to install. Customize the error before presenting it.

    NSBundle *bundle = SMBundleForObject(self);

    NSMutableDictionary *presentedErrorUserInfo = [[installError userInfo] mutableCopy];
    presentedErrorUserInfo[NSLocalizedDescriptionKey] = NSLocalizedStringFromTableInBundle(@"MIDI Monitor could not install its driver.", @"MIDIMonitor", bundle, "error message if spy driver install fails");

    if (installError.domain == MIDISpyDriverInstallationErrorDomain) {
        // Errors with this domain should be very rare and indicate a problem with the app itself.

        NSMutableString *fullSuggestion = [NSMutableString string];
        NSString *reason = [installError localizedFailureReason];
        if (reason && ![@"" isEqualToString:reason]) {
            [fullSuggestion appendString:reason];
            [fullSuggestion appendString:@"\n\n"];
            [fullSuggestion appendString:NSLocalizedStringFromTableInBundle(@"This shouldn't happen. Try downloading MIDI Monitor again.", @"MIDIMonitor", bundle, "suggestion if spy driver install fails due to our own error")];
            [fullSuggestion appendString:@"\n\n"];
            [fullSuggestion appendString:NSLocalizedStringFromTableInBundle(@"MIDI Monitor will not be able to see the output of other MIDI applications, but all other features will still work.", @"MIDIMonitor", bundle, "more suggestion if spy driver install fails")];
        }

        if (![@"" isEqualToString:fullSuggestion]) {
            presentedErrorUserInfo[NSLocalizedRecoverySuggestionErrorKey] = fullSuggestion;
        }
    }
    else {
        NSMutableString *fullSuggestion = [NSMutableString string];
        NSString *reason = [installError localizedDescription];
        if (reason && ![@"" isEqualToString:reason]) {
            [fullSuggestion appendString:reason];
        }

        NSString *suggestion = [installError localizedRecoverySuggestion];
        if (suggestion && ![@"" isEqualToString:suggestion]) {
            if (![@"" isEqualToString:fullSuggestion]) {
                [fullSuggestion appendString:@"\n\n"];
            }
            [fullSuggestion appendString:suggestion];
        }

        if (![@"" isEqualToString:fullSuggestion]) {
            [fullSuggestion appendString:@"\n\n"];
            [fullSuggestion appendString:NSLocalizedStringFromTableInBundle(@"MIDI Monitor will not be able to see the output of other MIDI applications, but all other features will still work.", @"MIDIMonitor", bundle, "more suggestion if spy driver install fails")];
            presentedErrorUserInfo[NSLocalizedRecoverySuggestionErrorKey] = fullSuggestion;
        }

        // To find the path involved, look for NSDestinationFilePath first (it's set for failures to copy, and is better than the source path),
        // then fall back to the documented keys.
        NSString *filePath = installError.userInfo[@"NSDestinationFilePath"];
        if (!filePath) {
            filePath = installError.userInfo[NSFilePathErrorKey];
        }
        if (!filePath) {
            NSURL *url = installError.userInfo[NSURLErrorKey];
            if (url && [url isFileURL]) {
                filePath = [url path];
            }
        }

        if (filePath && ![@"" isEqualToString:filePath]) {
            presentedErrorUserInfo[NSFilePathErrorKey] = filePath;
            presentedErrorUserInfo[NSLocalizedRecoveryOptionsErrorKey] = @[
                NSLocalizedStringFromTableInBundle(@"Continue", @"MIDIMonitor", bundle, "Continue button if spy driver install fails"),
                NSLocalizedStringFromTableInBundle(@"Show in Finder", @"MIDIMonitor", bundle, "Show in Finder button if spy driver install fails"),
            ];
            presentedErrorUserInfo[NSRecoveryAttempterErrorKey] = self;
        }
    }

    NSError *presentedError = [NSError errorWithDomain:installError.domain code:installError.code userInfo:presentedErrorUserInfo];
    [presentedErrorUserInfo release];
    [NSApp presentError:presentedError];
}

// NSErrorRecoveryAttempting
- (BOOL)attemptRecoveryFromError:(NSError *)error optionIndex:(NSUInteger)recoveryOptionIndex
{
    if (recoveryOptionIndex == 0) {
        // Continue: do nothing
    }
    else if (recoveryOptionIndex == 1) {
        NSString *filePath = error.userInfo[NSFilePathErrorKey];
        [[NSWorkspace sharedWorkspace] selectFile:filePath inFileViewerRootedAtPath:@""];
    }

    return YES; // recovery was successful
}

- (void)failedToConnectToSpyClient
{
    NSBundle *bundle = SMBundleForObject(self);
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedStringFromTableInBundle(@"MIDI Monitor could not make a connection to its MIDI driver.", @"MIDIMonitor", bundle, "error message if MIDI spy client creation fails");
    alert.informativeText = NSLocalizedStringFromTableInBundle(@"If you continue, MIDI Monitor will not be able to see the output of other MIDI applications, but all other features will still work.\n\nTo fix the problem:\n1. Remove any old 32-bit-only drivers from /Library/Audio/MIDI Drivers.\n2. Restart your computer.", @"MIDIMonitor", bundle, "second line of warning when MIDI spy is unavailable");
    [alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Continue", @"MIDIMonitor", bundle, "Continue button after MIDI spy client creation fails")];
    [alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Restart",  @"MIDIMonitor", bundle, "Restart button after MIDI spy client creation fails")];
    [alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Show MIDI Drivers",  @"MIDIMonitor", bundle, "Show MIDI Drivers button after MIDI spy client creation fails")];

    NSModalResponse response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) { // Restart
        NSAlert *ynAlert = [[NSAlert alloc] init];
        ynAlert.messageText = NSLocalizedStringFromTableInBundle(@"Are you sure you want to restart now?", @"MIDIMonitor", bundle, "Restart y/n?");
        [ynAlert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Restart", @"MIDIMonitor", bundle, "Restart button title")];
        [ynAlert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", @"MIDIMonitor", bundle, "Cancel button title")];
        if ([ynAlert runModal] == NSAlertFirstButtonReturn) {
            NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:@"tell application \"Finder\" to restart"];
            [appleScript executeAndReturnError:NULL];
            [appleScript release];
        }
        [ynAlert release];
    }
    else if (response == NSAlertThirdButtonReturn) { // Show MIDI Drivers
        [[NSWorkspace sharedWorkspace] selectFile:@"/Library/Audio/MIDI Drivers" inFileViewerRootedAtPath:@""];
    }

    [alert release];
}

- (void)sourceEndpointsAppeared:(NSNotification *)notification
{
    NSArray *endpoints = [[notification userInfo] objectForKey:SMMIDIObjectsThatAppeared];
    if ([endpoints count] > 0) {
        SMMAutoConnectOption autoConnectOption = (SMMAutoConnectOption)[[NSUserDefaults standardUserDefaults] integerForKey:SMMAutoConnectNewSourcesPreferenceKey];

        if (!self.newlyAppearedSources) {
            self.newlyAppearedSources = [NSMutableSet set];

            if (autoConnectOption == SMMAutoConnectOptionAddInCurrentWindow) {
                [self performSelector:@selector(autoConnectToNewlyAppearedSources) withObject:nil afterDelay:0.1];
            }
            else if (autoConnectOption == SMMAutoConnectOptionOpenNewWindow) {
                [self performSelector:@selector(openWindowForNewlyAppearedSources) withObject:nil afterDelay:0.1];
            }
        }

        [self.newlyAppearedSources addObjectsFromArray:endpoints];
    }
}

- (void)openWindowForNewlyAppearedSources
{
    NSDocumentController *dc = [NSDocumentController sharedDocumentController];
    SMMDocument *document = [dc openUntitledDocumentAndDisplay:NO error:NULL];
    [document makeWindowControllers];
    [document setSelectedInputSources:self.newlyAppearedSources];
    [document showWindows];

    SMMMonitorWindowController *wc = document.windowControllers.firstObject;
    [wc revealInputSources:self.newlyAppearedSources];
    [document updateChangeCount:NSChangeCleared];

    self.newlyAppearedSources = nil;
}

- (void)autoConnectToNewlyAppearedSources
{
    NSDocumentController *dc = [NSDocumentController sharedDocumentController];
    SMMDocument *document = [dc currentDocument] ?: [[[NSApplication sharedApplication] orderedDocuments] firstObject];
    if (document) {
        [document setSelectedInputSources:[self.newlyAppearedSources setByAddingObjectsFromSet:[document selectedInputSources]]];

        SMMMonitorWindowController *wc = document.windowControllers.firstObject;
        [wc revealInputSources:self.newlyAppearedSources];
        [document updateChangeCount:NSChangeCleared];
    }

    self.newlyAppearedSources = nil;
}

@end
