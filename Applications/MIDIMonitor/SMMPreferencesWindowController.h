#import <Cocoa/Cocoa.h>

@class OFPreference;


@interface SMMPreferencesWindowController : NSWindowController
{
    IBOutlet NSMatrix *timeFormatMatrix;
    IBOutlet NSMatrix *noteFormatMatrix;
    IBOutlet NSMatrix *controllerFormatMatrix;
    IBOutlet NSMatrix *dataFormatMatrix;
    IBOutlet NSMatrix *sysExBytesPerRowMatrix;
    IBOutlet NSMatrix *autoSelectFirstSourceInNewDocumentMatrix;
    IBOutlet NSButton *autoSelectFirstSourceIfSourceDisappearsCheckbox;
    IBOutlet NSButton *openWindowsForNewSourcesCheckbox;

    OFPreference *timeFormatPreference;
    OFPreference *noteFormatPreference;
    OFPreference *controllerFormatPreference;
    OFPreference *dataFormatPreference;
    OFPreference *sysExBytesPerRowPreference;
    OFPreference *autoSelectFirstSourceInNewDocumentPreference;
    OFPreference *autoSelectFirstSourceIfSourceDisappearsPreference;
    OFPreference *openWindowsForNewSourcesPreference;
}

+ (SMMPreferencesWindowController *)preferencesWindowController;

- (id)init;

- (IBAction)changeTimeFormat:(id)sender;
- (IBAction)changeNoteFormat:(id)sender;
- (IBAction)changeControllerFormat:(id)sender;
- (IBAction)changeDataFormat:(id)sender;
- (IBAction)changeSysExBytesPerRow:(id)sender;
- (IBAction)changeAutoSelectFirstSourceInNewDocument:(id)sender;
- (IBAction)changeAutoSelectFirstSourceIfSourceDisappears:(id)sender;
- (IBAction)changeOpenWindowsForNewSources:(id)sender;

@end

// Notifications
extern NSString *SMMDisplayPreferenceChangedNotification;
extern NSString *SMMSysExBytesPerRowPreferenceChangedNotification;
