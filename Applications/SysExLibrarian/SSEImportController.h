#import <Cocoa/Cocoa.h>

@class SSELibrary;
@class SSEMainWindowController;

@interface SSEImportController : NSObject
{
    IBOutlet NSPanel *importSheetWindow;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSTextField *progressMessageField;
    IBOutlet NSTextField *progressIndexField;

    IBOutlet NSPanel *importWarningSheetWindow;
    IBOutlet NSButton *doNotWarnOnImportAgainCheckbox;
    
    SSEMainWindowController *nonretainedMainWindowController;
    SSELibrary *nonretainedLibrary;

    // Transient data
    NSArray *filePathsToImport;
    BOOL shouldShowProgress;

    NSLock *importStatusLock;
    NSString *importFilePath;
    unsigned int importFileIndex;
    unsigned int importFileCount;

    BOOL importCancelled;    
}

- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController library:(SSELibrary *)library;

// Main window controller sends this to begin the process
- (void)importFiles:(NSArray *)filePaths showingProgress:(BOOL)showProgress;

// Actions
- (IBAction)cancelImporting:(id)sender;
- (IBAction)endSheetWithReturnCodeFromSenderTag:(id)sender;

@end

// Preferences keys
extern NSString *SSEShowWarningOnImportPreferenceKey;
