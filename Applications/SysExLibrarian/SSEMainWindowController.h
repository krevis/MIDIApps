#import "SSEWindowController.h"

@class OFScheduledEvent;
@class SSEMIDIController;
@class SSELibrary;
@class SSERecordController;
@class SSETableView;

@interface SSEMainWindowController : SSEWindowController
{
    IBOutlet SSEMIDIController *midiController;

    IBOutlet NSPopUpButton *destinationPopUpButton;

    IBOutlet SSETableView *libraryTableView;

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
    SSERecordController *recordOneController;
    SSERecordController *recordManyController;
    NSLock *importStatusLock;
    NSString *importFilePath;
    unsigned int importFileIndex;
    unsigned int importFileCount;
    BOOL importCancelled;
    NSString *sortColumnIdentifier;
    BOOL isSortAscending;
    NSMutableArray *entriesWithMissingFiles;
    NSToolbarItem *nonretainedDestinationToolbarItem;
    BOOL showSysExWarningWhenShowingWindow;
}

+ (SSEMainWindowController *)mainWindowController;

// Actions

- (IBAction)selectDestinationFromPopUpButton:(id)sender;
- (IBAction)selectDestinationFromMenuItem:(id)sender;

- (IBAction)selectAll:(id)sender;

- (IBAction)addToLibrary:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)recordOne:(id)sender;
- (IBAction)recordMany:(id)sender;
- (IBAction)play:(id)sender;
- (IBAction)showFileInFinder:(id)sender;
- (IBAction)rename:(id)sender;
- (IBAction)showDetails:(id)sender;

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

- (void)addReadMessagesToLibrary;

- (void)showSysExSendStatus;
- (void)hideSysExSendStatusWithSuccess:(BOOL)success;

- (void)showSysExWorkaroundWarning;

@end

// Preferences keys
extern NSString *SSEShowWarningOnDeletePreferenceKey;
extern NSString *SSEShowWarningOnImportPreferenceKey;
extern NSString *SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey;
