/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSERecordOneController.h"

#import "SSEMainWindowController.h"
#import "SSEMIDIController.h"


@interface SSERecordOneController (Private)

- (void)readFinished:(NSNotification *)notification;

@end


@implementation SSERecordOneController

//
// SSERecordController subclass
//

- (NSString *)nibName;
{
    return @"RecordOne";
}

- (void)tellMIDIControllerToStartRecording;
{
    [nonretainedMIDIController listenForOneMessage];    
}

- (void)updateIndicatorsWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;
{
    if ((bytesRead == 0 && messageCount == 0)) {
        [progressMessageField setStringValue:[self waitingForSysexMessage]];
        [progressBytesField setStringValue:@""];
    } else {
        [progressMessageField setStringValue:[self receivingSysexMessage]];
        [progressBytesField setStringValue:[NSString SnoizeMIDI_abbreviatedStringForByteCount:bytesRead + totalBytesRead]];
    }
}

- (void)observeMIDIController;
{
    [super observeMIDIController];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readFinished:) name:SSEMIDIControllerReadFinishedNotification object:nonretainedMIDIController];
}

- (void)stopObservingMIDIController;
{
    [super stopObservingMIDIController];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:SSEMIDIControllerReadFinishedNotification object:nonretainedMIDIController];
}

@end


@implementation SSERecordOneController (Private)

- (void)readFinished:(NSNotification *)notification;
{
    // If there is an update pending, cancel it and do it now.
    if (scheduledProgressUpdate) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateIndicators) object:nil];
        scheduledProgressUpdate = NO;
        [self updateIndicators];
    }

    [progressIndicator stopAnimation:nil];

    // Close the sheet, after a little bit of a delay (makes it look nicer)
    [NSApp performSelector:@selector(endSheet:) withObject:sheetWindow afterDelay:0.5];

    [self stopObservingMIDIController];

    [nonretainedMainWindowController addReadMessagesToLibrary];
}

@end
