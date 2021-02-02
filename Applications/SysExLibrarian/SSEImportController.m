/*
 Copyright (c) 2002-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSEImportController.h"

@import SnoizeMIDI;

#import "SSEMainWindowController.h"
#import "SSELibrary.h"
#import "SSELibraryEntry.h"
#import "SSEAppController.h"


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
- (void)doneImportingInWorkThreadWithNewEntriesAndBadFiles:(NSDictionary *)dict;

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

    if (![[NSBundle mainBundle] loadNibNamed:@"Import" owner:self topLevelObjects:&topLevelObjects]) {
        [self release];
        return nil;
    }
    [topLevelObjects retain];

    importStatusLock = [[NSLock alloc] init];

    return self;
}

- (void)dealloc;
{
    [topLevelObjects release];

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
    SMAssert(filePathsToImport == nil);
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
    NSUInteger fileIndex, fileCount;

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
    NSUInteger fileIndex;

    fileIndex = [filePathsToImport count];
    while (fileIndex--) {
        if (![nonretainedLibrary isPathInFileDirectory:[filePathsToImport objectAtIndex:fileIndex]]) {
            areAllFilesInLibraryDirectory = NO;
            break;
        }
    }

    if (areAllFilesInLibraryDirectory || [[NSUserDefaults standardUserDefaults] boolForKey:SSEShowWarningOnImportPreferenceKey] == NO) {
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
            [[NSUserDefaults standardUserDefaults] setBool: NO forKey: SSEShowWarningOnImportPreferenceKey];

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
    static NSString *scanningString = nil;
    static NSString *xOfYFormatString = nil;
    NSString *filePath;
    NSUInteger fileIndex, fileCount;

    if (!scanningString)
        scanningString = [NSLocalizedStringFromTableInBundle(@"Scanning...", @"SysExLibrarian", SMBundleForObject(self), "Scanning...") retain];
    if (!xOfYFormatString)
        xOfYFormatString = [NSLocalizedStringFromTableInBundle(@"%u of %u", @"SysExLibrarian", SMBundleForObject(self), "importing sysex: x of y") retain];
    
    [importStatusLock lock];
    filePath = [[importFilePath retain] autorelease];
    fileIndex = importFileIndex;
    fileCount = importFileCount;
    [importStatusLock unlock];

    if (fileCount == 0) {
        [progressIndicator setIndeterminate:YES];
        [progressIndicator setUsesThreadedAnimation:YES];
        [progressIndicator startAnimation:nil];
        [progressMessageField setStringValue:scanningString];
        [progressIndexField setStringValue:@""];
    } else {
        if ([progressIndicator isIndeterminate]) {
            [progressIndicator setIndeterminate:NO];
            [progressIndicator setMaxValue:fileCount];
        }
        [progressIndicator setDoubleValue:fileIndex + 1];
        [progressMessageField setStringValue:[[NSFileManager defaultManager] displayNameAtPath:filePath]];
        [progressIndexField setStringValue:[NSString stringWithFormat:xOfYFormatString, fileIndex + 1, fileCount]];
    }
    
    queuedUpdate = NO;
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

    if (!newEntries)
        newEntries = (id)[NSNull null];
    if (!badFilePaths)
        badFilePaths = (id)[NSNull null];
    [self performSelectorOnMainThread:@selector(doneImportingInWorkThreadWithNewEntriesAndBadFiles:)
                           withObject:[NSDictionary dictionaryWithObjectsAndKeys:newEntries, @"newEntries", badFilePaths, @"badFiles", nil]
                        waitUntilDone:NO];

    [pool release];
}

- (NSArray *)workThreadExpandAndFilterFiles:(NSArray *)filePaths;
{
    NSFileManager *fileManager;
    NSUInteger fileIndex, fileCount;
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
            NSUInteger childIndex, childCount;
            NSMutableArray *fullChildPaths;
            NSArray *acceptableChildren;
            
            children = [fileManager contentsOfDirectoryAtPath:filePath error:NULL];
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

- (void)doneImportingInWorkThreadWithNewEntriesAndBadFiles:(NSDictionary *)dict
{
    NSArray *newEntries = [dict objectForKey:@"newEntries"];
    if (newEntries == (id)[NSNull null])
        newEntries = nil;
    NSArray *badFilePaths = [dict objectForKey:@"badFiles"];
    if (badFilePaths == (id)[NSNull null])
        badFilePaths = nil;
    
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
    NSUInteger fileIndex, fileCount;
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
        if (![(SSEAppController*)[NSApp delegate] inMainThread]) {
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

            if (!queuedUpdate) {
                [self performSelectorOnMainThread:@selector(updateImportStatusDisplay) withObject:nil waitUntilDone:NO];
                queuedUpdate = YES;
            }
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
    NSUInteger badFileCount;
    NSString *title;
    NSString *message;

    badFileCount = [badFilePaths count];
    SMAssert(badFileCount > 0);

    if (badFileCount == 1) {
        message = NSLocalizedStringFromTableInBundle(@"No SysEx data could be found in this file. It has not been added to the library.", @"SysExLibrarian", SMBundleForObject(self), "message when no sysex data found in file");
    } else {
        NSString *format;
        
        format = NSLocalizedStringFromTableInBundle(@"No SysEx data could be found in %u of the files. They have not been added to the library.", @"SysExLibrarian", SMBundleForObject(self), "format of message when no sysex data found in files");
        message = [NSString stringWithFormat:format, badFileCount];
    }

    SMAssert([[nonretainedMainWindowController window] attachedSheet] == nil);
    if ([[nonretainedMainWindowController window] attachedSheet])
        return;

    title = NSLocalizedStringFromTableInBundle(@"Could not read SysEx", @"SysExLibrarian", SMBundleForObject(self), "title of alert when can't read a sysex file");
    NSBeginInformationalAlertSheet(title, nil, nil, nil, [nonretainedMainWindowController window], nil, NULL, NULL, NULL, @"%@", message);
}

@end
