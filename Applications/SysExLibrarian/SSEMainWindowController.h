#import <Cocoa/Cocoa.h>

@class OFScheduledEvent;
@class SSEMainController;


@interface SSEMainWindowController : NSWindowController
{
    IBOutlet SSEMainController *mainController;

    IBOutlet NSPopUpButton *sourcePopUpButton;
    IBOutlet NSPopUpButton *destinationPopUpButton;

    IBOutlet NSWindow *recordSheetWindow;
    IBOutlet NSProgressIndicator *recordProgressIndicator;
    IBOutlet NSTextField *recordProgressMessageField;
    IBOutlet NSTextField *recordProgressBytesField;

    IBOutlet NSWindow *recordMultipleSheetWindow;
    IBOutlet NSProgressIndicator *recordMultipleProgressIndicator;
    IBOutlet NSTextField *recordMultipleProgressMessageField;
    IBOutlet NSTextField *recordMultipleProgressBytesField;
    IBOutlet NSTextField *recordMultipleTotalProgressField;
    IBOutlet NSButton *recordMultipleDoneButton;
    
    IBOutlet NSWindow *playSheetWindow;
    IBOutlet NSProgressIndicator *playProgressIndicator;
    IBOutlet NSTextField *playProgressMessageField;
    IBOutlet NSTextField *playProgressBytesField;

    // Transient data
    OFScheduledEvent *progressUpdateEvent;
}

+ (SSEMainWindowController *)mainWindowController;

// Actions

- (IBAction)selectSource:(id)sender;
- (IBAction)selectDestination:(id)sender;

- (IBAction)open:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)recordOne:(id)sender;
- (IBAction)recordMultiple:(id)sender;
- (IBAction)play:(id)sender;

- (IBAction)cancelRecordSheet:(id)sender;
- (IBAction)doneWithRecordMultipleSheet:(id)sender;
- (IBAction)cancelPlaySheet:(id)sender;

// Other API

- (void)synchronizeInterface;
    // Calls each of the following
- (void)synchronizeSources;
- (void)synchronizeDestinations;

- (void)updateSysExReadIndicator;
- (void)stopSysExReadIndicator;

- (void)showSysExSendStatus;
- (void)hideSysExSendStatus;

@end
