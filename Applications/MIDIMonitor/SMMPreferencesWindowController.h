#import <Cocoa/Cocoa.h>

@class OFPreference;


@interface SMMPreferencesWindowController : NSWindowController
{
    IBOutlet NSTabView *tabView;
    IBOutlet NSMatrix *timeFormatMatrix;
    IBOutlet NSMatrix *noteFormatMatrix;
    IBOutlet NSMatrix *controllerFormatMatrix;
    IBOutlet NSMatrix *dataFormatMatrix;
    IBOutlet NSButton *autoSelectOrdinarySourcesCheckbox;
    IBOutlet NSButton *autoSelectVirtualDestinationCheckbox;
    IBOutlet NSButton *autoSelectSpyingDestinationsCheckbox;
    IBOutlet NSButton *openWindowsForNewSourcesCheckbox;
    IBOutlet NSMatrix *alwaysSaveSysExWithEOXMatrix;

    OFPreference *timeFormatPreference;
    OFPreference *noteFormatPreference;
    OFPreference *controllerFormatPreference;
    OFPreference *dataFormatPreference;
    OFPreference *autoSelectOrdinarySourcesPreference;
    OFPreference *autoSelectVirtualDestinationPreference;
    OFPreference *autoSelectSpyingDestinationsPreference;
    OFPreference *openWindowsForNewSourcesPreference;
    OFPreference *alwaysSaveSysExWithEOXPreference;
}

+ (SMMPreferencesWindowController *)preferencesWindowController;

- (id)init;

- (IBAction)changeTimeFormat:(id)sender;
- (IBAction)changeNoteFormat:(id)sender;
- (IBAction)changeControllerFormat:(id)sender;
- (IBAction)changeDataFormat:(id)sender;
- (IBAction)changeAutoSelectOrdinarySources:(id)sender;
- (IBAction)changeAutoSelectVirtualDestination:(id)sender;
- (IBAction)changeAutoSelectSpyingDestinations:(id)sender;
- (IBAction)changeOpenWindowsForNewSources:(id)sender;
- (IBAction)changeAlwaysSaveSysExWithEOX:(id)sender;

@end

// Notifications
extern NSString *SMMDisplayPreferenceChangedNotification;
