#import <Cocoa/Cocoa.h>

@class SSEMainWindowController;

@interface SSEDeleteController : NSObject
{
    IBOutlet NSPanel *deleteWarningSheetWindow;
    IBOutlet NSButton *doNotWarnOnDeleteAgainCheckbox;
    IBOutlet NSPanel *deleteLibraryFilesWarningSheetWindow;

    SSEMainWindowController *nonretainedMainWindowController;

    NSArray *entriesToDelete;
}

- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController;

// Main window controller sends this to begin the process
- (void)deleteEntries:(NSArray *)entries;

// Actions
- (IBAction)endSheetWithReturnCodeFromSenderTag:(id)sender;

@end

// Preferences keys
extern NSString *SSEShowWarningOnDeletePreferenceKey;
