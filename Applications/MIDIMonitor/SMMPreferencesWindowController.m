#import "SMMPreferencesWindowController.h"

#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMAppController.h"
#import "SMMDocument.h"
#import "SMMMonitorWindowController.h"
#import "SMMSysExWindowController.h"


@interface  SMMPreferencesWindowController (Private)

- (void)synchronizeDefaults;
- (void)sendDisplayPreferenceChangedNotification;

@end


@implementation SMMPreferencesWindowController

NSString *SMMDisplayPreferenceChangedNotification = @"SMMDisplayPreferenceChangedNotification";


static SMMPreferencesWindowController *controller;

+ (SMMPreferencesWindowController *)preferencesWindowController;
{
    if (!controller)
        controller = [[SMMPreferencesWindowController alloc] init];
    
    return controller;
}

- (id)init;
{
    if (!(self = [super initWithWindowNibName:@"Preferences"]))
        return nil;

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    SMRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)windowDidLoad
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
    [super windowDidLoad];

    // Make sure the first tab is selected (just in case someone changed it while editing the nib)
    [tabView selectFirstTabViewItem:nil];
    
    [timeFormatMatrix selectCellWithTag:[defaults integerForKey: SMTimeFormatPreferenceKey]];
    [noteFormatMatrix selectCellWithTag:[defaults integerForKey: SMNoteFormatPreferenceKey]];
    [controllerFormatMatrix selectCellWithTag:[defaults integerForKey: SMControllerFormatPreferenceKey]];
	[dataFormatMatrix selectCellWithTag:[defaults integerForKey: SMDataFormatPreferenceKey]];

    [autoSelectOrdinarySourcesCheckbox setIntValue:[defaults boolForKey:SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey]];
    [autoSelectVirtualDestinationCheckbox setIntValue:[defaults boolForKey:SMMAutoSelectVirtualDestinationInNewDocumentPreferenceKey]];
    [autoSelectSpyingDestinationsCheckbox setIntValue:[defaults boolForKey:SMMAutoSelectSpyingDestinationsInNewDocumentPreferenceKey]];
    [openWindowsForNewSourcesCheckbox setIntValue:[defaults boolForKey:SMMOpenWindowsForNewSourcesPreferenceKey]];

    [askBeforeClosingModifiedWindowCheckbox setIntValue:[defaults boolForKey:SMMAskBeforeClosingModifiedWindowPreferenceKey]];
    [alwaysSaveSysExWithEOXMatrix selectCellWithTag:[defaults boolForKey:SMMSaveSysExWithEOXAlwaysPreferenceKey]];
}


//
// Actions
//

- (IBAction)changeTimeFormat:(id)sender;
{
	[[NSUserDefaults standardUserDefaults] setInteger: [[sender selectedCell] tag] forKey: SMTimeFormatPreferenceKey];
    [self synchronizeDefaults];
    [self sendDisplayPreferenceChangedNotification];
}

- (IBAction)changeNoteFormat:(id)sender;
{
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender selectedCell] tag] forKey: SMNoteFormatPreferenceKey];
    [self synchronizeDefaults];
    [self sendDisplayPreferenceChangedNotification];
}
 
- (IBAction)changeControllerFormat:(id)sender;
{
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender selectedCell] tag] forKey: SMControllerFormatPreferenceKey];
    [self synchronizeDefaults];
    [self sendDisplayPreferenceChangedNotification];
}

- (IBAction)changeDataFormat:(id)sender;
{
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender selectedCell] tag] forKey: SMDataFormatPreferenceKey];
    [self synchronizeDefaults];
    [self sendDisplayPreferenceChangedNotification];
}

- (IBAction)changeAutoSelectOrdinarySources:(id)sender;
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender intValue] forKey: SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey];
    [self synchronizeDefaults];
}

- (IBAction)changeAutoSelectVirtualDestination:(id)sender;
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender intValue] forKey: SMMAutoSelectVirtualDestinationInNewDocumentPreferenceKey];
    [self synchronizeDefaults];
}

- (IBAction)changeAutoSelectSpyingDestinations:(id)sender;
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender intValue] forKey: SMMAutoSelectSpyingDestinationsInNewDocumentPreferenceKey];
    [self synchronizeDefaults];
}

- (IBAction)changeOpenWindowsForNewSources:(id)sender;
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender intValue] forKey: SMMOpenWindowsForNewSourcesPreferenceKey];
    [self synchronizeDefaults];
}

- (IBAction)changeAskBeforeClosingModifiedWindow:(id)sender;
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender intValue] forKey: SMMAskBeforeClosingModifiedWindowPreferenceKey];
    [self synchronizeDefaults];
}

- (IBAction)changeAlwaysSaveSysExWithEOX:(id)sender;
{
	[[NSUserDefaults standardUserDefaults] setBool:[[sender selectedCell] tag] forKey: SMMSaveSysExWithEOXAlwaysPreferenceKey];
    [self synchronizeDefaults];
}

@end


@implementation SMMPreferencesWindowController (Private)

- (void)synchronizeDefaults;
{
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)sendDisplayPreferenceChangedNotification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMMDisplayPreferenceChangedNotification object:nil];
}

@end
