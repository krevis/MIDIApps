#import "SSEPlayController.h"

#import "SSEMainWindowController.h"
#import "SSEMIDIController.h"


@interface SSEPlayController (Private)

- (void)observeMIDIController;
- (void)stopObservingMIDIController;

- (void)sendWillStart:(NSNotification *)notification;
- (void)sendFinished:(NSNotification *)notification;
- (void)sendFinishedImmediately:(NSNotification *)notification;

- (void)updateProgressAndRepeat;
- (void)updateProgress;

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


@implementation SSEPlayController

- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController midiController:(SSEMIDIController *)midiController;
{
    if (!(self = [super init]))
        return nil;

    SMAssert(mainWindowController != nil);
    SMAssert(midiController != nil);

    nonretainedMainWindowController = mainWindowController;
    nonretainedMIDIController = midiController;

    if (![NSBundle loadNibNamed:@"Play" owner:self]) {
        [self release];
        return nil;
    }
    
    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Top-level nib objects
    [sheetWindow release];
    sheetWindow = nil;
        
    [super dealloc];
}

//
// API for main window controller
//

- (void)playMessages:(NSArray *)messages;
{    
    [self observeMIDIController];

    [nonretainedMIDIController setMessages:messages];
    [nonretainedMIDIController sendMessages];
    // This may send the messages immediately; if it does, it will post a notification and our -sendFinishedImmediately: will be called.
    // Otherwise, we expect a notifications so that -sendWillStart: will be called.
}

//
// Actions
//

- (IBAction)cancelPlaying:(id)sender;
{
    [nonretainedMIDIController cancelSendingMessages];
    // SSEMIDIControllerSendFinishedNotification will get sent soon; it will call our -sendFinished: and thus end the sheet
}

@end


@implementation SSEPlayController (Private)

- (void)observeMIDIController;
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendWillStart:) name:SSEMIDIControllerSendWillStartNotification object:nonretainedMIDIController];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendFinished:) name:SSEMIDIControllerSendFinishedNotification object:nonretainedMIDIController];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendFinishedImmediately:) name:SSEMIDIControllerSendFinishedImmediatelyNotification object:nonretainedMIDIController];
}

- (void)stopObservingMIDIController;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SSEMIDIControllerSendWillStartNotification object:nonretainedMIDIController];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SSEMIDIControllerSendFinishedNotification object:nonretainedMIDIController];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SSEMIDIControllerSendFinishedImmediatelyNotification object:nonretainedMIDIController];
}

- (void)sendWillStart:(NSNotification *)notification;
{
    unsigned int bytesToSend;

    [progressIndicator setMinValue:0.0];
    [progressIndicator setDoubleValue:0.0];
    [nonretainedMIDIController getMessageCount:NULL messageIndex:NULL bytesToSend:&bytesToSend bytesSent:NULL];
    [progressIndicator setMaxValue:bytesToSend];

    SMAssert(scheduledProgressUpdate == NO);

    [self updateProgressAndRepeat];

    [NSApp beginSheet:sheetWindow modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)sendFinished:(NSNotification *)notification;
{
    BOOL success;

    success = [[[notification userInfo] objectForKey:@"success"] boolValue];
    
    // If there is a delayed update pending, cancel it and do the update now.
    if (scheduledProgressUpdate) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateProgressAndRepeat) object:nil];
        scheduledProgressUpdate = NO;
        [self updateProgress];
    }

    if (!success)
        [progressMessageField setStringValue:NSLocalizedStringFromTableInBundle(@"Cancelled.", @"SysExLibrarian", SMBundleForObject(self), "Cancelled.")];

    // Even if we have set the progress indicator to its maximum value, it won't get drawn on the screen that way immediately,
    // probably because it tries to smoothly animate to that state. The only way I have found to show the maximum value is to just
    // wait a little while for the animation to finish. This looks nice, too.
    [NSApp performSelector:@selector(endSheet:) withObject:sheetWindow afterDelay:0.5];

    [self stopObservingMIDIController];
}

- (void)sendFinishedImmediately:(NSNotification *)notification;
{
    SMAssert(scheduledProgressUpdate == NO);
    
    [self stopObservingMIDIController];    
}

- (void)updateProgressAndRepeat;
{
    [self updateProgress];

    [self performSelector:@selector(updateProgressAndRepeat) withObject: nil afterDelay:[progressIndicator animationDelay]];
    scheduledProgressUpdate = YES;
}

- (void)updateProgress;
{
    static NSString *sendingFormatString = nil;
    static NSString *sendingString = nil;
    static NSString *doneString = nil;
    unsigned int messageIndex, messageCount, bytesToSend, bytesSent;
    NSString *message;

    if (!sendingFormatString)
        sendingFormatString = [NSLocalizedStringFromTableInBundle(@"Sending message %u of %u...", @"SysExLibrarian", SMBundleForObject(self), "format for progress message when sending multiple sysex messages") retain];
    if (!sendingString)
        sendingString = [NSLocalizedStringFromTableInBundle(@"Sending message...", @"SysExLibrarian", SMBundleForObject(self), "progress message when sending one sysex message") retain];
    if (!doneString)
        doneString = [NSLocalizedStringFromTableInBundle(@"Done.", @"SysExLibrarian", SMBundleForObject(self), "Done.") retain];    
    
    [nonretainedMIDIController getMessageCount:&messageCount messageIndex:&messageIndex bytesToSend:&bytesToSend bytesSent:&bytesSent];

    SMAssert(bytesSent >= [progressIndicator doubleValue]);
    // Make sure we don't go backwards somehow

    [progressIndicator setDoubleValue:bytesSent];
    [progressBytesField setStringValue:[NSString SnoizeMIDI_abbreviatedStringForByteCount:bytesSent]];
    if (bytesSent < bytesToSend) {
        if (messageCount > 1)
            message = [NSString stringWithFormat:sendingFormatString, messageIndex+1, messageCount];
        else
            message = sendingString;
    } else {
        message = doneString;
    }
    [progressMessageField setStringValue:message];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    // We don't really care how this sheet ended
    [sheet orderOut:nil];
}

@end
