#import <Cocoa/Cocoa.h>


@interface SSEAppController : NSObject
{
    BOOL hasFinishedLaunching;
    NSMutableArray *filesToImport;
}

- (IBAction)showPreferences:(id)sender;
- (IBAction)showAboutBox:(id)sender;
- (IBAction)showHelp:(id)sender;
- (IBAction)showMainWindow:(id)sender;
- (IBAction)showMainWindowAndAddToLibrary:(id)sender;

@end
