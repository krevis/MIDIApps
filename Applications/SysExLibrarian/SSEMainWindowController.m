#import "SSEMainWindowController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "NSPopUpButton-Extensions.h"
#import "SSEDetailsWindowController.h"
#import "SSELibrary.h"
#import "SSELibraryEntry.h"
#import "SSEMIDIController.h"
#import "SSEPreferencesWindowController.h"
#import "SSETableView.h"


@interface SSEMainWindowController (Private)

- (void)_displayPreferencesDidChange:(NSNotification *)notification;

- (BOOL)_finishEditingResultsInError;

- (void)_synchronizeDestinationPopUpWithDescriptions:(NSArray *)descriptions currentDescription:(NSDictionary *)currentDescription;
- (void)_synchronizeDestinationToolbarMenuWithDescriptions:(NSArray *)descriptions currentDescription:(NSDictionary *)currentDescription;

- (void)_libraryDidChange:(NSNotification *)notification;
- (void)_sortLibraryEntries;

- (NSArray *)_selectedEntries;
- (void)_selectEntries:(NSArray *)entries;
- (void)_scrollToEntries:(NSArray *)entries;
- (void)_selectAndScrollToEntries:(NSArray *)entries;

- (void)_openPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void  *)contextInfo;
- (void)_showImportWarningForFiles:(NSArray *)filePaths andThenPerformSelector:(SEL)selector;
- (void)_importWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)_addFilesToLibraryInMainThread:(NSArray *)filePaths;
- (void)_showErrorMessageForBadFiles:(NSArray *)badFilePaths;

- (void)_sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)_updateSysExReadIndicator;
- (void)_updateSingleSysExReadIndicatorWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;
- (void)_updateMultipleSysExReadIndicatorWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;

- (void)_playSelectedEntries;

- (void)_updatePlayProgressAndRepeat;
- (void)_updatePlayProgress;

- (void)_showDetailsOfSelectedEntries;

- (BOOL)_areAnyFilesAcceptable:(NSArray *)filePaths;
- (BOOL)_areAnyFilesDirectories:(NSArray *)filePaths;
- (void)_importFilesShowingProgress:(NSArray *)filePaths;
- (void)_workThreadImportFiles:(NSArray *)filePaths;
- (NSArray *)_workThreadExpandAndFilterDraggedFiles:(NSArray *)filePaths;

- (NSArray *)_addFilesToLibrary:(NSArray *)filePaths returningBadFiles:(NSArray **)badFilePathsPtr;

- (void)_showImportSheet;
- (void)_updateImportStatusDisplay;
- (void)_doneImportingInWorkThreadWithAddedEntries:(NSArray *)addedEntries badFiles:(NSArray *)badFilePaths;

- (void)_findMissingFilesAndPerformSelector:(SEL)selector;
- (void)_missingFileAlertDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)_runOpenSheetForMissingFileWithContextInfo:(void *)contextInfo;
- (void)_findMissingFileOpenPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)_deleteWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)_deleteStep2;
- (void)_deleteLibraryFilesWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)_deleteSelectedEntriesMovingLibraryFilesToTrash:(BOOL)shouldMoveToTrash;

@end


@implementation SSEMainWindowController

NSString *SSEShowWarningOnDeletePreferenceKey = @"SSEShowWarningOnDelete";
NSString *SSEShowWarningOnImportPreferenceKey = @"SSEShowWarningOnImport";
NSString *SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey = @"SSEAbbreviateFileSizesInLibraryTableView";

static SSEMainWindowController *controller;


+ (SSEMainWindowController *)mainWindowController;
{
    if (!controller)
        controller = [[self alloc] init];

    return controller;
}

- (id)init;
{
    if (!(self = [super initWithWindowNibName:@"MainWindow"]))
        return nil;

    library = [[SSELibrary sharedLibrary] retain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_libraryDidChange:) name:SSELibraryDidChangeNotification object:library];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_displayPreferencesDidChange:) name:SSEDisplayPreferenceChangedNotification object:nil];

    importStatusLock = [[NSLock alloc] init];

    sortColumnIdentifier = @"name";
    isSortAscending = YES;

    showSysExWarningWhenShowingWindow = NO;

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [progressUpdateEvent release];
    progressUpdateEvent = nil;
    [importStatusLock release];
    importStatusLock = nil;
    [importFilePath release];
    importFilePath = nil;
    [sortColumnIdentifier release];
    sortColumnIdentifier = nil;
    [sortedLibraryEntries release];
    sortedLibraryEntries = nil;
    [entriesWithMissingFiles release];
    entriesWithMissingFiles = nil;
    
    [super dealloc];
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    [libraryTableView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    [libraryTableView setTarget:self];
    [libraryTableView setDoubleAction:@selector(play:)];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self synchronizeInterface];
}

- (void)speciallyInitializeToolbarItem:(NSToolbarItem *)toolbarItem;
{
    float height;
    NSMenuItem *menuItem;
    NSMenu *submenu;

    nonretainedDestinationToolbarItem = toolbarItem;
    
    [toolbarItem setView:destinationPopUpButton];

    height = NSHeight([destinationPopUpButton frame]);
    [toolbarItem setMinSize:NSMakeSize(150, height)];
    [toolbarItem setMaxSize:NSMakeSize(1000, height)];

    menuItem = [[NSMenuItem alloc] initWithTitle:@"Destination" action:NULL keyEquivalent:@""];
    submenu = [[NSMenu alloc] initWithTitle:@""];
    [menuItem setSubmenu:submenu];
    [submenu release];
    [toolbarItem setMenuFormRepresentation:menuItem];
    [menuItem release];
}

- (IBAction)showWindow:(id)sender;
{
    [super showWindow:sender];

    if (showSysExWarningWhenShowingWindow) {
        [self showSysExWorkaroundWarning];
        showSysExWarningWhenShowingWindow = NO;
    }
}

