#import <Cocoa/Cocoa.h>


@interface SMMAppController : NSObject
{
}

- (IBAction)showPreferences:(id)sender;
- (IBAction)showAboutBox:(id)sender;
- (IBAction)showHelp:(id)sender;

- (IBAction)restartMIDI:(id)sender;

@end

// Preference keys
extern NSString *SMMOpenWindowsForNewSourcesPreferenceKey;
