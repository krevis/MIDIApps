#import <Cocoa/Cocoa.h>


@interface SMMAppController : NSObject
{
    BOOL shouldUseMIDISpy;
    BOOL shouldOpenUntitledDocument;
}

- (IBAction)showPreferences:(id)sender;
- (IBAction)showAboutBox:(id)sender;
- (IBAction)showHelp:(id)sender;

- (IBAction)restartMIDI:(id)sender;

- (BOOL)shouldUseMIDISpy;

@end

// Preference keys
extern NSString *SMMOpenWindowsForNewSourcesPreferenceKey;