//
// Action validation
//

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)theItem;
{
    SEL action;

    action = [theItem action];

    if (action == @selector(play:))
        return ([libraryTableView numberOfSelectedRows] > 0);
    else if (action == @selector(delete:))
        return ([libraryTableView numberOfSelectedRows] > 0);
    else if (action == @selector(showFileInFinder:))
        return ([libraryTableView numberOfSelectedRows] == 1 && [[[self _selectedEntries] objectAtIndex:0] isFilePresent]);
    else if (action == @selector(rename:))
        return ([libraryTableView numberOfSelectedRows] == 1 && [[[self _selectedEntries] objectAtIndex:0] isFilePresent]);
    else if (action == @selector(showDetails:))
        return ([libraryTableView numberOfSelectedRows] > 0);
    else
        return [super validateUserInterfaceItem:theItem];
}

//
// Actions
//

- (IBAction)selectDestinationFromPopUpButton:(id)sender;
{
    [midiController setDestinationDescription:[(NSMenuItem *)[sender selectedItem] representedObject]];
}

- (IBAction)selectDestinationFromMenuItem:(id)sender;
{
    [midiController setDestinationDescription:[(NSMenuItem *)sender representedObject]];
}

- (IBAction)selectAll:(id)sender;
{
    // Forward to the library table view, even if it isn't the first responder
    [libraryTableView selectAll:sender];
}

