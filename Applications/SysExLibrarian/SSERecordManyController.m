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
    NSString *totalProgress;
    BOOL hasAtLeastOneCompleteMessage;

    if (bytesRead == 0) {
        [progressMessageField setStringValue:@"Waiting for SysEx message..."];
        [progressBytesField setStringValue:@""];
    } else {
        [progressIndicator animate:nil];
        [progressMessageField setStringValue:@"Receiving SysEx message..."];
        [progressBytesField setStringValue:[NSString abbreviatedStringForBytes:bytesRead]];
    }

    hasAtLeastOneCompleteMessage = (messageCount > 0);
    if (hasAtLeastOneCompleteMessage) {
        totalProgress = [NSString stringWithFormat:@"Total: %u message%@, %@", messageCount, (messageCount > 1) ? @"s" : @"", [NSString abbreviatedStringForBytes:totalBytesRead]];
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
