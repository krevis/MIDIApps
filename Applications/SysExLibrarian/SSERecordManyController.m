#import "SSERecordManyController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

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

- (void)updateIndicatorsWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;
{
    static NSString *totalProgressFormatString = nil;
    static NSString *totalProgressPluralFormatString = nil;
    NSString *totalProgress;
    BOOL hasAtLeastOneCompleteMessage;

    if (!totalProgressFormatString)
        totalProgressFormatString = [NSLocalizedStringFromTableInBundle(@"Total: %u message, %@", @"SysExLibrarian", [self bundle], "format of progress message when receiving multiple sysex messages (one message so far)") retain];
    if (!totalProgressPluralFormatString)
        totalProgressPluralFormatString = [NSLocalizedStringFromTableInBundle(@"Total: %u messages, %@", @"SysExLibrarian", [self bundle], "format of progress message when receiving multiple sysex messages (more than one message so far)") retain];

    if (bytesRead == 0) {
        [progressMessageField setStringValue:[self waitingForSysexMessage]];
        [progressBytesField setStringValue:@""];
    } else {
        [progressIndicator animate:nil];
        [progressMessageField setStringValue:[self receivingSysexMessage]];
        [progressBytesField setStringValue:[NSString abbreviatedStringForBytes:bytesRead]];
    }

    hasAtLeastOneCompleteMessage = (messageCount > 0);
    if (hasAtLeastOneCompleteMessage) {
        NSString *format;

        format = (messageCount > 1)  ? totalProgressPluralFormatString : totalProgressFormatString;
        totalProgress = [NSString stringWithFormat:format, messageCount, [NSString abbreviatedStringForBytes:totalBytesRead]];
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

    [NSApp endSheet:sheetWindow];

    [nonretainedMainWindowController addReadMessagesToLibrary];
}

@end
