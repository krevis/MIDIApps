#import <Cocoa/Cocoa.h>

@class SSEMainController;


@interface SSEMainWindowController : NSWindowController
{
    IBOutlet SSEMainController *mainController;

    IBOutlet NSPopUpButton *sourcePopUpButton;
    IBOutlet NSPopUpButton *destinationPopUpButton;

    IBOutlet NSWindow *recordSheetWindow;
    IBOutlet NSTabView *recordSheetTabView;
    IBOutlet NSProgressIndicator *recordProgressIndicator;
    IBOutlet NSTextField *recordProgressField;

    IBOutlet NSWindow *playSheetWindow;
    IBOutlet NSProgressIndicator *playProgressIndicator;
    IBOutlet NSTextField *playProgressField;

    // Transient data
    NSDate *nextSysExAnimateDate;
}

+ (SSEMainWindowController *)mainWindowController;

// Actions

- (IBAction)selectSource:(id)sender;
- (IBAction)selectDestination:(id)sender;

- (IBAction)open:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)recordOne:(id)sender;
- (IBAction)record:(id)sender;
- (IBAction)play:(id)sender;

- (IBAction)cancelRecordSheet:(id)sender;
- (IBAction)cancelPlaySheet:(id)sender;

// Other API

- (void)synchronizeInterface;
    // Calls each of the following
- (void)synchronizeSources;
- (void)synchronizeDestinations;

- (void)updateSysExReadIndicatorWithBytes:(unsigned int)bytesRead;
- (void)stopSysExReadIndicatorWithBytes:(unsigned int)bytesRead;

- (void)showSysExSendStatusWithBytesToSend:(unsigned int)bytesToSend;
- (void)hideSysExSendStatusWithBytesSent:(unsigned int)bytesSent;

@end
