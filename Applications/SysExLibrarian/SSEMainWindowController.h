#import <Cocoa/Cocoa.h>

@class OFScheduledEvent;
@class SSEMainController;
@class SSELibrary;


@interface SSEMainWindowController : NSWindowController
{
    IBOutlet SSEMainController *mainController;

    IBOutlet NSPopUpButton *sourcePopUpButton;
    IBOutlet NSPopUpButton *destinationPopUpButton;

    IBOutlet NSTableView  *libraryTableView;

    IBOutlet NSButton *playButton;
    
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

    // Library
    SSELibrary *library;
    
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
- (void)synchronizeLibrary;
- (void)synchronizePlayButton;

- (void)updateSysExReadIndicator;
- (void)stopSysExReadIndicator;

- (void)showSysExSendStatus;
- (void)hideSysExSendStatusWithSuccess:(BOOL)success;

@end
