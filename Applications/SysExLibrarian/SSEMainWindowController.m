#import "SSEMainWindowController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "NSPopUpButton-Extensions.h"
#import "SSELibrary.h"
#import "SSELibraryEntry.h"
#import "SSEMainController.h"
#import "SSETableView.h"


@interface SSEMainWindowController (Private)

- (void)_autosaveWindowFrame;

- (void)_synchronizePopUpButton:(NSPopUpButton *)popUpButton withDescriptions:(NSArray *)descriptions currentDescription:(NSDictionary *)currentDescription;

- (void)_selectAndScrollToEntries:(NSArray *)entries;

- (void)_openPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void  *)contextInfo;

- (void)_sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)_updateSysExReadIndicator;
- (void)_updateSingleSysExReadIndicatorWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;
- (void)_updateMultipleSysExReadIndicatorWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;

- (void)_updatePlayProgressAndRepeat;
- (void)_updatePlayProgress;

- (BOOL)_areAnyDraggedFilesAcceptable:(NSArray *)filePaths;
- (void)_dragFilesIntoLibrary:(NSArray *)filePaths;

- (void)_workThreadImportFiles:(NSArray *)filePaths;
- (NSArray *)_workThreadExpandAndFilterDraggedFiles:(NSArray *)filePaths;

- (NSArray *)_addFilesToLibrary:(NSArray *)filePaths;

- (void)_showImportSheet;
- (void)_updateImportStatusDisplay;
- (void)_doneImporting:(NSArray *)addedEntries;

@end


@implementation SSEMainWindowController

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

    library = [[SSELibrary alloc] init];

    importStatusLock = [[NSLock alloc] init];

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
    
    [super dealloc];
}

- (void)awakeFromNib
{
    [[self window] setFrameAutosaveName:[self windowNibName]];
    [libraryTableView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self synchronizeInterface];
}

//
// Actions
//

- (IBAction)selectSource:(id)sender;
{
    [mainController setSourceDescription:[(NSMenuItem *)[sender selectedItem] representedObject]];
}

- (IBAction)selectDestination:(id)sender;
{
    [mainController setDestinationDescription:[(NSMenuItem *)[sender selectedItem] representedObject]];
}

- (IBAction)open:(id)sender;
{
    NSOpenPanel *openPanel;

    openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:YES];

    [openPanel beginSheetForDirectory:nil file:nil types:[library allowedFileTypes] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)delete:(id)sender;
{
    // TODO
    // should we have a confirmation dialog?
    // ask whether to delete the file or just the reference? (see how Project Builder or iTunes do it)

    NSEnumerator *selectedRowEnumerator;
    NSNumber *rowNumber;
    NSMutableArray *entriesToRemove;
    unsigned int entryIndex;

    entriesToRemove = [NSMutableArray array];
    selectedRowEnumerator = [libraryTableView selectedRowEnumerator];
    while ((rowNumber = [selectedRowEnumerator nextObject])) {
        SSELibraryEntry *entry;

        entry = [[library entries] objectAtIndex:[rowNumber intValue]];
        [entriesToRemove addObject:entry];
    }

    entryIndex = [entriesToRemove count];
    while (entryIndex--) {
        [library removeEntry:[entriesToRemove objectAtIndex:entryIndex]];
    }

    [libraryTableView deselectAll:nil];
    [self synchronizeInterface];
}

- (IBAction)recordOne:(id)sender;
{
    [self _updateSingleSysExReadIndicatorWithMessageCount:0 bytesRead:0 totalBytesRead:0];

    [[NSApplication sharedApplication] beginSheet:recordSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];    

    [mainController listenForOneMessage];
}

- (IBAction)recordMultiple:(id)sender;
{
    [self _updateMultipleSysExReadIndicatorWithMessageCount:0 bytesRead:0 totalBytesRead:0];

    [[NSApplication sharedApplication] beginSheet:recordMultipleSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];

    [mainController listenForMultipleMessages];
}

