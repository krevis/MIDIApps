#import "SSEWindowController.h"

@class OFScheduledEvent;
@class SSEMIDIController;
@class SSELibrary;
@class SSETableView;


@interface SSEMainWindowController : SSEWindowController
{
    IBOutlet SSEMIDIController *midiController;

    IBOutlet NSPopUpButton *destinationPopUpButton;

    IBOutlet SSETableView *libraryTableView;

    IBOutlet NSPanel *recordSheetWindow;
    IBOutlet NSProgressIndicator *recordProgressIndicator;
    IBOutlet NSTextField *recordProgressMessageField;
    IBOutlet NSTextField *recordProgressBytesField;

    IBOutlet NSPanel *recordMultipleSheetWindow;
    IBOutlet NSProgressIndicator *recordMultipleProgressIndicator;
    IBOutlet NSTextField *recordMultipleProgressMessageField;
    IBOutlet NSTextField *recordMultipleProgressBytesField;
    IBOutlet NSTextField *recordMultipleTotalProgressField;
    IBOutlet NSButton *recordMultipleDoneButton;
    
    IBOutlet NSPanel *playSheetWindow;
    IBOutlet NSProgressIndicator *playProgressIndicator;
    IBOutlet NSTextField *playProgressMessageField;
    IBOutlet NSTextField *playProgressBytesField;

    IBOutlet NSPanel *importSheetWindow;
    IBOutlet NSProgressIndicator *importProgressIndicator;
    IBOutlet NSTextField *importProgressMessageField;
    IBOutlet NSTextField *importProgressIndexField;

    IBOutlet NSPanel *deleteWarningSheetWindow;
    IBOutlet NSButton *doNotWarnOnDeleteAgainCheckbox;
    IBOutlet NSPanel *deleteLibraryFilesWarningSheetWindow;

    IBOutlet NSPanel *importWarningSheetWindow;
    IBOutlet NSButton *doNotWarnOnImportAgainCheckbox;
    
    // Library
    SSELibrary *library;
    NSArray *sortedLibraryEntries;
    
    // Transient data
    OFScheduledEvent *progressUpdateEvent;
    NSLock *importStatusLock;
    NSString *importFilePath;
    unsigned int importFileIndex;
    unsigned int importFileCount;
    BOOL importCancelled;
    NSString *sortColumnIdentifier;
    BOOL isSortAscending;
    NSMutableArray *entriesWithMissingFiles;
    NSToolbarItem *nonretainedDestinationToolbarItem;
}

+ (SSEMainWindowController *)mainWindowController;

// Actions

- (IBAction)selectDestinationFromPopUpButton:(id)sender;
- (IBAction)selectDestinationFromMenuItem:(id)sender;

- (IBAction)selectAll:(id)sender;

- (IBAction)addToLibrary:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)recordOne:(id)sender;
- (IBAction)recordMultiple:(id)sender;
- (IBAction)play:(id)sender;
- (IBAction)showFileInFinder:(id)sender;
- (IBAction)rename:(id)sender;

- (IBAction)cancelRecordSheet:(id)sender;
- (IBAction)doneWithRecordMultipleSheet:(id)sender;
- (IBAction)cancelPlaySheet:(id)sender;

- (IBAction)cancelImportSheet:(id)sender;

- (IBAction)endSheetWithReturnCodeFromSenderTag:(id)sender;

// Other API

- (void)synchronizeInterface;
    // Calls each of the following
- (void)synchronizeDestinations;
- (void)synchronizeLibrarySortIndicator;
- (void)synchronizeLibrary;

- (void)importFiles:(NSArray *)filePaths showingProgress:(BOOL)showProgress;

- (void)updateSysExReadIndicator;
- (void)stopSysExReadIndicator;
- (void)addReadMessagesToLibrary;

- (void)showSysExSendStatus;
- (void)hideSysExSendStatusWithSuccess:(BOOL)success;

@end

// Preferences keys
extern NSString *SSEShowWarningOnDelete;
extern NSString *SSEShowWarningOnImport;
