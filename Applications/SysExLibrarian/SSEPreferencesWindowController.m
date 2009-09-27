/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSEPreferencesWindowController.h"

#import "SSEMainWindowController.h"
#import "SSELibrary.h"
#import "SSEMIDIController.h"
#import "SSESysExSpeedController.h"


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
NSString *SSEListenForProgramChangesPreferenceChangedNotification = @"SSEListenForProgramChangesPreferenceChangedNotification";


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

- (void)windowDidLoad;
{
    [super windowDidLoad];
        
    // Make sure the "General" tab is showing, just in case it was changed in the nib
    [tabView selectTabViewItemWithIdentifier: @"general"];
}

- (IBAction)showWindow:(id)sender;
{
    [self window];	// Make sure the window gets loaded before we do anything else

    [self synchronizeControls];

    if ([@"speed" isEqualToString: [[tabView selectedTabViewItem] identifier]]) {
        [sysExSpeedController willShow];
    }
    
    [super showWindow:sender];
}

//
// Delegate methods
//

- (void)tabView:(NSTabView *)tv willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    if ([@"speed" isEqualToString: [tabViewItem identifier]]) {
        [sysExSpeedController willShow];
    } else if ([@"speed" isEqualToString: [[tabView selectedTabViewItem] identifier]]) {
        [sysExSpeedController willHide];
    }
}

- (void)windowWillClose:(NSNotification *)notification
{
    if ([@"speed" isEqualToString: [[tabView selectedTabViewItem] identifier]]) {
        [sysExSpeedController willHide];
    }    
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

- (IBAction)listenForProgramChanges:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:([sender intValue] ? YES : NO) forKey:SSEListenForProgramChangesPreferenceKey];
    [self synchronizeDefaults];
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:SSEListenForProgramChangesPreferenceChangedNotification object: nil] postingStyle:NSPostWhenIdle];
}

- (IBAction)interruptOnProgramChange:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:([sender intValue] ? YES : NO) forKey:SSEInterruptOnProgramChangePreferenceKey];
    [self synchronizeDefaults];    
    // no need for a notification to be posted; relevant code looks up this value each time
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
	[listenForProgramChangesButton setIntValue:[defaults boolForKey:SSEListenForProgramChangesPreferenceKey]];
    [interruptOnProgramChangeButton setIntValue:[defaults boolForKey:SSEInterruptOnProgramChangePreferenceKey]];
    [self synchronizeReadTimeOutField];
    [sysExIntervalBetweenSentMessagesSlider setIntValue:[defaults integerForKey: SSESysExIntervalBetweenSentMessagesPreferenceKey]];
    [self synchronizeIntervalBetweenSentMessagesField];
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