- (IBAction)addToLibrary:(id)sender;
{
    NSOpenPanel *openPanel;

    if ([self _finishEditingResultsInError])
        return;
    
    openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:YES];

    [openPanel beginSheetForDirectory:nil file:nil types:[library allowedFileTypes] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)delete:(id)sender;
{
    if ([self _finishEditingResultsInError])
        return;

    if ([[OFPreference preferenceForKey:SSEShowWarningOnDeletePreferenceKey] boolValue]) {
        [doNotWarnOnDeleteAgainCheckbox setIntValue:0];
        [[NSApplication sharedApplication] beginSheet:deleteWarningSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_deleteWarningSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    } else {
        [self _deleteStep2];
    } 
}

- (IBAction)recordOne:(id)sender;
{
    if ([self _finishEditingResultsInError])
        return;

    [self _updateSingleSysExReadIndicatorWithMessageCount:0 bytesRead:0 totalBytesRead:0];

    [[NSApplication sharedApplication] beginSheet:recordSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];    

    [midiController listenForOneMessage];
}

- (IBAction)recordMultiple:(id)sender;
{
    if ([self _finishEditingResultsInError])
        return;

    [self _updateMultipleSysExReadIndicatorWithMessageCount:0 bytesRead:0 totalBytesRead:0];

    [[NSApplication sharedApplication] beginSheet:recordMultipleSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];

    [midiController listenForMultipleMessages];
}

- (IBAction)play:(id)sender;
{
    if ([self _finishEditingResultsInError])
        return;

    [self _findMissingFilesAndPerformSelector:@selector(_playSelectedEntries)];
}

- (IBAction)showFileInFinder:(id)sender;
{
    NSArray *selectedEntries;
    NSString *path;

    [self finishEditingInWindow];
        // We don't care if there is an error, go on anyway

    selectedEntries = [self _selectedEntries];
    OBASSERT([selectedEntries count] == 1);

    if ((path = [[selectedEntries objectAtIndex:0] path]))
        [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:@""];
    else
        NSBeep();	// Turns out the file isn't there after all
}

- (IBAction)rename:(id)sender;
{
    if ([libraryTableView editedRow] >= 0) {
        // We are already editing the table view, so don't do anything
    } else  {
        [self finishEditingInWindow];  // In case we are editing something else

        // Make sure that the file really exists right now before we try to rename it
        if ([[[self _selectedEntries] objectAtIndex:0] isFilePresentIgnoringCachedValue])
            [libraryTableView editColumn:0 row:[libraryTableView selectedRow] withEvent:nil select:YES];
        else
            NSBeep();
    }
}

- (IBAction)showDetails:(id)sender;
{
    if ([self _finishEditingResultsInError])
        return;

    [self _findMissingFilesAndPerformSelector:@selector(_showDetailsOfSelectedEntries)];
}

- (IBAction)cancelRecordSheet:(id)sender;
{
    [midiController cancelMessageListen];
    [[NSApplication sharedApplication] endSheet:[[self window] attachedSheet]];
}

- (IBAction)doneWithRecordMultipleSheet:(id)sender;
{
    [midiController doneWithMultipleMessageListen];
    [[NSApplication sharedApplication] endSheet:recordMultipleSheetWindow];
    [self addReadMessagesToLibrary];
}

- (IBAction)cancelPlaySheet:(id)sender;
{
    [midiController cancelSendingMessages];
    // -hideSysExSendStatusWithSuccess: will get called soon; it will end the sheet
}

- (IBAction)cancelImportSheet:(id)sender;
{
    // No need to lock just to set a boolean
    importCancelled = YES;
}

- (IBAction)endSheetWithReturnCodeFromSenderTag:(id)sender;
{
    [[NSApplication sharedApplication] endSheet:[[self window] attachedSheet] returnCode:[sender tag]];
}

//
// Other API
//

- (void)synchronizeInterface;
{
    [self synchronizeDestinations];
    [self synchronizeLibrarySortIndicator];
    [self synchronizeLibrary];
}

- (void)synchronizeDestinations;
{
    NSArray *descriptions;
    NSDictionary *currentDescription;

    descriptions = [midiController destinationDescriptions];
    currentDescription = [midiController destinationDescription];

    [self _synchronizeDestinationPopUpWithDescriptions:descriptions currentDescription:currentDescription];
    [self _synchronizeDestinationToolbarMenuWithDescriptions:descriptions currentDescription:currentDescription];
}

- (void)synchronizeLibrarySortIndicator;
{
    NSTableColumn *column;

    column = [libraryTableView tableColumnWithIdentifier:sortColumnIdentifier];    
    [libraryTableView setSortColumn:column isAscending:isSortAscending];
    [libraryTableView setHighlightedTableColumn:column];
}

- (void)synchronizeLibrary;
{
    NSArray *selectedEntries;

    selectedEntries = [self _selectedEntries];

    [self _sortLibraryEntries];

    // NOTE Some entries in selectedEntries may no longer be present in sortedLibraryEntries.
    // We don't need to manually take them out of selectedEntries because _selectEntries can deal with
    // entries that are missing.
    
    [libraryTableView reloadData];
    [self _selectEntries:selectedEntries];

    // Sometimes, apparently, reloading the table view will not mark the window as needing update. Weird.
    [NSApp setWindowsNeedUpdate:YES];
}

- (void)importFiles:(NSArray *)filePaths showingProgress:(BOOL)showProgress;
{
    SEL selector;

    if (![self _areAnyFilesDirectories:filePaths])
        showProgress = NO;

    selector = showProgress ? @selector(_importFilesShowingProgress:) : @selector(_addFilesToLibraryInMainThread:);
    [self _showImportWarningForFiles:filePaths andThenPerformSelector:selector];
}


//
// Reading SysEx
//

- (void)updateSysExReadIndicator;
{
    if (!progressUpdateEvent) {
        progressUpdateEvent = [[[OFScheduler mainScheduler] scheduleSelector:@selector(_updateSysExReadIndicator) onObject:self afterTime:[recordProgressIndicator animationDelay]] retain];
    }
}

- (void)stopSysExReadIndicator;
{
    // If there is an update pending, try to cancel it. If that succeeds, then we know the event never happened, and we do it ourself now.
    if (progressUpdateEvent && [[OFScheduler mainScheduler] abortEvent:progressUpdateEvent])
        [progressUpdateEvent invoke];

    // Close the sheet, after a little bit of a delay (makes it look nicer)
    [NSApp performSelector:@selector(endSheet:) withObject:[[self window] attachedSheet] afterDelay:0.5];
}

- (void)addReadMessagesToLibrary;
{
    NSData *allSysexData;
    SSELibraryEntry *entry = nil;
    NSString *exceptionReason = nil;

    allSysexData = [SMSystemExclusiveMessage dataForSystemExclusiveMessages:[midiController messages]];
    if (!allSysexData)
        return;	// No messages, no data, nothing to do
    
    NS_DURING {
        entry = [library addNewEntryWithData:allSysexData];
    } NS_HANDLER {
        exceptionReason = [[[localException reason] retain] autorelease];
    } NS_ENDHANDLER;

    if (entry) {
        [self synchronizeLibrary];
        [self _selectAndScrollToEntries:[NSArray arrayWithObject:entry]];
    } else {
        NSWindow *attachedSheet;
        
        if (!exceptionReason)
            exceptionReason = @"Unknown error";   // NOTE I don't see how this could happen, but let's handle it...

        // We need to get rid of the sheet right away, instead of after the delay (see -stopSysExReadIndicator).
        if ((attachedSheet = [[self window] attachedSheet])) {
            [NSObject cancelPreviousPerformRequestsWithTarget:NSApp selector:@selector(endSheet:) object:attachedSheet];
            [NSApp endSheet:attachedSheet];
        }

        // Now we can start another sheet.
        OBASSERT([[self window] attachedSheet] == nil);
        NSBeginAlertSheet(@"Error", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"The file could not be created.\n%@", exceptionReason);
    }
}

//
// Sending SysEx
//

- (void)showSysExSendStatus;
{
    unsigned int bytesToSend;

    [playProgressIndicator setMinValue:0.0];
    [playProgressIndicator setDoubleValue:0.0];
    [midiController getMessageCount:NULL messageIndex:NULL bytesToSend:&bytesToSend bytesSent:NULL];
    [playProgressIndicator setMaxValue:bytesToSend];

    [self _updatePlayProgressAndRepeat];

    [[NSApplication sharedApplication] beginSheet:playSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)hideSysExSendStatusWithSuccess:(BOOL)success;
{
    // If there is an update pending, try to cancel it. If that succeeds, then we know the event never happened, and we do it ourself now.
    if (progressUpdateEvent && [[OFScheduler mainScheduler] abortEvent:progressUpdateEvent]) {
        [self _updatePlayProgress];
        [progressUpdateEvent release];
        progressUpdateEvent = nil;
    }
    
    if (!success)
        [playProgressMessageField setStringValue:@"Cancelled."];

    // Even if we have set the progress indicator to its maximum value, it won't get drawn on the screen that way immediately,
    // probably because it tries to smoothly animate to that state. The only way I have found to show the maximum value is to just
    // wait a little while for the animation to finish. This looks nice, too.
    [[NSApplication sharedApplication] performSelector:@selector(endSheet:) withObject:playSheetWindow afterDelay:0.5];    
}

//
// SysEx workaround warning
//

- (void)showSysExWorkaroundWarning;
{    
    if (![[self window] isVisible]) {
        showSysExWarningWhenShowingWindow = YES;
        return;
    }
    
    OBASSERT([[self window] attachedSheet] == nil);
    if ([[self window] attachedSheet])
        return;

    NSBeginAlertSheet(@"Warning", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"The driver for this MIDIMAN device has problems sending SysEx messages. SysEx Librarian will attempt to work around the problems, but please be warned that you may still experience unpredictable hangs or crashes, and sending large amounts of data will be slow.\n\nPlease check the manufacturer's web site to see if an updated driver is available.");

    [[OFPreference preferenceForKey:SSEHasShownSysExWorkaroundWarningPreferenceKey] setBoolValue:YES];
    [[NSUserDefaults standardUserDefaults] autoSynchronize];
}

@end


@implementation SSEMainWindowController (NotificationsDelegatesDataSources)

//
// NSTableView data source
//

- (int)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [sortedLibraryEntries count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    SSELibraryEntry *entry;
    NSString *identifier;

    entry = [sortedLibraryEntries objectAtIndex:row];
    identifier = [tableColumn identifier];

    if ([identifier isEqualToString:@"name"]) {
        return [entry name];
    } else if ([identifier isEqualToString:@"manufacturer"]) {
        return [entry manufacturer];
    } else if ([identifier isEqualToString:@"size"]) {
        NSNumber *entrySize;

        entrySize = [entry size];
        if ([[OFPreference preferenceForKey:SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey] boolValue])
            return [NSString abbreviatedStringForBytes:[entrySize unsignedIntValue]];
        else
            return [entrySize stringValue];
    } else if ([identifier isEqualToString:@"messageCount"]) {
        return [entry messageCount];
    } else {
        return nil;
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    NSString *newName = (NSString *)object;
    SSELibraryEntry *entry;

    if (!newName || [newName length] == 0)
        return;
    
    entry = [sortedLibraryEntries objectAtIndex:row];
    if (![entry renameFileTo:newName]) {
        NSBeginAlertSheet(@"Error", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"The file for this item could not be renamed.");
    }
    
    [self synchronizeLibrary];
}

//
// SSETableView data source
//

- (void)tableView:(SSETableView *)tableView deleteRows:(NSArray *)rows;
{
    [self delete:tableView];
}

- (NSDragOperation)tableView:(SSETableView *)tableView draggingEntered:(id <NSDraggingInfo>)sender;
{
    if ([self _areAnyFilesAcceptable:[[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType]])
        return NSDragOperationGeneric;
    else
        return NSDragOperationNone;
}

- (BOOL)tableView:(SSETableView *)tableView performDragOperation:(id <NSDraggingInfo>)sender;
{
    NSArray *filePaths;

    filePaths = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
    [self importFiles:filePaths showingProgress:YES];

    return YES;
}

//
// NSTableView delegate
//

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    SSELibraryEntry *entry;
    NSColor *color;
    
    entry = [sortedLibraryEntries objectAtIndex:row];
    color = [entry isFilePresent] ? [NSColor blackColor] : [NSColor redColor];
    [cell setTextColor:color];
}

- (void)tableView:(NSTableView *)tableView mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn;
{
    NSString *identifier;

    identifier = [tableColumn identifier];
    if ([identifier isEqualToString:sortColumnIdentifier]) {
        isSortAscending = !isSortAscending;
    } else {
        [sortColumnIdentifier release];
        sortColumnIdentifier = [identifier retain];
        isSortAscending = YES;
    }

    [self synchronizeLibrarySortIndicator];
    [self synchronizeLibrary];
    [self _scrollToEntries:[self _selectedEntries]];
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    SSELibraryEntry *entry;

    entry = [sortedLibraryEntries objectAtIndex:row];
    return ([entry isFilePresent]);
}

@end


@implementation SSEMainWindowController (Private)

- (void)_displayPreferencesDidChange:(NSNotification *)notification;
{
    [libraryTableView reloadData];
}

- (BOOL)_finishEditingResultsInError;
{
    [self finishEditingInWindow];
    return ([[self window] attachedSheet] != nil);
}

- (void)_synchronizeDestinationPopUpWithDescriptions:(NSArray *)descriptions currentDescription:(NSDictionary *)currentDescription;
{
    BOOL wasAutodisplay;
    unsigned int count, index;
    BOOL found = NO;
    BOOL addedSeparatorBetweenPortAndVirtual = NO;
    
    // The pop up button redraws whenever it's changed, so turn off autodisplay to stop the blinkiness
    wasAutodisplay = [[self window] isAutodisplay];
    [[self window] setAutodisplay:NO];

    [destinationPopUpButton removeAllItems];

    count = [descriptions count];
    for (index = 0; index < count; index++) {
        NSDictionary *description;

        description = [descriptions objectAtIndex:index];
        if (!addedSeparatorBetweenPortAndVirtual && [description objectForKey:@"endpoint"] == nil) {
            if (index > 0)
                [destinationPopUpButton addSeparatorItem];
            addedSeparatorBetweenPortAndVirtual = YES;
        }
        [destinationPopUpButton addItemWithTitle:[description objectForKey:@"name"] representedObject:description];

        if (!found && [description isEqual:currentDescription]) {
            [destinationPopUpButton selectItemAtIndex:[destinationPopUpButton numberOfItems] - 1];
            // Don't use index because it may be off by one (because of the separator item)
            found = YES;
        }
    }

    if (!found)
        [destinationPopUpButton selectItem:nil];

    // ...and turn autodisplay on again
    if (wasAutodisplay)
        [[self window] displayIfNeeded];
    [[self window] setAutodisplay:wasAutodisplay];
}

- (void)_synchronizeDestinationToolbarMenuWithDescriptions:(NSArray *)descriptions currentDescription:(NSDictionary *)currentDescription;
{
    // Set the title to "Destination: <Whatever>"
    // Then set up the submenu items
    NSMenuItem *topMenuItem;
    NSString *destinationName;
    NSMenu *submenu;
    unsigned int count, index;
    BOOL found = NO;
    BOOL addedSeparatorBetweenPortAndVirtual = NO;

    topMenuItem = [nonretainedDestinationToolbarItem menuFormRepresentation];
    
    destinationName = [currentDescription objectForKey:@"name"];
    if (!destinationName)
        destinationName = @"None";
    [topMenuItem setTitle:[@"Destination: " stringByAppendingString:destinationName]];

    submenu = [topMenuItem submenu];
    index = [submenu numberOfItems];
    while (index--)
        [submenu removeItemAtIndex:index];

    count = [descriptions count];
    for (index = 0; index < count; index++) {
        NSDictionary *description;
        NSMenuItem *menuItem;

        description = [descriptions objectAtIndex:index];
        if (!addedSeparatorBetweenPortAndVirtual && [description objectForKey:@"endpoint"] == nil) {
            if (index > 0)
                [submenu addItem:[NSMenuItem separatorItem]];
            addedSeparatorBetweenPortAndVirtual = YES;
        }
        menuItem = [submenu addItemWithTitle:[description objectForKey:@"name"] action:@selector(selectDestinationFromMenuItem:) keyEquivalent:@""];
        [menuItem setRepresentedObject:description];
        [menuItem setTarget:self];

        if (!found && [description isEqual:currentDescription]) {
            [menuItem setState:NSOnState];
            found = YES;
        }
    }

    // Workaround to get the toolbar item to refresh after we change the title of the menu item
    [topMenuItem retain];
    [nonretainedDestinationToolbarItem setMenuFormRepresentation:nil];
    [nonretainedDestinationToolbarItem setMenuFormRepresentation:topMenuItem];
    [topMenuItem release];    
}

- (void)_libraryDidChange:(NSNotification *)notification;
{
    // Reloading the table view will wipe out the edit session, so don't do that if we're editing
    if ([libraryTableView editedRow] == -1)
        [self synchronizeLibrary];
}

static int libraryEntryComparator(id object1, id object2, void *context)
{
    NSString *key = (NSString *)context;
    id value1, value2;

    value1 = [object1 valueForKey:key];
    value2 = [object2 valueForKey:key];

    if (value1 && value2)
        // NOTE: We would say:
        // return [value1 compare:value2];
        // but that gives us a warning because there are multiple declarations of compare: (for NSString, NSDate, etc.).
        // So let's just avoid that whole problem.
        return (NSComparisonResult)objc_msgSend(value1, @selector(compare:), value2);
    else if (value1) {
        return NSOrderedDescending;
    } else {
        // both are nil
        return NSOrderedSame;
    }
}

- (void)_sortLibraryEntries;
{
    [sortedLibraryEntries release];
    sortedLibraryEntries = [[library entries] sortedArrayUsingFunction:libraryEntryComparator context:sortColumnIdentifier];
    if (!isSortAscending)
        sortedLibraryEntries = [sortedLibraryEntries reversedArray];
    [sortedLibraryEntries retain];
}

- (NSArray *)_selectedEntries;
{
    NSMutableArray *selectedEntries;
    NSEnumerator *selectedRowEnumerator;
    NSNumber *rowNumber;

    selectedEntries = [NSMutableArray array];

    selectedRowEnumerator = [libraryTableView selectedRowEnumerator];
    while ((rowNumber = [selectedRowEnumerator nextObject])) {
        [selectedEntries addObject:[sortedLibraryEntries objectAtIndex:[rowNumber intValue]]];
    }

    return selectedEntries;
}

- (void)_selectEntries:(NSArray *)entries;
{
    unsigned int entryCount, entryIndex;

    [libraryTableView deselectAll:nil];

    entryCount = [entries count];
    if (entryCount == 0)
        return;

    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        unsigned int row;

        row = [sortedLibraryEntries indexOfObjectIdenticalTo:[entries objectAtIndex:entryIndex]];
        if (row != NSNotFound)
            [libraryTableView selectRow:row byExtendingSelection:YES];
    }
}

- (void)_scrollToEntries:(NSArray *)entries;
{
    unsigned int entryCount, entryIndex;
    unsigned int lowestRow = UINT_MAX;

    entryCount = [entries count];
    if (entryCount == 0)
        return;
    
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        unsigned int row;

        row = [sortedLibraryEntries indexOfObjectIdenticalTo:[entries objectAtIndex:entryIndex]];
        if (row != NSNotFound)
            lowestRow = MIN(lowestRow, row);
    }

    [libraryTableView scrollRowToVisible:lowestRow];
}

- (void)_selectAndScrollToEntries:(NSArray *)entries;
{
    [self _selectEntries:entries];
    [self _scrollToEntries:entries];
}

- (void)_openPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void  *)contextInfo;
{
    if (returnCode == NSOKButton) {
        [openPanel orderOut:nil];
        [self importFiles:[openPanel filenames] showingProgress:NO];
    }
}

