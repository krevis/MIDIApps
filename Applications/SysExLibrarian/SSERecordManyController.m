/*
 Copyright (c) 2002-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSERecordManyController.h"

#import "SSEMainWindowController.h"
#import "SSEMIDIController.h"


@implementation SSERecordManyController

//
// SSERecordController subclass
//

- (NSString *)nibName;
{
    return @"RecordMany";
}

- (void)tellMIDIControllerToStartRecording;
{
    [nonretainedMIDIController listenForMultipleMessages];
}

- (void)updateIndicatorsWithMessageCount:(NSUInteger)messageCount bytesRead:(NSUInteger)bytesRead totalBytesRead:(NSUInteger)totalBytesRead;
{
    static NSString *totalProgressFormatString = nil;
    static NSString *totalProgressPluralFormatString = nil;
    NSString *totalProgress;
    BOOL hasAtLeastOneCompleteMessage;

    if (!totalProgressFormatString)
        totalProgressFormatString = [NSLocalizedStringFromTableInBundle(@"Total: %u message, %@", @"SysExLibrarian", SMBundleForObject(self), "format of progress message when receiving multiple sysex messages (one message so far)") retain];
    if (!totalProgressPluralFormatString)
        totalProgressPluralFormatString = [NSLocalizedStringFromTableInBundle(@"Total: %u messages, %@", @"SysExLibrarian", SMBundleForObject(self), "format of progress message when receiving multiple sysex messages (more than one message so far)") retain];

    if (bytesRead == 0) {
        [progressMessageField setStringValue:[self waitingForSysexMessage]];
        [progressBytesField setStringValue:@""];
    } else {
        [progressMessageField setStringValue:[self receivingSysexMessage]];
        [progressBytesField setStringValue:[NSString SnoizeMIDI_abbreviatedStringForByteCount:bytesRead]];
    }

    hasAtLeastOneCompleteMessage = (messageCount > 0);
    if (hasAtLeastOneCompleteMessage) {
        NSString *format;

        format = (messageCount > 1)  ? totalProgressPluralFormatString : totalProgressFormatString;
        totalProgress = [NSString stringWithFormat:format, messageCount, [NSString SnoizeMIDI_abbreviatedStringForByteCount:totalBytesRead]];
    } else {
        totalProgress = @"";
    }

    [totalProgressField setStringValue:totalProgress];
    [doneButton setEnabled:hasAtLeastOneCompleteMessage];
}


//
// Actions
//

- (IBAction)doneRecording:(id)sender;
{
    [nonretainedMIDIController doneWithMultipleMessageListen];
    [self stopObservingMIDIController];

    [progressIndicator stopAnimation:nil];
    
    [NSApp endSheet:sheetWindow];

    [nonretainedMainWindowController addReadMessagesToLibrary];
}

@end
