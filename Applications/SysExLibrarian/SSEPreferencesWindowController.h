#import "SSEWindowController.h"

@class OFPreference;


@interface SSEPreferencesWindowController : SSEWindowController
{
    IBOutlet NSMatrix *sizeFormatMatrix;
    IBOutlet NSTextField *sysExFolderPathField;
    IBOutlet NSSlider *sysExReadTimeOutSlider;
    IBOutlet NSTextField *sysExReadTimeOutField;
    IBOutlet NSSlider *sysExIntervalBetweenSentMessagesSlider;
    IBOutlet NSTextField *sysExIntervalBetweenSentMessagesField;

    OFPreference *sizeFormatPreference;
    OFPreference *readTimeOutPreference;
    OFPreference *intervalBetweenSentMessagesPreference;
}

+ (SSEPreferencesWindowController *)preferencesWindowController;

- (id)init;

- (IBAction)changeSizeFormat:(id)sender;
- (IBAction)changeSysExFolder:(id)sender;
- (IBAction)changeReadTimeOut:(id)sender;
- (IBAction)changeIntervalBetweenSentMessages:(id)sender;

@end

// Notifications
extern NSString *SSEDisplayPreferenceChangedNotification;
extern NSString *SSESysExSendPreferenceChangedNotification;
extern NSString *SSESysExReceivePreferenceChangedNotification;
