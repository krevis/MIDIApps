#import <Cocoa/Cocoa.h>
#import "SMMWindowController.h"


@interface SMMPreferencesWindowController : SMMWindowController
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
    IBOutlet NSButton *askBeforeClosingModifiedWindowCheckbox;
    IBOutlet NSMatrix *alwaysSaveSysExWithEOXMatrix;
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
- (IBAction)changeAskBeforeClosingModifiedWindow:(id)sender;
- (IBAction)changeAlwaysSaveSysExWithEOX:(id)sender;

@end

// Notifications
extern NSString *SMMDisplayPreferenceChangedNotification;
