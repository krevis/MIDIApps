#import "SSERecordController.h"


@interface SSERecordManyController : SSERecordController
{
    IBOutlet NSTextField *totalProgressField;
    IBOutlet NSButton *doneButton;
}

// Actions
- (IBAction)doneRecording:(id)sender;

@end
