#import "SSEFindMissingController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

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

    OBASSERT(entriesWithMissingFiles == nil);
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

        entry = [entriesWithMissingFiles objectAtIndex:0];
        NSBeginAlertSheet(@"Missing File", @"Yes", @"Cancel", nil, [nonretainedMainWindowController window], self, @selector(missingFileAlertDidEnd:returnCode:contextInfo:), NULL, NULL, @"The file for the item \"%@\" could not be found. Would you like to locate it?", [entry name]);
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

        OBASSERT([entriesWithMissingFiles count] > 0);
        entry = [entriesWithMissingFiles objectAtIndex:0];

        filePath = [[openPanel filenames] objectAtIndex:0];

        // Is this file in use by any entries?  (It might be in use by *this* entry if the file has gotten put in place again!)
        matchingEntries = [nonretainedLibrary findEntriesForFiles:[NSArray arrayWithObject:filePath] returningNonMatchingFiles:NULL];
        if ([matchingEntries count] > 0 && [matchingEntries indexOfObject:entry] == NSNotFound) {
            int returnCode2;

            returnCode2 = NSRunAlertPanel(@"In Use", @"That file is already in the library. Please choose another one.", @"OK", @"Cancel", nil);
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
