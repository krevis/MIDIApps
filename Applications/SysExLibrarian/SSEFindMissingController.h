#import <Cocoa/Cocoa.h>

@class SSELibrary;
@class SSEMainWindowController;

@interface SSEFindMissingController : NSObject
{
    SSEMainWindowController *nonretainedMainWindowController;
    SSELibrary *nonretainedLibrary;

    NSMutableArray *entriesWithMissingFiles;
    SEL finishingSelector;
}

- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController library:(SSELibrary *)library;

// Main window controller sends this to begin the process
- (void)findMissingFilesForEntries:(NSArray *)entries andPerformSelectorOnWindowController:(SEL)selector;

@end
