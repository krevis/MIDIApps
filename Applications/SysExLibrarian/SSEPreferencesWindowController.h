#import "SSEWindowController.h"


@interface SSEPreferencesWindowController : SSEWindowController
{
    IBOutlet NSMatrix *sizeFormatMatrix;
    IBOutlet NSTextField *sysExFolderPathField;
    IBOutlet NSSlider *sysExReadTimeOutSlider;
    IBOutlet NSTextField *sysExReadTimeOutField;
    IBOutlet NSSlider *sysExIntervalBetweenSentMessagesSlider;
    IBOutlet NSTextField *sysExIntervalBetweenSentMessagesField;
    IBOutlet NSButton *showSysExSpeedWindowButton;
}

+ (SSEPreferencesWindowController *)preferencesWindowController;

- (id)init;

- (IBAction)changeSizeFormat:(id)sender;
- (IBAction)changeSysExFolder:(id)sender;
- (IBAction)changeReadTimeOut:(id)sender;
- (IBAction)changeIntervalBetweenSentMessages:(id)sender;

- (IBAction)showSysExSpeedWindow:(id)sender;

@end

// Notifications
extern NSString *SSEDisplayPreferenceChangedNotification;
extern NSString *SSESysExSendPreferenceChangedNotification;
extern NSString *SSESysExReceivePreferenceChangedNotification;