- (void)_showImportWarningForFiles:(NSArray *)filePaths andThenPerformSelector:(SEL)selector;
{
    BOOL areAllFilesInLibraryDirectory = YES;
    unsigned int fileIndex;

    fileIndex = [filePaths count];
    while (fileIndex--) {
        if (![library isPathInFileDirectory:[filePaths objectAtIndex:fileIndex]]) {
            areAllFilesInLibraryDirectory = NO;
            break;
        }
    }

    if (areAllFilesInLibraryDirectory || [[OFPreference preferenceForKey:SSEShowWarningOnImportPreferenceKey] boolValue] == NO) {
        [self performSelector:selector withObject:filePaths];
    } else {
        OFInvocation *invocation;

        invocation = [[OFInvocation alloc] initForObject:self selector:selector withObject:filePaths];

        [doNotWarnOnImportAgainCheckbox setIntValue:0];
        [[NSApplication sharedApplication] beginSheet:importWarningSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_importWarningSheetDidEnd:returnCode:contextInfo:) contextInfo:invocation];
    }
}

- (void)_importWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:nil];

    if (returnCode == NSOKButton) {
        OFInvocation *invocation = (OFInvocation *)contextInfo;

        if ([doNotWarnOnImportAgainCheckbox intValue] == 1)
            [[OFPreference preferenceForKey:SSEShowWarningOnImportPreferenceKey] setBoolValue:NO];

        [invocation invoke];
        [invocation release];
    }
}

