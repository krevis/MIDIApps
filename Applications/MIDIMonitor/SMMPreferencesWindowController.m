#import "SMMPreferencesWindowController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMAppController.h"
#import "SMMDocument.h"
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

    timeFormatPreference = [[OFPreference preferenceForKey:SMTimeFormatPreferenceKey] retain];
    noteFormatPreference = [[OFPreference preferenceForKey:SMNoteFormatPreferenceKey] retain];
    controllerFormatPreference = [[OFPreference preferenceForKey:SMControllerFormatPreferenceKey] retain];
    dataFormatPreference = [[OFPreference preferenceForKey:SMDataFormatPreferenceKey] retain];

    autoSelectOrdinarySourcesPreference = [[OFPreference preferenceForKey:SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey] retain];
    autoSelectVirtualDestinationPreference = [[OFPreference preferenceForKey:SMMAutoSelectVirtualDestinationInNewDocumentPreferenceKey] retain];
    autoSelectSpyingDestinationsPreference = [[OFPreference preferenceForKey:SMMAutoSelectSpyingDestinationsInNewDocumentPreferenceKey] retain];
    openWindowsForNewSourcesPreference = [[OFPreference preferenceForKey:SMMOpenWindowsForNewSourcesPreferenceKey] retain];

    alwaysSaveSysExWithEOXPreference = [[OFPreference preferenceForKey:SMMSaveSysExWithEOXAlwaysPreferenceKey] retain];
    
    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [timeFormatPreference release];
    [noteFormatPreference release];
    [controllerFormatPreference release];
    [dataFormatPreference release];
    [autoSelectOrdinarySourcesPreference release];
    [autoSelectVirtualDestinationPreference release];
    [autoSelectSpyingDestinationsPreference release];
    [openWindowsForNewSourcesPreference release];
    [alwaysSaveSysExWithEOXPreference release];
    
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    // Make sure the first tab is selected (just in case someone changed it while editing the nib)
    [tabView selectFirstTabViewItem:nil];
    
    [timeFormatMatrix selectCellWithTag:[timeFormatPreference integerValue]];
    [noteFormatMatrix selectCellWithTag:[noteFormatPreference integerValue]];
    [controllerFormatMatrix selectCellWithTag:[controllerFormatPreference integerValue]];
    [dataFormatMatrix selectCellWithTag:[dataFormatPreference integerValue]];

    [autoSelectOrdinarySourcesCheckbox setIntValue:[autoSelectOrdinarySourcesPreference boolValue]];
    [autoSelectVirtualDestinationCheckbox setIntValue:[autoSelectVirtualDestinationPreference boolValue]];
    [autoSelectSpyingDestinationsCheckbox setIntValue:[autoSelectSpyingDestinationsPreference boolValue]];
    [openWindowsForNewSourcesCheckbox setIntValue:[openWindowsForNewSourcesPreference boolValue]];

    [alwaysSaveSysExWithEOXMatrix selectCellWithTag:[alwaysSaveSysExWithEOXPreference boolValue]];
}


//
// Actions
//

- (IBAction)changeTimeFormat:(id)sender;
{
    [timeFormatPreference setIntegerValue:[[sender selectedCell] tag]];
    [self synchronizeDefaults];
    [self sendDisplayPreferenceChangedNotification];
}

- (IBAction)changeNoteFormat:(id)sender;
{
    [noteFormatPreference setIntegerValue:[[sender selectedCell] tag]];
    [self synchronizeDefaults];
    [self sendDisplayPreferenceChangedNotification];
}
 
- (IBAction)changeControllerFormat:(id)sender;
{
    [controllerFormatPreference setIntegerValue:[[sender selectedCell] tag]];
    [self synchronizeDefaults];
    [self sendDisplayPreferenceChangedNotification];
}

- (IBAction)changeDataFormat:(id)sender;
{
    [dataFormatPreference setIntegerValue:[[sender selectedCell] tag]];
    [self synchronizeDefaults];
    [self sendDisplayPreferenceChangedNotification];
}

- (IBAction)changeAutoSelectOrdinarySources:(id)sender;
{
    [autoSelectOrdinarySourcesPreference setBoolValue:[sender intValue]];
    [self synchronizeDefaults];
}

- (IBAction)changeAutoSelectVirtualDestination:(id)sender;
{
    [autoSelectVirtualDestinationPreference setBoolValue:[sender intValue]];
    [self synchronizeDefaults];
}

- (IBAction)changeAutoSelectSpyingDestinations:(id)sender;
{
    [autoSelectSpyingDestinationsPreference setBoolValue:[sender intValue]];
    [self synchronizeDefaults];
}

- (IBAction)changeOpenWindowsForNewSources:(id)sender;
{
    [openWindowsForNewSourcesPreference setBoolValue:[sender intValue]];
    [self synchronizeDefaults];
}

- (IBAction)changeAlwaysSaveSysExWithEOX:(id)sender;
{
    [alwaysSaveSysExWithEOXPreference setBoolValue:[[sender selectedCell] tag]];
    [self synchronizeDefaults];
}

@end


@implementation SMMPreferencesWindowController (Private)

- (void)synchronizeDefaults;
{
    [[NSUserDefaults standardUserDefaults] autoSynchronize];
}

- (void)sendDisplayPreferenceChangedNotification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMMDisplayPreferenceChangedNotification object:nil];
}

@end