- (IBAction)play:(id)sender;
{
    NSEnumerator *selectedRowEnumerator;
    NSNumber *rowNumber;
    NSArray *messages = nil;

    selectedRowEnumerator = [libraryTableView selectedRowEnumerator];
    while ((rowNumber = [selectedRowEnumerator nextObject])) {
        NSArray *entryMessages;

        entryMessages = [[[library entries] objectAtIndex:[rowNumber intValue]] messages];
        if (messages)
            messages = [messages arrayByAddingObjectsFromArray:entryMessages];
        else
            messages = entryMessages;
    }

    [mainController setMessages:messages];
    [mainController sendMessages];
}

- (IBAction)cancelRecordSheet:(id)sender;
{
    [mainController cancelMessageListen];
    [[NSApplication sharedApplication] endSheet:[[self window] attachedSheet]];
}

- (IBAction)doneWithRecordMultipleSheet:(id)sender;
{
    [mainController doneWithMultipleMessageListen];
    [[NSApplication sharedApplication] endSheet:recordMultipleSheetWindow];
    [self addReadMessagesToLibrary];
}

- (IBAction)cancelPlaySheet:(id)sender;
{
    [mainController cancelSendingMessages];
    // -hideSysExSendStatusWithSuccess: will get called soon; it will end the sheet
}

- (IBAction)cancelImportSheet:(id)sender;
{
    // No need to lock just to set a boolean
    importCancelled = YES;
}

//
// Other API
//

- (void)synchronizeInterface;
{
    [self synchronizeSources];
    [self synchronizeDestinations];
    [self synchronizeLibrary];
    [self synchronizePlayButton];
    [self synchronizeDeleteButton];
}

- (void)synchronizeSources;
{
    [self _synchronizePopUpButton:sourcePopUpButton withDescriptions:[mainController sourceDescriptions] currentDescription:[mainController sourceDescription]];
}

- (void)synchronizeDestinations;
{
    [self _synchronizePopUpButton:destinationPopUpButton withDescriptions:[mainController destinationDescriptions] currentDescription:[mainController destinationDescription]];
}

- (void)synchronizeLibrary;
{
    // TODO may need code to keep selection
    [libraryTableView reloadData];
}

- (void)synchronizePlayButton;
{
    [playButton setEnabled:([libraryTableView numberOfSelectedRows] > 0)];
}

- (void)synchronizeDeleteButton;
{
    [deleteButton setEnabled:([libraryTableView numberOfSelectedRows] > 0)];
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
    [[NSApplication sharedApplication] performSelector:@selector(endSheet:) withObject:[[self window] attachedSheet] afterDelay:0.5];
}

