#import <Cocoa/Cocoa.h>

@class OFScheduledEvent;
@class SSEMainWindowController;
@class SSEMIDIController;


@interface SSERecordController : NSObject
{
    IBOutlet NSPanel *sheetWindow;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSTextField *progressMessageField;
    IBOutlet NSTextField *progressBytesField;
    
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
- (IBAction)cancelRecording:(id)sender;

// To be implemented in subclasses
- (NSString *)nibName;
- (void)tellMIDIControllerToStartRecording;
- (void)updateIndicatorsWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;

// May be overridden by subclasses
- (void)observeMIDIController;
- (void)stopObservingMIDIController;

@end
