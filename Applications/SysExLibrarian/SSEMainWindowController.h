#import "SSEWindowController.h"

@class OFScheduledEvent;
@class SSEDeleteController;
@class SSEFindMissingController;
@class SSEImportController;
@class SSEMIDIController;
@class SSELibrary;
@class SSEPlayController;
@class SSERecordController;
@class SSETableView;

@interface SSEMainWindowController : SSEWindowController
{
    IBOutlet NSPopUpButton *destinationPopUpButton;
    IBOutlet SSETableView *libraryTableView;

    // Library
    SSELibrary *library;
    NSArray *sortedLibraryEntries;

    // Subcontrollers
    SSEMIDIController *midiController;
    SSEPlayController *playController;
    SSERecordController *recordOneController;
    SSERecordController *recordManyController;
    SSEDeleteController *deleteController;
    SSEImportController *importController;
    SSEFindMissingController *findMissingController;
    
    // Transient data
    NSString *sortColumnIdentifier;
    BOOL isSortAscending;
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

// Other API

- (void)synchronizeInterface;
    // Calls each of the following
- (void)synchronizeDestinations;
- (void)synchronizeLibrarySortIndicator;
- (void)synchronizeLibrary;

- (void)importFiles:(NSArray *)filePaths showingProgress:(BOOL)showProgress;
- (void)showNewEntries:(NSArray *)newEntries;

- (void)addReadMessagesToLibrary;

- (void)showSysExWorkaroundWarning;

@end

// Preferences keys
extern NSString *SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey;
