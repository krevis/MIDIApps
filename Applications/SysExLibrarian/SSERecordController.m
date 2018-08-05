/*
 Copyright (c) 2002-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSERecordController.h"

#import "SSEMainWindowController.h"
#import "SSEMIDIController.h"


@interface SSERecordController (Private)

- (void)readStatusChanged:(NSNotification *)notification;

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


@implementation SSERecordController

- (id)initWithMainWindowController:(SSEMainWindowController *)mainWindowController midiController:(SSEMIDIController *)midiController;
{
    if (!(self = [super init]))
        return nil;

    nonretainedMainWindowController = mainWindowController;
    nonretainedMIDIController = midiController;

    if (![[NSBundle mainBundle] loadNibNamed:[self nibName] owner:self topLevelObjects:&topLevelObjects]) {
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

    [super dealloc];
}

//
// API for main window controller
//

- (void)beginRecording;
{
    [progressIndicator startAnimation:nil];

    [self updateIndicatorsWithMessageCount:0 bytesRead:0 totalBytesRead:0];

    [NSApp beginSheet:sheetWindow modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];

    [self observeMIDIController];

    [self tellMIDIControllerToStartRecording];
}

//
// Actions
//

- (IBAction)cancelRecording:(id)sender;
{
    [nonretainedMIDIController cancelMessageListen];
    [self stopObservingMIDIController];

    [progressIndicator stopAnimation:nil];

    [NSApp endSheet:sheetWindow];
}

//
// To be implemented in subclasses
//

- (NSString *)nibName;
{
    SMRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void)tellMIDIControllerToStartRecording;
{
    SMRequestConcreteImplementation(self, _cmd);
}

- (void)updateIndicatorsWithMessageCount:(NSUInteger)messageCount bytesRead:(NSUInteger)bytesRead totalBytesRead:(NSUInteger)totalBytesRead;
{
    SMRequestConcreteImplementation(self, _cmd);
}

//
// May be overridden by subclasses
//

- (void)observeMIDIController;
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readStatusChanged:) name:SSEMIDIControllerReadStatusChangedNotification object:nonretainedMIDIController];
}

- (void)stopObservingMIDIController;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SSEMIDIControllerReadStatusChangedNotification object:nonretainedMIDIController];
}

//
// To be used by subclasses
//

- (NSString *)waitingForSysexMessage;
{
    static NSString *waitingForSysexString = nil;

    if (!waitingForSysexString)
        waitingForSysexString = [NSLocalizedStringFromTableInBundle(@"Waiting for SysEx message...", @"SysExLibrarian", SMBundleForObject(self), "message when waiting for sysex") retain];

    return waitingForSysexString;    
}

- (NSString *)receivingSysexMessage;
{
    static NSString *receivingSysexString = nil;

    if (!receivingSysexString)
        receivingSysexString = [NSLocalizedStringFromTableInBundle(@"Receiving SysEx message...", @"SysExLibrarian", SMBundleForObject(self), "message when receiving sysex") retain];
    
    return receivingSysexString;
}

- (void)updateIndicators;
{
    NSUInteger messageCount, bytesRead, totalBytesRead;
    
    [nonretainedMIDIController getMessageCount:&messageCount bytesRead:&bytesRead totalBytesRead:&totalBytesRead];
    
    [self updateIndicatorsWithMessageCount:messageCount bytesRead:bytesRead totalBytesRead:totalBytesRead];
    
    scheduledProgressUpdate = NO;
}

@end


@implementation SSERecordController (Private)

- (void)readStatusChanged:(NSNotification *)notification;
{
    if (!scheduledProgressUpdate) {
        [self performSelector:@selector(updateIndicators) withObject:self afterDelay:5.0/60.0];
        scheduledProgressUpdate = YES;
    }
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    // We don't really care how this sheet ended
    [sheet orderOut:nil];
}

@end
