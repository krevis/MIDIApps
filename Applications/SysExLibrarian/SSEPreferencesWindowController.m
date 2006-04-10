#import "SSEPreferencesWindowController.h"

#import "SSEMainWindowController.h"
#import "SSELibrary.h"
#import "SSEMIDIController.h"
#import "SSESysExSpeedWindowController.h"


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
    [[NSUserDefaults standardUserDefaults] setBool:[[sender selectedCell] tag] forKey:SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey];
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
    [[NSUserDefaults standardUserDefaults] setInteger:[sender intValue] forKey:SSESysExReadTimeOutPreferenceKey];
    [self synchronizeReadTimeOutField];
    [self synchronizeDefaults];
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:SSESysExReceivePreferenceChangedNotification object: nil] postingStyle:NSPostWhenIdle];
}

- (IBAction)changeIntervalBetweenSentMessages:(id)sender;
{
    [[NSUserDefaults standardUserDefaults] setInteger:[sender intValue] forKey:SSESysExIntervalBetweenSentMessagesPreferenceKey];
    [self synchronizeIntervalBetweenSentMessagesField];
    [self synchronizeDefaults];
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:SSESysExSendPreferenceChangedNotification object: nil] postingStyle:NSPostWhenIdle];
}

- (IBAction)showSysExSpeedWindow:(id)sender
{
    [[SSESysExSpeedWindowController sysExSpeedWindowController] showWindow:nil];
}

@end


@implementation SSEPreferencesWindowController (Private)

- (void)synchronizeDefaults;
{
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)synchronizeControls;
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    [sizeFormatMatrix selectCellWithTag:[defaults boolForKey:SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey]];
    [sysExFolderPathField setStringValue:[[SSELibrary sharedLibrary] fileDirectoryPath]];
    [sysExReadTimeOutSlider setIntValue:[defaults integerForKey:SSESysExReadTimeOutPreferenceKey]];
    [self synchronizeReadTimeOutField];
    [sysExIntervalBetweenSentMessagesSlider setIntValue:[defaults integerForKey: SSESysExIntervalBetweenSentMessagesPreferenceKey]];
    [self synchronizeIntervalBetweenSentMessagesField];
//    [showSysExSpeedWindowButton setEnabled:[[SMClient sharedClient] doesSendSysExRespectExternalDeviceSpeed]];
}

- (void)synchronizeReadTimeOutField;
{
    [sysExReadTimeOutField setStringValue:[self formatMilliseconds:[[NSUserDefaults standardUserDefaults] integerForKey:SSESysExReadTimeOutPreferenceKey]]];
}

- (void)synchronizeIntervalBetweenSentMessagesField;
{
    [sysExIntervalBetweenSentMessagesField setStringValue:[self formatMilliseconds:[[NSUserDefaults standardUserDefaults] integerForKey: SSESysExIntervalBetweenSentMessagesPreferenceKey]]];
}

- (NSString *)formatMilliseconds:(int)msec;
{
    static NSString *oneSecond = nil;
    static NSString *millisecondsFormat = nil;

    if (!oneSecond)
        oneSecond =  [NSLocalizedStringFromTableInBundle(@"1 second", @"SysExLibrarian", SMBundleForObject(self), "one second (formatting of milliseconds)") retain];
    if (!millisecondsFormat)
        millisecondsFormat = [NSLocalizedStringFromTableInBundle(@"%d milliseconds", @"SysExLibrarian", SMBundleForObject(self), "format for milliseconds") retain];
    
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
