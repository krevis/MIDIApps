#import "SSEImportController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SSEMainWindowController.h"
#import "SSELibrary.h"
#import "SSELibraryEntry.h"


@interface SSEImportController (Private)

- (BOOL)areAnyFilesDirectories:(NSArray *)filePaths;

- (void)showImportWarning;
- (void)importWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)importFiles;

- (void)importFilesShowingProgress;
- (void)importSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)updateImportStatusDisplay;

- (void)workThreadImportFiles:(NSArray *)filePaths;
- (NSArray *)workThreadExpandAndFilterFiles:(NSArray *)filePaths;
- (void)doneImportingInWorkThreadWithNewEntries:(NSArray *)newEntries badFiles:(NSArray *)badFilePaths;

- (NSArray *)addFilesToLibrary:(NSArray *)filePaths returningBadFiles:(NSArray **)badFilePathsPtr;

- (void)finishImportWithNewEntries:(NSArray *)newEntries badFiles:(NSArray *)badFilePaths;
- (void)showErrorMessageForFilesWithNoSysEx:(NSArray *)badFilePaths;

@end


@implementation SSEImportController

NSString *SSEShowWarningOnImportPreferenceKey = @"SSEShowWarningOnImport";


- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController library:(SSELibrary *)library;
{
    if (!(self = [super init]))
        return nil;

    nonretainedMainWindowController = mainWindowController;
    nonretainedLibrary = library;

    if (![NSBundle loadNibNamed:@"Import" owner:self]) {
        [self release];
        return nil;
    }

    importStatusLock = [[NSLock alloc] init];

    return self;
}

- (void)dealloc;
{
    // TODO do we need to dealloc top-level items in the nib, like the window?

    [filePathsToImport release];
    filePathsToImport = nil;
    [importStatusLock release];
    importStatusLock = nil;
    [importFilePath release];
    importFilePath = nil;
    
    [super dealloc];
}

//
// API for main window controller
//

- (void)importFiles:(NSArray *)filePaths showingProgress:(BOOL)showProgress;
{
    OBASSERT(filePathsToImport == nil);
    filePathsToImport = [filePaths retain];

    if (![self areAnyFilesDirectories:filePaths])
        showProgress = NO;

    shouldShowProgress = showProgress;

    [self showImportWarning];
}

//
// Actions
//

- (IBAction)cancelImporting:(id)sender;
{
    // No need to lock just to set a boolean
    importCancelled = YES;
}

- (IBAction)endSheetWithReturnCodeFromSenderTag:(id)sender;
{
    [NSApp endSheet:[[nonretainedMainWindowController window] attachedSheet] returnCode:[sender tag]];
}

@end


@implementation SSEImportController (Private)

- (BOOL)areAnyFilesDirectories:(NSArray *)filePaths;
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

- (void)showImportWarning;
{
    BOOL areAllFilesInLibraryDirectory = YES;
    unsigned int fileIndex;

    fileIndex = [filePathsToImport count];
    while (fileIndex--) {
        if (![nonretainedLibrary isPathInFileDirectory:[filePathsToImport objectAtIndex:fileIndex]]) {
            areAllFilesInLibraryDirectory = NO;
            break;
        }
    }

    if (areAllFilesInLibraryDirectory || [[OFPreference preferenceForKey:SSEShowWarningOnImportPreferenceKey] boolValue] == NO) {
        [self importFiles];
    } else {
        [doNotWarnOnImportAgainCheckbox setIntValue:0];
        [NSApp beginSheet:importWarningSheetWindow modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(importWarningSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    }
}

- (void)importWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:nil];

    if (returnCode == NSOKButton) {
        if ([doNotWarnOnImportAgainCheckbox intValue] == 1)
            [[OFPreference preferenceForKey:SSEShowWarningOnImportPreferenceKey] setBoolValue:NO];

        [self importFiles];
    } else {
        // Cancelled
        [filePathsToImport release];
        filePathsToImport = nil;
    }
}

- (void)importFiles;
{
    if (shouldShowProgress) {
        [self importFilesShowingProgress];
    } else {
        // Add entries immediately
        NSArray *newEntries;
        NSArray *badFilePaths;

        newEntries = [self addFilesToLibrary:filePathsToImport returningBadFiles:&badFilePaths];
        [self finishImportWithNewEntries:newEntries badFiles:badFilePaths];        
    }
}

//
// Import with progress display
// Main thread: setup, updating progress display, teardown
//

