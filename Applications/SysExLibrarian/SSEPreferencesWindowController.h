#import "SSEWindowController.h"

@class OFPreference;


@interface SSEPreferencesWindowController : SSEWindowController
{
    IBOutlet NSMatrix *sizeFormatMatrix;

    OFPreference *sizeFormatPreference;
}

+ (SSEPreferencesWindowController *)preferencesWindowController;

- (id)init;

- (IBAction)changeSizeFormat:(id)sender;

@end

// Notifications
extern NSString *SSEDisplayPreferenceChangedNotification;
