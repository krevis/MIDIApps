#import "SSEPreferencesWindowController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SSEMainWindowController.h"
#import "SSELibrary.h"
#import "SSEMIDIController.h"


@interface  SSEPreferencesWindowController (Private)

- (void)_synchronizeDefaults;

- (void)_synchronizeControls;
- (void)_synchronizeReadTimeOutField;
- (void)_synchronizeIntervalBetweenSentMessagesField;

- (NSString *)_formatMilliseconds:(int)msec;

- (void)_openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


@implementation SSEPreferencesWindowController

DEFINE_NSSTRING(SSEDisplayPreferenceChangedNotification);
DEFINE_NSSTRING(SSESysExSendPreferenceChangedNotification);
DEFINE_NSSTRING(SSESysExReceivePreferenceChangedNotification);


static SSEPreferencesWindowController *controller;

+ (SSEPreferencesWindowController *)preferencesWindowController;
{
    if (!controller)
        controller = [[self alloc] init];
    
    return controller;
}

- (id)init;
{
    if (!(self = [super initWithWindowNibName:@"Preferences"]))
        return nil;

    sizeFormatPreference = [[OFPreference preferenceForKey:SSEAbbreviateFileSizesInLibraryTableView] retain];
    readTimeOutPreference = [[OFPreference preferenceForKey:SSESysExReadTimeOutPreferenceKey] retain];
    intervalBetweenSentMessagesPreference = [[OFPreference preferenceForKey:SSESysExIntervalBetweenSentMessagesPreferenceKey] retain];

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [sizeFormatPreference release];
    [readTimeOutPreference release];
    [intervalBetweenSentMessagesPreference release];
    
    [super dealloc];
}

- (IBAction)showWindow:(id)sender;
{
    [self window];	// Make sure the window gets loaded the first time
    [self _synchronizeControls];
    [super showWindow:sender];
}

//
// Actions
//

- (IBAction)changeSizeFormat:(id)sender;
{
    [sizeFormatPreference setBoolValue:[[sender selectedCell] tag]];
    [self _synchronizeDefaults];
    [[NSNotificationCenter defaultCenter] postNotificationName:SSEDisplayPreferenceChangedNotification object:nil];
}

- (IBAction)changeSysExFolder:(id)sender;
{
    NSOpenPanel *openPanel;
    NSString *oldPath;

    openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];

    oldPath = [[SSELibrary sharedLibrary] fileDirectoryPath];

    [openPanel beginSheetForDirectory:oldPath file:nil types:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (IBAction)changeReadTimeOut:(id)sender;
{
    [readTimeOutPreference setIntegerValue:[sender intValue]];
    [self _synchronizeReadTimeOutField];
    [self _synchronizeDefaults];
    [[NSNotificationQueue defaultQueue] enqueueNotificationName:SSESysExReceivePreferenceChangedNotification object:nil postingStyle:NSPostWhenIdle];
}

- (IBAction)changeIntervalBetweenSentMessages:(id)sender;
{
    [intervalBetweenSentMessagesPreference setIntegerValue:[sender intValue]];
    [self _synchronizeIntervalBetweenSentMessagesField];
    [self _synchronizeDefaults];
    [[NSNotificationQueue defaultQueue] enqueueNotificationName:SSESysExSendPreferenceChangedNotification object:nil postingStyle:NSPostWhenIdle];
}

@end


@implementation SSEPreferencesWindowController (Private)

- (void)_synchronizeDefaults;
{
    [[NSUserDefaults standardUserDefaults] autoSynchronize];
}

- (void)_synchronizeControls;
{
    [sizeFormatMatrix selectCellWithTag:[sizeFormatPreference boolValue]];
    [sysExFolderPathField setStringValue:[[SSELibrary sharedLibrary] fileDirectoryPath]];
    [sysExReadTimeOutSlider setIntValue:[readTimeOutPreference integerValue]];
    [self _synchronizeReadTimeOutField];
    [sysExIntervalBetweenSentMessagesSlider setIntValue:[intervalBetweenSentMessagesPreference integerValue]];
    [self _synchronizeIntervalBetweenSentMessagesField];
}

- (void)_synchronizeReadTimeOutField;
{
    [sysExReadTimeOutField setStringValue:[self _formatMilliseconds:[readTimeOutPreference integerValue]]];
}

- (void)_synchronizeIntervalBetweenSentMessagesField;
{
    [sysExIntervalBetweenSentMessagesField setStringValue:[self _formatMilliseconds:[intervalBetweenSentMessagesPreference integerValue]]];
}

- (NSString *)_formatMilliseconds:(int)msec;
{
    if (msec == 1000)
        return @"1 second";
    else
        return [NSString stringWithFormat:@"%d milliseconds", msec];
}

- (void)_openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSOKButton) {
        [[SSELibrary sharedLibrary] setFileDirectoryPath:[[sheet filenames] objectAtIndex:0]];
        [self _synchronizeDefaults];
        [self _synchronizeControls];
    }
}

@end
