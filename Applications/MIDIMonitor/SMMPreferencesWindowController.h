#import <Cocoa/Cocoa.h>

@class OFPreference;


@interface SMMPreferencesWindowController : NSWindowController
{
    IBOutlet NSMatrix *timeFormatMatrix;
    IBOutlet NSMatrix *noteFormatMatrix;
    IBOutlet NSMatrix *controllerFormatMatrix;
    IBOutlet NSMatrix *dataFormatMatrix;
    IBOutlet NSMatrix *autoSelectFirstSourceInNewDocumentMatrix;
    IBOutlet NSButton *autoSelectFirstSourceIfSourceDisappearsCheckbox;
    IBOutlet NSButton *openWindowsForNewSourcesCheckbox;
    IBOutlet NSMatrix *alwaysSaveSysExWithEOXMatrix;

    OFPreference *timeFormatPreference;
    OFPreference *noteFormatPreference;
    OFPreference *controllerFormatPreference;
    OFPreference *dataFormatPreference;
    OFPreference *autoSelectFirstSourceInNewDocumentPreference;
    OFPreference *autoSelectFirstSourceIfSourceDisappearsPreference;
    OFPreference *openWindowsForNewSourcesPreference;
    OFPreference *alwaysSaveSysExWithEOXPreference;
}

+ (SMMPreferencesWindowController *)preferencesWindowController;

- (id)init;

- (IBAction)changeTimeFormat:(id)sender;
- (IBAction)changeNoteFormat:(id)sender;
- (IBAction)changeControllerFormat:(id)sender;
- (IBAction)changeDataFormat:(id)sender;
- (IBAction)changeAutoSelectFirstSourceInNewDocument:(id)sender;
- (IBAction)changeAutoSelectFirstSourceIfSourceDisappears:(id)sender;
- (IBAction)changeOpenWindowsForNewSources:(id)sender;
- (IBAction)changeAlwaysSaveSysExWithEOX:(id)sender;

@end

// Notifications
extern NSString *SMMDisplayPreferenceChangedNotification;