- (void)addReadMessagesToLibrary;
{
    NSData *allSysexData;

    allSysexData = [SMSystemExclusiveMessage dataForSystemExclusiveMessages:[mainController messages]];
    if (allSysexData) {
        SSELibraryEntry *entry;

        entry = [library addNewEntryWithData:allSysexData];
        [self synchronizeLibrary];
        [self _selectAndScrollToEntries:[NSArray arrayWithObject:entry]];
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
    [mainController getMessageCount:NULL messageIndex:NULL bytesToSend:&bytesToSend bytesSent:NULL];
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
    
    if (!success) {
        [playProgressMessageField setStringValue:@"Cancelled."];
            // TODO localize
    }

    // Even if we have set the progress indicator to its maximum value, it won't get drawn on the screen that way immediately,
    // probably because it tries to smoothly animate to that state. The only way I have found to show the maximum value is to just
    // wait a little while for the animation to finish. This looks nice, too.
    [[NSApplication sharedApplication] performSelector:@selector(endSheet:) withObject:playSheetWindow afterDelay:0.5];    
}

@end


@implementation SSEMainWindowController (NotificationsDelegatesDataSources)

//
// Window delegate
//

- (void)windowDidResize:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

- (void)windowDidMove:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

//
// NSTableView data source
//

- (int)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [[library entries] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    SSELibraryEntry *entry;
    NSString *identifier;

    entry = [[library entries] objectAtIndex:row];
    identifier = [tableColumn identifier];

    if ([identifier isEqualToString:@"name"])
        return [entry name];
    else if ([identifier isEqualToString:@"manufacturer"])
        return [entry manufacturerName];
    else if ([identifier isEqualToString:@"size"])
//        return [NSNumber numberWithUnsignedInt:[entry size]];   // TODO make a pref for showing abbreviated vs. full bytes
        return [NSString abbreviatedStringForBytes:[entry size]];
    else if ([identifier isEqualToString:@"messageCount"])
        return [NSNumber numberWithUnsignedInt:[entry messageCount]];
    else
        return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    SSELibraryEntry *entry;

    entry = [[library entries] objectAtIndex:row];
    if ([object isKindOfClass:[NSString class]])
        [entry setName:object];

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
    if ([self _areAnyDraggedFilesAcceptable:[[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType]])
        return NSDragOperationGeneric;
    else
        return NSDragOperationNone;
}

- (BOOL)tableView:(SSETableView *)tableView performDragOperation:(id <NSDraggingInfo>)sender;
{
    [self _dragFilesIntoLibrary:[[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType]];
    return YES;
}

//
// NSTableView delegate
//

- (void)tableViewSelectionDidChange:(NSNotification *)notification;
{
    [self synchronizePlayButton];
    [self synchronizeDeleteButton];
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    if ([[tableColumn identifier] isEqualToString:@"name"]) {
        SSELibraryEntry *entry;
        NSColor *color;
        
        entry = [[library entries] objectAtIndex:row];
        color = [entry isFilePresent] ? [NSColor blackColor] : [NSColor redColor];
        [cell setTextColor:color];
    }
}

@end


@implementation SSEMainWindowController (Private)

- (void)_autosaveWindowFrame;
{
    // Work around an AppKit bug: the frame that gets saved in NSUserDefaults is the window's old position, not the new one.
    // We get notified after the window has been moved/resized and the defaults changed.

    NSWindow *window;
    NSString *autosaveName;

    window = [self window];
    // Sometimes we get called before the window's autosave name is set (when the nib is loading), so check that.
    if ((autosaveName = [window frameAutosaveName])) {
        [window saveFrameUsingName:autosaveName];
        [[NSUserDefaults standardUserDefaults] autoSynchronize];
    }
}

- (void)_synchronizePopUpButton:(NSPopUpButton *)popUpButton withDescriptions:(NSArray *)descriptions currentDescription:(NSDictionary *)currentDescription;
{
    BOOL wasAutodisplay;
    unsigned int count, index;
    BOOL found = NO;
    BOOL addedSeparatorBetweenPortAndVirtual = NO;

    // The pop up button redraws whenever it's changed, so turn off autodisplay to stop the blinkiness
    wasAutodisplay = [[self window] isAutodisplay];
    [[self window] setAutodisplay:NO];

    [popUpButton removeAllItems];

    count = [descriptions count];
    for (index = 0; index < count; index++) {
        NSDictionary *description;

        description = [descriptions objectAtIndex:index];
        if (!addedSeparatorBetweenPortAndVirtual && [description objectForKey:@"endpoint"] == nil) {
            if (index > 0)
                [popUpButton addSeparatorItem];
            addedSeparatorBetweenPortAndVirtual = YES;
        }
        [popUpButton addItemWithTitle:[description objectForKey:@"name"] representedObject:description];

        if (!found && [description isEqual:currentDescription]) {
            [popUpButton selectItemAtIndex:[popUpButton numberOfItems] - 1];
            // Don't use index because it may be off by one (because of the separator item)
            found = YES;
        }
    }

    if (!found)
        [popUpButton selectItem:nil];

    // ...and turn autodisplay on again
    if (wasAutodisplay)
        [[self window] displayIfNeeded];
    [[self window] setAutodisplay:wasAutodisplay];
}

- (void)_selectAndScrollToEntries:(NSArray *)entries;
{
    unsigned int entryCount, entryIndex;
    NSArray *allEntries;

    entryCount = [entries count];
    allEntries = [library entries];

    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        unsigned int row;

        row = [allEntries indexOfObjectIdenticalTo:[entries objectAtIndex:entryIndex]];

        if (entryIndex == 0) {
            [libraryTableView selectRow:row byExtendingSelection:NO];
            [libraryTableView scrollRowToVisible:row];
        } else {
            [libraryTableView selectRow:row byExtendingSelection:YES];
        }
    }
}

- (void)_openPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void  *)contextInfo;
{
    if (returnCode == NSOKButton)
        [self _addFilesToLibrary:[openPanel filenames]];
}

- (void)_sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    // At this point, we don't really care how this sheet ended
    [sheet orderOut:nil];
}

