#import "SSEDeleteController.h"

#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSEMainWindowController.h"
#import "SSELibrary.h"
#import "SSELibraryEntry.h"

@interface SSEDeleteController (Private)

- (void)deleteWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)checkForFilesInLibraryDirectory;
- (void)deleteLibraryFilesWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)deleteEntriesMovingLibraryFilesToTrash:(BOOL)shouldMoveToTrash;

@end


@implementation SSEDeleteController

NSString *SSEShowWarningOnDeletePreferenceKey = @"SSEShowWarningOnDelete";


- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController
{
    if (!(self = [super init]))
        return nil;

    nonretainedMainWindowController = mainWindowController;

    if (![NSBundle loadNibNamed:@"Delete" owner:self]) {
        [self release];
        return nil;
    }
    
    return self;
}

- (void)dealloc;
{
    // Top-level nib objects
    [deleteWarningSheetWindow release];
    deleteWarningSheetWindow = nil;
    [deleteLibraryFilesWarningSheetWindow release];
    deleteLibraryFilesWarningSheetWindow = nil;
    
    [entriesToDelete release];
    entriesToDelete = nil;
    
    [super dealloc];
}

//
// API for main window controller
//

- (void)deleteEntries:(NSArray *)entries;
{
    if ([entries count] == 0)
        return;

    SMAssert(entriesToDelete == nil);
    entriesToDelete = [entries retain];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:SSEShowWarningOnDeletePreferenceKey]) {
        [doNotWarnOnDeleteAgainCheckbox setIntValue:0];
        [NSApp beginSheet:deleteWarningSheetWindow modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(deleteWarningSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    } else {
        [self checkForFilesInLibraryDirectory];
    }
}

//
// Actions
//

- (IBAction)endSheetWithReturnCodeFromSenderTag:(id)sender;
{
    [NSApp endSheet:[[nonretainedMainWindowController window] attachedSheet] returnCode:[sender tag]];
}

@end


@implementation SSEDeleteController (Private)

- (void)deleteWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:nil];
    
    if (returnCode == NSOKButton) {
        if ([doNotWarnOnDeleteAgainCheckbox intValue] == 1)
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:SSEShowWarningOnDeletePreferenceKey];

        [self checkForFilesInLibraryDirectory];
    } else {
        // Cancelled
        [entriesToDelete release];
        entriesToDelete = nil;
    }
}

- (void)checkForFilesInLibraryDirectory;
{
    unsigned int entryIndex;
    BOOL areAnyFilesInLibraryDirectory = NO;

    entryIndex = [entriesToDelete count];
    while (entryIndex--) {
        if ([[entriesToDelete objectAtIndex:entryIndex] isFileInLibraryFileDirectory]) {
            areAnyFilesInLibraryDirectory = YES;
            break;
        }
    }

    if (areAnyFilesInLibraryDirectory) {
        [NSApp beginSheet:deleteLibraryFilesWarningSheetWindow modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(deleteLibraryFilesWarningSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    } else {
        [self deleteEntriesMovingLibraryFilesToTrash:NO];
    }
}

- (void)deleteLibraryFilesWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:nil];

    if (returnCode == NSAlertDefaultReturn) {
        // "Yes" button
        [self deleteEntriesMovingLibraryFilesToTrash:YES];
    } else if (returnCode == NSAlertAlternateReturn) {
        // "No" button
        [self deleteEntriesMovingLibraryFilesToTrash:NO];
    } else {
        // "Cancel" button
        [entriesToDelete release];
        entriesToDelete = nil;
    }
}

- (void)deleteEntriesMovingLibraryFilesToTrash:(BOOL)shouldMoveToTrash;
{
    SSELibrary *library;

    library = [[entriesToDelete objectAtIndex:0] library];

    if (shouldMoveToTrash)
        [library moveFilesInLibraryDirectoryToTrashForEntries:entriesToDelete];
    [library removeEntries:entriesToDelete];

    [entriesToDelete release];
    entriesToDelete = nil;
    
    [nonretainedMainWindowController synchronizeInterface];
}

@end