- (void)_addFilesToLibraryInMainThread:(NSArray *)filePaths;
{
    NSArray *newEntries;
    NSArray *badFilePaths;

    newEntries = [self _addFilesToLibrary:filePaths returningBadFiles:&badFilePaths];
    [self synchronizeLibrary];
    [self _selectAndScrollToEntries:newEntries];

    if ([badFilePaths count] > 0)
        [self _showErrorMessageForBadFiles:badFilePaths];
}

- (void)_showErrorMessageForBadFiles:(NSArray *)badFilePaths;
{
    unsigned int badFileCount;
    NSString *message;

    badFileCount = [badFilePaths count];
    OBASSERT(badFileCount > 0);

    if (badFileCount == 1)
        message = @"No SysEx data could be found in this file. It has not been added to the library.";
    else
        message = [NSString stringWithFormat:@"No SysEx data could be found in %u of the files. They have not been added to the library.", badFileCount];
    
    NSBeginInformationalAlertSheet(@"Could not read SysEx", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"%@", message);    
}

- (void)_sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    // At this point, we don't really care how this sheet ended
    [sheet orderOut:nil];
}

- (void)_updateSysExReadIndicator;
{
    unsigned int messageCount, bytesRead, totalBytesRead;

    [midiController getMessageCount:&messageCount bytesRead:&bytesRead totalBytesRead:&totalBytesRead];

    if ([[self window] attachedSheet] == recordSheetWindow)
        [self _updateSingleSysExReadIndicatorWithMessageCount:messageCount bytesRead:bytesRead totalBytesRead:totalBytesRead];
    else
        [self _updateMultipleSysExReadIndicatorWithMessageCount:messageCount bytesRead:bytesRead totalBytesRead:totalBytesRead];

    [progressUpdateEvent release];
    progressUpdateEvent = nil;
}

- (void)_updateSingleSysExReadIndicatorWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;
{
    if ((bytesRead == 0 && messageCount == 0)) {
        [recordProgressMessageField setStringValue:@"Waiting for SysEx message..."];
        [recordProgressBytesField setStringValue:@""];
    } else {
        [recordProgressIndicator animate:nil];
        [recordProgressMessageField setStringValue:@"Receiving SysEx message..."];
        [recordProgressBytesField setStringValue:[NSString abbreviatedStringForBytes:bytesRead + totalBytesRead]];
    }
}

- (void)_updateMultipleSysExReadIndicatorWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;
{
    NSString *totalProgress;
    BOOL hasAtLeastOneCompleteMessage;

    if (bytesRead == 0) {
        [recordMultipleProgressMessageField setStringValue:@"Waiting for SysEx message..."];
        [recordMultipleProgressBytesField setStringValue:@""];
    } else {
        [recordMultipleProgressIndicator animate:nil];
        [recordMultipleProgressMessageField setStringValue:@"Receiving SysEx message..."];
        [recordMultipleProgressBytesField setStringValue:[NSString abbreviatedStringForBytes:bytesRead]];
    }

    hasAtLeastOneCompleteMessage = (messageCount > 0);
    if (hasAtLeastOneCompleteMessage) {
        totalProgress = [NSString stringWithFormat:@"Total: %u message%@, %@", messageCount, (messageCount > 1) ? @"s" : @"", [NSString abbreviatedStringForBytes:totalBytesRead]];
    } else {
        totalProgress = @"";
    }

    [recordMultipleTotalProgressField setStringValue:totalProgress];
    [recordMultipleDoneButton setEnabled:hasAtLeastOneCompleteMessage];
}

- (void)_playSelectedEntries;
{
    NSArray *selectedEntries;
    NSMutableArray *messages;
    unsigned int entryCount, entryIndex;

    selectedEntries = [self _selectedEntries];
        
    messages = [NSMutableArray array];
    entryCount = [selectedEntries count];
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        [messages addObjectsFromArray:[[selectedEntries objectAtIndex:entryIndex] messages]];
    }

    [midiController setMessages:messages];
    [midiController sendMessages];
}

- (void)_updatePlayProgressAndRepeat;
{
    [self _updatePlayProgress];

    [progressUpdateEvent release];
    progressUpdateEvent = [[[OFScheduler mainScheduler] scheduleSelector:@selector(_updatePlayProgressAndRepeat) onObject:self afterTime:[playProgressIndicator animationDelay]] retain];
}

- (void)_updatePlayProgress;
{
    unsigned int messageIndex, messageCount, bytesToSend, bytesSent;
    NSString *message;

    [midiController getMessageCount:&messageCount messageIndex:&messageIndex bytesToSend:&bytesToSend bytesSent:&bytesSent];

    OBASSERT(bytesSent >= [playProgressIndicator doubleValue]);
        // Make sure we don't go backwards somehow
        
    [playProgressIndicator setDoubleValue:bytesSent];
    [playProgressBytesField setStringValue:[NSString abbreviatedStringForBytes:bytesSent]];
    if (bytesSent < bytesToSend) {
        if (messageCount > 1)
            message = [NSString stringWithFormat:@"Sending message %u of %u...", messageIndex+1, messageCount];
        else
            message = @"Sending message...";
    } else {
        message = @"Done.";
    }
    [playProgressMessageField setStringValue:message];
}

- (void)_showDetailsOfSelectedEntries;
{
    NSArray *selectedEntries;
    unsigned int entryCount, entryIndex;

    selectedEntries = [self _selectedEntries];
    entryCount = [selectedEntries count];
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        SSELibraryEntry *entry;

        entry = [selectedEntries objectAtIndex:entryIndex];
        [[SSEDetailsWindowController detailsWindowControllerWithEntry:entry] showWindow:nil];
    }
}

- (BOOL)_areAnyFilesAcceptable:(NSArray *)filePaths;
{
    NSFileManager *fileManager;
    unsigned int fileIndex, fileCount;

    fileManager = [NSFileManager defaultManager];

    fileCount = [filePaths count];
    for (fileIndex = 0; fileIndex < fileCount; fileIndex++) {
        NSString *filePath;
        BOOL isDirectory;

        filePath = [filePaths objectAtIndex:fileIndex];
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDirectory] == NO)
            continue;

        if (isDirectory)
            return YES;

        if ([fileManager isReadableFileAtPath:filePath] && [library typeOfFileAtPath:filePath] != SSELibraryFileTypeUnknown)
            return YES;
    }

    return NO;
}

- (BOOL)_areAnyFilesDirectories:(NSArray *)filePaths;
{
    NSFileManager *fileManager;
    unsigned int fileIndex, fileCount;

    fileManager = [NSFileManager defaultManager];

    fileCount = [filePaths count];
    for (fileIndex = 0; fileIndex < fileCount; fileIndex++) {
        NSString *filePath;
        BOOL isDirectory;

        filePath = [filePaths objectAtIndex:fileIndex];
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDirectory] == NO)
            continue;

        if (isDirectory)
            return YES;
    }

    return NO;
}

- (void)_importFilesShowingProgress:(NSArray *)filePaths;
{
    importFilePath = nil;
    importFileIndex = 0;
    importFileCount = 0;
    importCancelled = NO;

    [self _showImportSheet];

    [NSThread detachNewThreadSelector:@selector(_workThreadImportFiles:) toTarget:self withObject:filePaths];
}