- (void)importFilesShowingProgress;
{
    NSWindow *mainWindow;

    importFilePath = nil;
    importFileIndex = 0;
    importFileCount = 0;
    importCancelled = NO;

    [self updateImportStatusDisplay];

    mainWindow = [nonretainedMainWindowController window];

    // Bring the application and window to the front, so the sheet doesn't cause the dock to bounce our icon
    // TODO Does this actually work correctly? It seems to be getting delayed...
    [NSApp activateIgnoringOtherApps:YES];
    [mainWindow makeKeyAndOrderFront:nil];

    [NSApp beginSheet:importSheetWindow modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(importSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
    
    [NSThread detachNewThreadSelector:@selector(workThreadImportFiles:) toTarget:self withObject:filePathsToImport];
}

- (void)importSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    // At this point, we don't really care how this sheet ended
    [sheet orderOut:nil];
}

- (void)updateImportStatusDisplay;
{
    NSString *filePath;
    unsigned int fileIndex, fileCount;

    [importStatusLock lock];
    filePath = [[importFilePath retain] autorelease];
    fileIndex = importFileIndex;
    fileCount = importFileCount;
    [importStatusLock unlock];

    if (fileCount == 0) {
        [progressIndicator setIndeterminate:YES];
        [progressIndicator setUsesThreadedAnimation:YES];
        [progressIndicator startAnimation:nil];
        [progressMessageField setStringValue:@"Scanning..."];
        [progressIndexField setStringValue:@""];
    } else {
        if ([progressIndicator isIndeterminate]) {
            [progressIndicator setIndeterminate:NO];
            [progressIndicator setMaxValue:fileCount];
        }
        [progressIndicator setDoubleValue:fileIndex + 1];
        [progressMessageField setStringValue:[[NSFileManager defaultManager] displayNameAtPath:filePath]];
        [progressIndexField setStringValue:[NSString stringWithFormat:@"%u of %u", fileIndex + 1, fileCount]];
    }
}

//
// Import with progress display
// Work thread: recurse through directories, filter out inappropriate files, and import
//

- (void)workThreadImportFiles:(NSArray *)filePaths;
{
    NSAutoreleasePool *pool;
    NSArray *newEntries = nil;
    NSArray *expandedAndFilteredFilePaths;
    NSArray *badFilePaths = nil;

    pool = [[NSAutoreleasePool alloc] init];
    
    expandedAndFilteredFilePaths = [self workThreadExpandAndFilterFiles:filePaths];
    if ([expandedAndFilteredFilePaths count] > 0)
        newEntries = [self addFilesToLibrary:expandedAndFilteredFilePaths returningBadFiles:&badFilePaths];

    [self mainThreadPerformSelector:@selector(doneImportingInWorkThreadWithNewEntries:badFiles:) withObject:newEntries withObject:badFilePaths];

    [pool release];
}

- (NSArray *)workThreadExpandAndFilterFiles:(NSArray *)filePaths;
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

            acceptableChildren = [self workThreadExpandAndFilterFiles:fullChildPaths];
            [acceptableFilePaths addObjectsFromArray:acceptableChildren];            
        } else {
            if ([fileManager isReadableFileAtPath:filePath] && [nonretainedLibrary typeOfFileAtPath:filePath] != SSELibraryFileTypeUnknown) {
                [acceptableFilePaths addObject:filePath];
            }
        }

        [pool release];
    }
    
    return acceptableFilePaths;
}

- (void)doneImportingInWorkThreadWithNewEntries:(NSArray *)newEntries badFiles:(NSArray *)badFilePaths;
{
    [NSApp endSheet:importSheetWindow];

    [self finishImportWithNewEntries:newEntries badFiles:badFilePaths];
}

//
// Check if each file is already in the library, and then try to add each new one
//

- (NSArray *)addFilesToLibrary:(NSArray *)filePaths returningBadFiles:(NSArray **)badFilePathsPtr;
{
    // NOTE: This may be happening in the main thread or a work thread.

    NSArray *existingEntries;
    unsigned int fileIndex, fileCount;
    NSMutableArray *addedEntries;
    NSMutableArray *badFilePaths = nil;

    if (badFilePathsPtr)
        badFilePaths = [NSMutableArray array];

    // Find the files which are already in the library, and pull them out.
    existingEntries = [nonretainedLibrary findEntriesForFiles:filePaths returningNonMatchingFiles:&filePaths];

    // Try to add each file to the library, keeping track of the successful ones.
    addedEntries = [NSMutableArray array];
    fileCount = [filePaths count];
    for (fileIndex = 0; fileIndex < fileCount; fileIndex++) {
        NSAutoreleasePool *pool;
        NSString *filePath;
        SSELibraryEntry *addedEntry;

        pool = [[NSAutoreleasePool alloc] init];

        filePath = [filePaths objectAtIndex:fileIndex];

        // If we're not in the main thread, update progress information and tell the main thread to update its UI.
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

            [self mainThreadPerformSelectorOnce:@selector(updateImportStatusDisplay)];
        }

        addedEntry = [nonretainedLibrary addEntryForFile:filePath];
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

//
// Finishing up
//

- (void)finishImportWithNewEntries:(NSArray *)newEntries badFiles:(NSArray *)badFilePaths;
{
    [nonretainedMainWindowController showNewEntries:newEntries];

    if ([badFilePaths count] > 0)
        [self showErrorMessageForFilesWithNoSysEx:badFilePaths];

    [filePathsToImport release];
    filePathsToImport = nil;
}

- (void)showErrorMessageForFilesWithNoSysEx:(NSArray *)badFilePaths;
{
    unsigned int badFileCount;
    NSString *message;

    badFileCount = [badFilePaths count];
    OBASSERT(badFileCount > 0);

    if (badFileCount == 1)
        message = @"No SysEx data could be found in this file. It has not been added to the library.";
    else
        message = [NSString stringWithFormat:@"No SysEx data could be found in %u of the files. They have not been added to the library.", badFileCount];

    OBASSERT([[nonretainedMainWindowController window] attachedSheet] == nil);
    if ([[nonretainedMainWindowController window] attachedSheet])
        return;

    NSBeginInformationalAlertSheet(@"Could not read SysEx", nil, nil, nil, [nonretainedMainWindowController window], nil, NULL, NULL, NULL, @"%@", message);
}

@end
