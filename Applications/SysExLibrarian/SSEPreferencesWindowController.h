#import "SSEWindowController.h"

@class OFPreference;


@interface SSEPreferencesWindowController : SSEWindowController
{
    IBOutlet NSMatrix *sizeFormatMatrix;
    IBOutlet NSTextField *sysExFolderPathField;

    OFPreference *sizeFormatPreference;
}

+ (SSEPreferencesWindowController *)preferencesWindowController;

- (id)init;

- (IBAction)changeSizeFormat:(id)sender;
- (IBAction)changeSysExFolder:(id)sender;

@end

// Notifications
extern NSString *SSEDisplayPreferenceChangedNotification;