- (void)_workThreadImportFiles:(NSArray *)filePaths;
{
    NSAutoreleasePool *pool;
    NSArray *addedEntries = nil;
    NSArray *badFilePaths;

    pool = [[NSAutoreleasePool alloc] init];
    
    filePaths = [self _workThreadExpandAndFilterDraggedFiles:filePaths];
    if ([filePaths count] > 0)
        addedEntries = [self _addFilesToLibrary:filePaths returningBadFiles:&badFilePaths];

    [self mainThreadPerformSelector:@selector(_doneImportingInWorkThreadWithAddedEntries:badFiles:) withObject:addedEntries withObject:badFilePaths];

    [pool release];
}

- (NSArray *)_workThreadExpandAndFilterDraggedFiles:(NSArray *)filePaths;
{
    NSFileManager *fileManager;
    unsigned int fileIndex, fileCount;
    NSMutableArray *acceptableFilePaths;

    fileManager = [NSFileManager defaultManager];
    
    fileCount = [filePaths count];
    acceptableFilePaths = [NSMutableArray arrayWithCapacity:fileCount];
    for (fileIndex = 0; fileIndex < fileCount; fileIndex++) {
        NSString *filePath;
        BOOL isDirectory;
        NSAutoreleasePool *pool;

        if (importCancelled) {
            [acceptableFilePaths removeAllObjects];
            break;
        }

        filePath = [filePaths objectAtIndex:fileIndex];
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDirectory] == NO)
            continue;
        
        pool = [[NSAutoreleasePool alloc] init];

        if (isDirectory) {
            // Handle this directory's contents recursively            
            NSArray *children;
            unsigned int childIndex, childCount;
            NSMutableArray *fullChildPaths;
            NSArray *acceptableChildren;
            
            children = [fileManager directoryContentsAtPath:filePath];
            childCount = [children count];
            fullChildPaths = [NSMutableArray arrayWithCapacity:childCount];
            for (childIndex = 0; childIndex < childCount; childIndex++) {
                NSString *childPath;

                childPath = [filePath stringByAppendingPathComponent:[children objectAtIndex:childIndex]];
                [fullChildPaths addObject:childPath];
            }

            acceptableChildren = [self _workThreadExpandAndFilterDraggedFiles:fullChildPaths];
            [acceptableFilePaths addObjectsFromArray:acceptableChildren];            
        } else {
            if ([fileManager isReadableFileAtPath:filePath] && [library typeOfFileAtPath:filePath] != SSELibraryFileTypeUnknown) {
                [acceptableFilePaths addObject:filePath];
            }
        }

        [pool release];
    }
    
    return acceptableFilePaths;
}

- (NSArray *)_addFilesToLibrary:(NSArray *)filePaths returningBadFiles:(NSArray **)badFilePathsPtr;
{
    // NOTE: This may be happening in the main thread or a work thread.

    NSArray *existingEntries;
    unsigned int fileIndex, fileCount;
    NSMutableArray *addedEntries;
    NSMutableArray *badFilePaths = nil;

    if (badFilePathsPtr)
        badFilePaths = [NSMutableArray array];
    
    // Find the files which are already in the library, and pull them out.
    existingEntries = [library findEntriesForFiles:filePaths returningNonMatchingFiles:&filePaths];

    // Try to add each file to the library, keeping track of the successful ones.
    addedEntries = [NSMutableArray array];
    fileCount = [filePaths count];
    for (fileIndex = 0; fileIndex < fileCount; fileIndex++) {
        NSAutoreleasePool *pool;
        NSString *filePath;
        SSELibraryEntry *addedEntry;

        pool = [[NSAutoreleasePool alloc] init];

        filePath = [filePaths objectAtIndex:fileIndex];

        if (![NSThread inMainThread]) {
            [importStatusLock lock];
            [importFilePath release];
            importFilePath = [filePath retain];
            importFileIndex = fileIndex;
            importFileCount = fileCount;
            [importStatusLock unlock];

            if (importCancelled) {
                [pool release];
                break;
            }
    
            [self mainThreadPerformSelectorOnce:@selector(_updateImportStatusDisplay)];
        }

        addedEntry = [library addEntryForFile:filePath];
        if (addedEntry)
            [addedEntries addObject:addedEntry];
        else
            [badFilePaths addObject:filePath];

        [pool release];
    }

    if (badFilePathsPtr)
        *badFilePathsPtr = badFilePaths;

    return [addedEntries arrayByAddingObjectsFromArray:existingEntries];
}

- (void)_showImportSheet;
{
    [self _updateImportStatusDisplay];

    // Bring the application and window to the front, so the sheet doesn't cause the dock to bounce our icon
    // TODO Does this actually work correctly? It seems to be getting delayed...
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[self window] makeKeyAndOrderFront:nil];
    
    [[NSApplication sharedApplication] beginSheet:importSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)_updateImportStatusDisplay;
{
    NSString *filePath;
    unsigned int fileIndex, fileCount;
    
    [importStatusLock lock];
    filePath = [[importFilePath retain] autorelease];
    fileIndex = importFileIndex;
    fileCount = importFileCount;
    [importStatusLock unlock];

    if (fileCount == 0) {
        [importProgressIndicator setIndeterminate:YES];
        [importProgressIndicator setUsesThreadedAnimation:YES];
        [importProgressIndicator startAnimation:nil];
        [importProgressMessageField setStringValue:@"Scanning..."];
        [importProgressIndexField setStringValue:@""];
    } else {
        if ([importProgressIndicator isIndeterminate]) {
            [importProgressIndicator setIndeterminate:NO];
            [importProgressIndicator setMaxValue:fileCount];
        }
        [importProgressIndicator setDoubleValue:fileIndex + 1];
        [importProgressMessageField setStringValue:[[NSFileManager defaultManager] displayNameAtPath:filePath]];
        [importProgressIndexField setStringValue:[NSString stringWithFormat:@"%u of %u", fileIndex + 1, fileCount]];
    }
}

- (void)_doneImportingInWorkThreadWithAddedEntries:(NSArray *)addedEntries badFiles:(NSArray *)badFilePaths;
{
    if ([[self window] attachedSheet])
        [[NSApplication sharedApplication] endSheet:importSheetWindow];

    [self synchronizeInterface];
    [self _selectAndScrollToEntries:addedEntries];

    if ([badFilePaths count] > 0)
        [self _showErrorMessageForBadFiles:badFilePaths];
}

