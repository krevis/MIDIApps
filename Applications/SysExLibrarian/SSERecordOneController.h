#import <Cocoa/Cocoa.h>

@class OFScheduledEvent;
@class SSEMainWindowController;
@class SSEMIDIController;


@interface SSERecordOneController : NSObject
{
    IBOutlet NSPanel *recordSheetWindow;
    IBOutlet NSProgressIndicator *recordProgressIndicator;
    IBOutlet NSTextField *recordProgressMessageField;
    IBOutlet NSTextField *recordProgressBytesField;
    
    SSEMainWindowController *nonretainedMainWindowController;
    SSEMIDIController *nonretainedMIDIController;

    // Transient data
    OFScheduledEvent *progressUpdateEvent;
}

- (id)initWithMainWindowController:(SSEMainWindowController *)mainWindowController midiController:(SSEMIDIController *)midiController;

// Main window controller sends this to begin recording
- (void)beginRecording;
// When we have recorded successfully, we will send -addReadMessagesToLibrary to the window controller

// Actions
- (IBAction)cancelRecordSheet:(id)sender;

@end
