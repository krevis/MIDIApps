#import "SSEFindMissingController.h"

#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSEMainWindowController.h"
#import "SSELibrary.h"
#import "SSELibraryEntry.h"


@interface SSEFindMissingController (Private)

- (void)findNextMissingFile;
- (void)missingFileAlertDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)runOpenSheetForMissingFile;
- (void)findMissingFileOpenPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


@implementation SSEFindMissingController

- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController library:(SSELibrary *)library;
{
    if (!(self = [super init]))
        return nil;

    nonretainedMainWindowController = mainWindowController;
    nonretainedLibrary = library;

    return self;
}

- (void)dealloc;
{
    [entriesWithMissingFiles release];
    entriesWithMissingFiles = nil;
    
    [super dealloc];
}

//
// API for main window controller
//

- (void)findMissingFilesForEntries:(NSArray *)entries andPerformSelectorOnWindowController:(SEL)selector;
{
    // Ask the user to find each missing file.
    // If we go through them all successfully, perform the selector on the main window controller.
    // If we cancel at any point of the process, don't do anything.

    SMAssert(entriesWithMissingFiles == nil);
    entriesWithMissingFiles = [[NSMutableArray alloc] initWithArray:entries];
    finishingSelector = selector;

    [self findNextMissingFile];
}

@end


@implementation SSEFindMissingController (Private)

- (void)findNextMissingFile;
{
    if ([entriesWithMissingFiles count] > 0) {
        SSELibraryEntry *entry;
        NSString *title, *message;
        NSString *yes, *cancel;

        entry = [entriesWithMissingFiles objectAtIndex:0];

        title = NSLocalizedStringFromTableInBundle(@"Missing File", @"SysExLibrarian", SMBundleForObject(self), "title of alert for missing file");
        message = NSLocalizedStringFromTableInBundle(@"The file for the item \"%@\" could not be found. Would you like to locate it?", @"SysExLibrarian", SMBundleForObject(self), "format of message for missing file");
        yes = NSLocalizedStringFromTableInBundle(@"Yes", @"SysExLibrarian", SMBundleForObject(self), "Yes");
        cancel = NSLocalizedStringFromTableInBundle(@"Cancel", @"SysExLibrarian", SMBundleForObject(self), "Cancel");
        
        NSBeginAlertSheet(title, yes, cancel, nil, [nonretainedMainWindowController window], self, @selector(missingFileAlertDidEnd:returnCode:contextInfo:), NULL, NULL, message, [entry name]);
    } else {
        [nonretainedMainWindowController performSelector:finishingSelector];
    }
}

- (void)missingFileAlertDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSAlertDefaultReturn) {
        // Get this sheet out of the way before we open another one
        [sheet orderOut:nil];

        // Try to locate the file
        [self runOpenSheetForMissingFile];
    } else {
        // Cancel the whole process
        [entriesWithMissingFiles release];
        entriesWithMissingFiles = nil;
    }
}

- (void)runOpenSheetForMissingFile;
{
    NSOpenPanel *openPanel;

    openPanel = [NSOpenPanel openPanel];
    [openPanel beginSheetForDirectory:nil file:nil types:[nonretainedLibrary allowedFileTypes] modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(findMissingFileOpenPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)findMissingFileOpenPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    BOOL cancelled = NO;

    if (returnCode != NSOKButton) {
        cancelled = YES;
    } else {
        SSELibraryEntry *entry;
        NSString *filePath;
        NSArray *matchingEntries;

        SMAssert([entriesWithMissingFiles count] > 0);
        entry = [entriesWithMissingFiles objectAtIndex:0];

        filePath = [[openPanel filenames] objectAtIndex:0];

        // Is this file in use by any entries?  (It might be in use by *this* entry if the file has gotten put in place again!)
        matchingEntries = [nonretainedLibrary findEntriesForFiles:[NSArray arrayWithObject:filePath] returningNonMatchingFiles:NULL];
        if ([matchingEntries count] > 0 && [matchingEntries indexOfObject:entry] == NSNotFound) {
            NSString *title, *message, *ok, *cancel;
            int returnCode2;

            title = NSLocalizedStringFromTableInBundle(@"In Use", @"SysExLibrarian", SMBundleForObject(self), "title of alert for file already in library");
            message = NSLocalizedStringFromTableInBundle(@"That file is already in the library. Please choose another one.", @"SysExLibrarian", SMBundleForObject(self), "message for file already in library");
            ok = NSLocalizedStringFromTableInBundle(@"OK", @"SysExLibrarian", SMBundleForObject(self), "OK");
            cancel = NSLocalizedStringFromTableInBundle(@"Cancel", @"SysExLibrarian", SMBundleForObject(self), "Cancel");
            
            returnCode2 = NSRunAlertPanel(title, message, ok, cancel, nil);
            [openPanel orderOut:nil];
            if (returnCode2 == NSAlertDefaultReturn) {
                // Run the open sheet again
                [self runOpenSheetForMissingFile];
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
            [self findNextMissingFile];
        }
    }

    if (cancelled) {
        // Cancel the whole process
        [entriesWithMissingFiles release];
        entriesWithMissingFiles = nil;
    }
}

@end