- (void)_updateSysExReadIndicator;
{
    unsigned int messageCount, bytesRead, totalBytesRead;

    [mainController getMessageCount:&messageCount bytesRead:&bytesRead totalBytesRead:&totalBytesRead];

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
        [recordProgressMessageField setStringValue:@"Waiting for SysEx message..."]; // TODO localize
        [recordProgressBytesField setStringValue:@""];
    } else {
        [recordProgressIndicator animate:nil];
        [recordProgressMessageField setStringValue:@"Receiving SysEx message..."];	// TODO localize
        [recordProgressBytesField setStringValue:[NSString abbreviatedStringForBytes:bytesRead + totalBytesRead]];
    }
}

- (void)_updateMultipleSysExReadIndicatorWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;
{
    NSString *totalProgress;
    BOOL hasAtLeastOneCompleteMessage;

    if (bytesRead == 0) {
        [recordMultipleProgressMessageField setStringValue:@"Waiting for SysEx message..."]; 	// TODO localize
        [recordMultipleProgressBytesField setStringValue:@""];
    } else {
        [recordMultipleProgressIndicator animate:nil];
        [recordMultipleProgressMessageField setStringValue:@"Receiving SysEx message..."]; 	// TODO localize
        [recordMultipleProgressBytesField setStringValue:[NSString abbreviatedStringForBytes:bytesRead]];
    }

    hasAtLeastOneCompleteMessage = (messageCount > 0);
    if (hasAtLeastOneCompleteMessage) {
        totalProgress = [NSString stringWithFormat:@"Total: %u message%@, %@", messageCount, (messageCount > 1) ? @"s" : @"", [NSString abbreviatedStringForBytes:totalBytesRead]];
        // TODO localize -- the "s" vs "" trick will have to change
    } else {
        totalProgress = @"";
    }

    [recordMultipleTotalProgressField setStringValue:totalProgress];
    [recordMultipleDoneButton setEnabled:hasAtLeastOneCompleteMessage];
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

    [mainController getMessageCount:&messageCount messageIndex:&messageIndex bytesToSend:&bytesToSend bytesSent:&bytesSent];

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
        // TODO localize all of the above
    [playProgressMessageField setStringValue:message];
}

- (BOOL)_areAnyDraggedFilesAcceptable:(NSArray *)filePaths;
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

- (void)_dragFilesIntoLibrary:(NSArray *)filePaths;
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

    pool = [[NSAutoreleasePool alloc] init];
    
    filePaths = [self _workThreadExpandAndFilterDraggedFiles:filePaths];
    if ([filePaths count] > 0)
        addedEntries = [self _addFilesToLibrary:filePaths];

    [self mainThreadPerformSelector:@selector(_doneImporting:) withObject:addedEntries];

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

- (NSArray *)_addFilesToLibrary:(NSArray *)filePaths;
{
    // NOTE: This may be happening in the main thread or a work thread.
    
    unsigned int fileIndex, fileCount;
    NSMutableArray *addedEntries;

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

        [pool release];
    }

    return addedEntries;
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
        [importProgressMessageField setStringValue:@"Scanning..."];	// TODO localize
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
     
- (void)_doneImporting:(NSArray *)addedEntries;
{
    if ([[self window] attachedSheet])
        [[NSApplication sharedApplication] endSheet:importSheetWindow];

    [self synchronizeInterface];
    [self _selectAndScrollToEntries:addedEntries];
}

@end
