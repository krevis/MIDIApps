#import "SSEPreferencesWindowController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SSEMainWindowController.h"
#import "SSELibrary.h"
#import "SSEMIDIController.h"


@interface  SSEPreferencesWindowController (Private)

- (void)synchronizeDefaults;

- (void)synchronizeControls;
- (void)synchronizeReadTimeOutField;
- (void)synchronizeIntervalBetweenSentMessagesField;

- (NSString *)formatMilliseconds:(int)msec;

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


@implementation SSEPreferencesWindowController

NSString *SSEDisplayPreferenceChangedNotification = @"SSEDisplayPreferenceChangedNotification";
NSString *SSESysExSendPreferenceChangedNotification = @"SSESysExSendPreferenceChangedNotification";
NSString *SSESysExReceivePreferenceChangedNotification = @"SSESysExReceivePreferenceChangedNotification";


static SSEPreferencesWindowController *controller = nil;

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

    sizeFormatPreference = [[OFPreference preferenceForKey:SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey] retain];
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
    [self synchronizeControls];
    [super showWindow:sender];
}

//
// Actions
//

- (IBAction)changeSizeFormat:(id)sender;
{
    [sizeFormatPreference setBoolValue:[[sender selectedCell] tag]];
    [self synchronizeDefaults];
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

    [openPanel beginSheetForDirectory:oldPath file:nil types:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (IBAction)changeReadTimeOut:(id)sender;
{
    [readTimeOutPreference setIntegerValue:[sender intValue]];
    [self synchronizeReadTimeOutField];
    [self synchronizeDefaults];
    [[NSNotificationQueue defaultQueue] enqueueNotificationName:SSESysExReceivePreferenceChangedNotification object:nil postingStyle:NSPostWhenIdle];
}

- (IBAction)changeIntervalBetweenSentMessages:(id)sender;
{
    [intervalBetweenSentMessagesPreference setIntegerValue:[sender intValue]];
    [self synchronizeIntervalBetweenSentMessagesField];
    [self synchronizeDefaults];
    [[NSNotificationQueue defaultQueue] enqueueNotificationName:SSESysExSendPreferenceChangedNotification object:nil postingStyle:NSPostWhenIdle];
}

@end


@implementation SSEPreferencesWindowController (Private)

- (void)synchronizeDefaults;
{
    [[NSUserDefaults standardUserDefaults] autoSynchronize];
}

- (void)synchronizeControls;
{
    [sizeFormatMatrix selectCellWithTag:[sizeFormatPreference boolValue]];
    [sysExFolderPathField setStringValue:[[SSELibrary sharedLibrary] fileDirectoryPath]];
    [sysExReadTimeOutSlider setIntValue:[readTimeOutPreference integerValue]];
    [self synchronizeReadTimeOutField];
    [sysExIntervalBetweenSentMessagesSlider setIntValue:[intervalBetweenSentMessagesPreference integerValue]];
    [self synchronizeIntervalBetweenSentMessagesField];
}

- (void)synchronizeReadTimeOutField;
{
    [sysExReadTimeOutField setStringValue:[self formatMilliseconds:[readTimeOutPreference integerValue]]];
}

- (void)synchronizeIntervalBetweenSentMessagesField;
{
    [sysExIntervalBetweenSentMessagesField setStringValue:[self formatMilliseconds:[intervalBetweenSentMessagesPreference integerValue]]];
}

- (NSString *)formatMilliseconds:(int)msec;
{
    static NSString *oneSecond = nil;
    static NSString *millisecondsFormat = nil;

    if (!oneSecond)
        oneSecond =  [NSLocalizedStringFromTableInBundle(@"1 second", @"SysExLibrarian", [self bundle], "one second (formatting of milliseconds)") retain];
    if (!millisecondsFormat)
        millisecondsFormat = [NSLocalizedStringFromTableInBundle(@"%d milliseconds", @"SysExLibrarian", [self bundle], "format for milliseconds") retain];
    
    if (msec == 1000)
        return oneSecond;
    else
        return [NSString stringWithFormat:millisecondsFormat, msec];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSOKButton) {
        [[SSELibrary sharedLibrary] setFileDirectoryPath:[[sheet filenames] objectAtIndex:0]];
        [self synchronizeDefaults];
        [self synchronizeControls];
    }
}

@end