- (void)_findMissingFilesAndPerformSelector:(SEL)selector;
{
    // Ask the user to find each missing file.
    // If we go through them all successfully, perform the selector on ourself.
    // If we cancel at any point of the process, don't do anything.

    if (!entriesWithMissingFiles) {
        NSArray *selectedEntries;
        unsigned int entryCount, entryIndex;

        selectedEntries = [self _selectedEntries];

        // Which entries can't find their associated file?
        entryCount = [selectedEntries count];
        [entriesWithMissingFiles release];
        entriesWithMissingFiles = [[NSMutableArray alloc] initWithCapacity:entryCount];
        for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
            SSELibraryEntry *entry;

            entry = [selectedEntries objectAtIndex:entryIndex];
            if (![entry isFilePresentIgnoringCachedValue])
                [entriesWithMissingFiles addObject:entry];
        }
    }

    if ([entriesWithMissingFiles count] == 0) {
        [self performSelector:selector];
        [entriesWithMissingFiles release];
        entriesWithMissingFiles = nil;
    } else {
        SSELibraryEntry *entry;

        entry = [entriesWithMissingFiles objectAtIndex:0];

        NSBeginAlertSheet(@"Missing File", @"Yes", @"Cancel", nil, [self window], self, @selector(_missingFileAlertDidEnd:returnCode:contextInfo:), NULL, selector, @"The file for the item \"%@\" could not be found. Would you like to locate it?", [entry name]);
    }
}

- (void)_missingFileAlertDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSAlertDefaultReturn) {
        // Get this sheet out of the way before we open another one
        [sheet orderOut:nil];

        // Try to locate the file
        [self _runOpenSheetForMissingFileWithContextInfo:contextInfo];
    } else {
        // Cancel the whole _findMissingFilesAndPerformSelector: process
        [entriesWithMissingFiles release];
        entriesWithMissingFiles = nil;
    }
}

- (void)_runOpenSheetForMissingFileWithContextInfo:(void *)contextInfo;
{
    NSOpenPanel *openPanel;

    openPanel = [NSOpenPanel openPanel];
    [openPanel beginSheetForDirectory:nil file:nil types:[library allowedFileTypes] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_findMissingFileOpenPanelDidEnd:returnCode:contextInfo:) contextInfo:contextInfo];
}

- (void)_findMissingFileOpenPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    BOOL cancelled = NO;

    if (returnCode != NSOKButton) {
        cancelled = YES;
    } else {
        SSELibraryEntry *entry;
        NSString *filePath;
        NSArray *matchingEntries;

        OBASSERT([entriesWithMissingFiles count] > 0);
        entry = [entriesWithMissingFiles objectAtIndex:0];        

        filePath = [[openPanel filenames] objectAtIndex:0];

        // Is this file in use by any entries?  (It might be in use by *this* entry if the file has gotten put in place again!)
        matchingEntries = [library findEntriesForFiles:[NSArray arrayWithObject:filePath] returningNonMatchingFiles:NULL];
        if ([matchingEntries count] > 0 && [matchingEntries indexOfObject:entry] == NSNotFound) {
            int returnCode2;

            returnCode2 = NSRunAlertPanel(@"In Use", @"That file is already in the library. Please choose another one.", @"OK", @"Cancel", nil);
            [openPanel orderOut:nil];
            if (returnCode2 == NSAlertDefaultReturn) {
                // Run the open sheet again
                [self _runOpenSheetForMissingFileWithContextInfo:contextInfo];
            } else {
                // Cancel out of the whole process
                cancelled = YES;
            }

        } else {
            [openPanel orderOut:nil];
            
            [entry setPath:filePath];
            [entry setNameFromFile];
    
            [entriesWithMissingFiles removeObjectAtIndex:0];
    
            // Go on to the next file (if any)
            [self _findMissingFilesAndPerformSelector:(SEL)contextInfo];
        }
    }

    if (cancelled) {
        // Cancel the whole _findMissingFilesAndPerformSelector: process
        [entriesWithMissingFiles release];
        entriesWithMissingFiles = nil;
    }
}

- (void)_deleteWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:nil];
    if (returnCode == NSOKButton) {
        if ([doNotWarnOnDeleteAgainCheckbox intValue] == 1)
            [[OFPreference preferenceForKey:SSEShowWarningOnDeletePreferenceKey] setBoolValue:NO];

        [self _deleteStep2];
    }
}

- (void)_deleteStep2;
{
    NSArray *selectedEntries;
    unsigned int entryIndex;
    BOOL areAnyFilesInLibraryDirectory = NO;

    selectedEntries = [self _selectedEntries];
    entryIndex = [selectedEntries count];
    while (entryIndex--) {
        if ([[selectedEntries objectAtIndex:entryIndex] isFileInLibraryFileDirectory]) {
            areAnyFilesInLibraryDirectory = YES;
            break;
        }
    }

    if (areAnyFilesInLibraryDirectory) {
        [[NSApplication sharedApplication] beginSheet:deleteLibraryFilesWarningSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_deleteLibraryFilesWarningSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    } else {
        [self _deleteSelectedEntriesMovingLibraryFilesToTrash:NO];
    }
}

- (void)_deleteLibraryFilesWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:nil];
    if (returnCode == NSAlertDefaultReturn) {
        // "Yes" button
        [self _deleteSelectedEntriesMovingLibraryFilesToTrash:YES];
    } else if (returnCode == NSAlertAlternateReturn) {
        // "No" button
        [self _deleteSelectedEntriesMovingLibraryFilesToTrash:NO];
    }
}

- (void)_deleteSelectedEntriesMovingLibraryFilesToTrash:(BOOL)shouldMoveToTrash;
{
    NSArray *entriesToRemove;

    entriesToRemove = [self _selectedEntries];

    if (shouldMoveToTrash)
        [library moveFilesInLibraryDirectoryToTrashForEntries:entriesToRemove];
    [library removeEntries:entriesToRemove];

    [libraryTableView deselectAll:nil];
    [self synchronizeInterface];
}

@end
