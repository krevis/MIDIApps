#import <Cocoa/Cocoa.h>

@class OFPreference;


@interface SMMPreferencesWindowController : NSWindowController
{
    IBOutlet NSMatrix *timeFormatMatrix;
    IBOutlet NSMatrix *noteFormatMatrix;
    IBOutlet NSMatrix *controllerFormatMatrix;
    IBOutlet NSMatrix *dataFormatMatrix;
    IBOutlet NSMatrix *autoSelectOrdinarySourcesInNewDocumentMatrix;
    IBOutlet NSButton *openWindowsForNewSourcesCheckbox;
    IBOutlet NSMatrix *alwaysSaveSysExWithEOXMatrix;

    OFPreference *timeFormatPreference;
    OFPreference *noteFormatPreference;
    OFPreference *controllerFormatPreference;
    OFPreference *dataFormatPreference;
    OFPreference *autoSelectOrdinarySourcesInNewDocumentPreference;
    OFPreference *openWindowsForNewSourcesPreference;
    OFPreference *alwaysSaveSysExWithEOXPreference;
}

+ (SMMPreferencesWindowController *)preferencesWindowController;

- (id)init;

- (IBAction)changeTimeFormat:(id)sender;
- (IBAction)changeNoteFormat:(id)sender;
- (IBAction)changeControllerFormat:(id)sender;
- (IBAction)changeDataFormat:(id)sender;
- (IBAction)changeAutoSelectOrdinarySourcesInNewDocument:(id)sender;
- (IBAction)changeOpenWindowsForNewSources:(id)sender;
- (IBAction)changeAlwaysSaveSysExWithEOX:(id)sender;

@end

// Notifications
extern NSString *SMMDisplayPreferenceChangedNotification;
