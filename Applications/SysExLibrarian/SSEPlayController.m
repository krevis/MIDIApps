/*
 Copyright (c) 2002-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSEPlayController.h"

#import "SSEMainWindowController.h"
#import "SSEMIDIController.h"
#import "SSELibraryEntry.h"


@interface SSEPlayController (Private)

- (void)observeMIDIController;
- (void)stopObservingMIDIController;

- (void)sendWillStart:(NSNotification *)notification;
- (void)sendFinished:(NSNotification *)notification;
- (void)sendFinishedImmediately:(NSNotification *)notification;

- (void)updateProgressAndRepeat;
- (void)updateProgress;

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

- (void)setCurrentEntry:(SSELibraryEntry *)entry;
- (void)setQueuedEntry:(SSELibraryEntry *)entry;

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

    if (![[NSBundle mainBundle] loadNibNamed:@"Play" owner:self topLevelObjects:&topLevelObjects]) {
        [self release];
        return nil;
    }
    [topLevelObjects retain];
    
    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [topLevelObjects release];

    [currentEntry release];
    [queuedEntry release];
        
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
    // Otherwise, we expect a different notification so that -sendWillStart: will be called.
}

- (void)playMessagesInEntryForProgramChange:(SSELibraryEntry *)entry
{
	if (!transmitting) {
        // Normal case. Nothing is being transmitted, so just remember the current entry and play the messages in it.
		[self setCurrentEntry:entry];
        
		[self playMessages:[entry messages]];
    } else {
        // something is being transmitted already...
		if (currentEntry != entry) {
            // and the program change is asking to send a different entry than the one currently sending.
            // Queue up this entry to be sent later.
			[self setQueuedEntry:entry];
            
            // and maybe cancel the current send.
			if ([[NSUserDefaults standardUserDefaults] boolForKey:SSEInterruptOnProgramChangePreferenceKey]) {
				[nonretainedMIDIController cancelSendingMessages];
            }
		}
	}
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
    NSUInteger bytesToSend;

	transmitting = YES;
    [progressIndicator setMinValue:0.0];
    [progressIndicator setDoubleValue:0.0];
    [nonretainedMIDIController getMessageCount:NULL messageIndex:NULL bytesToSend:&bytesToSend bytesSent:NULL];
    [progressIndicator setMaxValue:bytesToSend];

    SMAssert(scheduledProgressUpdate == NO);

    [self updateProgressAndRepeat];

    if (![[nonretainedMainWindowController window] attachedSheet]) {
        [NSApp beginSheet:sheetWindow modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    }
}

- (void)sendFinished:(NSNotification *)notification;
{
    BOOL success;

    success = notification ? [[[notification userInfo] objectForKey:@"success"] boolValue] : YES;
    
    // If there is a delayed update pending, cancel it and do the update now.
    if (scheduledProgressUpdate) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateProgressAndRepeat) object:nil];
        scheduledProgressUpdate = NO;
        [self updateProgress];
    }

    if (!success)
        [progressMessageField setStringValue:NSLocalizedStringFromTableInBundle(@"Cancelled.", @"SysExLibrarian", SMBundleForObject(self), "Cancelled.")];
	
    [self stopObservingMIDIController];	

	transmitting = NO;

    // Maybe there's a queued entry that needs sending...
	if (queuedEntry != nil && currentEntry != queuedEntry) {
        // yes, move the queued entry to be current
		[self setCurrentEntry:queuedEntry];
        [self setQueuedEntry:nil];

        // then send it
		[self performSelector:@selector(playMessages:) withObject:[currentEntry messages] afterDelay:0.0];

	} else {
		[self setCurrentEntry:nil];
        [self setQueuedEntry:nil];

		// Even if we have set the progress indicator to its maximum value, it won't get drawn on the screen that way immediately,
		// probably because it tries to smoothly animate to that state. The only way I have found to show the maximum value is to just
		// wait a little while for the animation to finish. This looks nice, too.
		[NSApp performSelector:@selector(endSheet:) withObject:sheetWindow afterDelay:0.5];
	}
}

- (void)sendFinishedImmediately:(NSNotification *)notification;
{
    SMAssert(scheduledProgressUpdate == NO);
    
    // Pop up the sheet and immediately dismiss it, so the user knows that something happehed.    
    [self sendWillStart:nil];
    [self sendFinished:nil];
}

- (void)updateProgressAndRepeat;
{
    [self updateProgress];

    [self performSelector:@selector(updateProgressAndRepeat) withObject: nil afterDelay:5.0/60.0];
    scheduledProgressUpdate = YES;
}

- (void)updateProgress;
{
    static NSString *sendingFormatString = nil;
    static NSString *sendingString = nil;
    static NSString *doneString = nil;
    NSUInteger messageIndex, messageCount, bytesToSend, bytesSent;
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

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
    // We don't really care how this sheet ended
    [sheet orderOut:nil];
}

- (void)setCurrentEntry:(SSELibraryEntry *)entry
{
    if (entry != currentEntry) {
        [currentEntry release];
        currentEntry = [entry retain];
        
        if (currentEntry) {
            [nonretainedMainWindowController selectEntries:[NSArray arrayWithObject:currentEntry]];
        }
    }    
}

- (void)setQueuedEntry:(SSELibraryEntry *)entry
{
    if (entry != queuedEntry) {
        [queuedEntry release];
        queuedEntry = [entry retain];
    }
}

@end
