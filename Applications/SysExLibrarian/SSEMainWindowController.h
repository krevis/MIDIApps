#import <Cocoa/Cocoa.h>

@class OFScheduledEvent;
@class SSEMIDIController;
@class SSELibrary;
@class SSETableView;


@interface SSEMainWindowController : NSWindowController
{
    IBOutlet SSEMIDIController *midiController;

    IBOutlet NSPopUpButton *destinationPopUpButton;

    IBOutlet SSETableView *libraryTableView;

    IBOutlet NSButton *playButton;
    IBOutlet NSButton *deleteButton;
    IBOutlet NSButton *showFileButton;
    
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
    IBOutlet NSPanel *deleteLibraryFilesWarningSheetWindow;
    
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
}

+ (SSEMainWindowController *)mainWindowController;

// Actions

- (IBAction)selectDestination:(id)sender;

- (IBAction)open:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)recordOne:(id)sender;
- (IBAction)recordMultiple:(id)sender;
- (IBAction)play:(id)sender;
- (IBAction)showFileInFinder:(id)sender;

- (IBAction)cancelRecordSheet:(id)sender;
- (IBAction)doneWithRecordMultipleSheet:(id)sender;
- (IBAction)cancelPlaySheet:(id)sender;

- (IBAction)cancelImportSheet:(id)sender;

- (IBAction)endSheetWithReturnCodeFromSenderTag:(id)sender;

- (IBAction)setShowDeleteWarningInFuture:(id)sender;
- (IBAction)setShowDeleteLibraryFileWarningInFuture:(id)sender;

// Other API

- (void)synchronizeInterface;
    // Calls each of the following
- (void)synchronizeDestinations;
- (void)synchronizeLibrarySortIndicator;
- (void)synchronizeLibrary;
- (void)synchronizePlayButton;
- (void)synchronizeDeleteButton;
- (void)synchronizeShowFileButton;

- (void)updateSysExReadIndicator;
- (void)stopSysExReadIndicator;
- (void)addReadMessagesToLibrary;

- (void)showSysExSendStatus;
- (void)hideSysExSendStatusWithSuccess:(BOOL)success;

@end

// Preferences keys
extern NSString *SSEShowWarningOnDelete;
extern NSString *SSEShowWarningOnDeleteFilesInLibrary;
