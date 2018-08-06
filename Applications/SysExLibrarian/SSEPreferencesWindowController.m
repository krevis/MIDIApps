/*
 Copyright (c) 2002-2014, Kurt Revis.  All rights reserved.
 
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


@interface  SSEPreferencesWindowController ()
{
    IBOutlet NSMatrix *sizeFormatMatrix;
    IBOutlet NSTextField *sysExFolderPathField;
    IBOutlet NSSlider *sysExReadTimeOutSlider;
    IBOutlet NSTextField *sysExReadTimeOutField;
    IBOutlet NSSlider *sysExIntervalBetweenSentMessagesSlider;
    IBOutlet NSTextField *sysExIntervalBetweenSentMessagesField;
    IBOutlet NSTabView *tabView;
	IBOutlet NSButton *listenForProgramChangesButton;
	IBOutlet NSButton *interruptOnProgramChangeButton;
    IBOutlet SSESysExSpeedController *sysExSpeedController;

    struct {
        unsigned int willPostReceivePreferenceChangedNotification:1;
        unsigned int willPostSendPreferenceChangedNotification:1;
        unsigned int willPostListenForProgramChangesPreferenceChangedNotification:1;
    } flags;
}

@end


@implementation SSEPreferencesWindowController

NSString *SSEDisplayPreferenceChangedNotification = @"SSEDisplayPreferenceChangedNotification";
NSString *SSESysExSendPreferenceChangedNotification = @"SSESysExSendPreferenceChangedNotification";
NSString *SSESysExReceivePreferenceChangedNotification = @"SSESysExReceivePreferenceChangedNotification";
NSString *SSEListenForProgramChangesPreferenceChangedNotification = @"SSEListenForProgramChangesPreferenceChangedNotification";


+ (SSEPreferencesWindowController *)preferencesWindowController
{
    static SSEPreferencesWindowController *sController = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sController = [[self alloc] init];
    });

    return sController;
}

- (id)init
{
    if (!(self = [super initWithWindowNibName:@"Preferences"]))
        return nil;

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName
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
    [super windowDidLoad];
        
    // Make sure the "General" tab is showing, just in case it was changed in the nib
    [tabView selectTabViewItemWithIdentifier: @"general"];
}

- (IBAction)showWindow:(id)sender
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

- (IBAction)changeSizeFormat:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:[[sender selectedCell] tag] forKey:SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SSEDisplayPreferenceChangedNotification object:nil];
}

- (IBAction)changeSysExFolder:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    [openPanel setAllowsMultipleSelection:NO];

    NSString *oldPath = [[SSELibrary sharedLibrary] fileDirectoryPath];
    
    [openPanel setDirectoryURL:[NSURL fileURLWithPath:oldPath isDirectory:YES]];
    [openPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        [self openPanelDidEnd:openPanel returnCode:result contextInfo:NULL];
    }];
}

- (IBAction)changeReadTimeOut:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:[sender intValue] forKey:SSESysExReadTimeOutPreferenceKey];
    [self synchronizeReadTimeOutField];

    [[NSNotificationCenter defaultCenter] postNotificationName:SSESysExReceivePreferenceChangedNotification object:nil];
}

- (IBAction)changeIntervalBetweenSentMessages:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:[sender intValue] forKey:SSESysExIntervalBetweenSentMessagesPreferenceKey];
    [self synchronizeIntervalBetweenSentMessagesField];

    [[NSNotificationCenter defaultCenter] postNotificationName:SSESysExSendPreferenceChangedNotification object:nil];
}

- (IBAction)listenForProgramChanges:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:([sender intValue] ? YES : NO) forKey:SSEListenForProgramChangesPreferenceKey];

    [[NSNotificationCenter defaultCenter] postNotificationName:SSEListenForProgramChangesPreferenceChangedNotification object:nil];
}

- (IBAction)interruptOnProgramChange:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:([sender intValue] ? YES : NO) forKey:SSEInterruptOnProgramChangePreferenceKey];
    // no need for a notification to be posted; relevant code looks up this value each time
}


#pragma mark Private

- (void)synchronizeControls
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    [sizeFormatMatrix selectCellWithTag:[defaults boolForKey:SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey]];
    [sysExFolderPathField setStringValue:[[SSELibrary sharedLibrary] fileDirectoryPath]];
    [sysExReadTimeOutSlider setIntegerValue:[defaults integerForKey:SSESysExReadTimeOutPreferenceKey]];
	[listenForProgramChangesButton setIntValue:[defaults boolForKey:SSEListenForProgramChangesPreferenceKey]];
    [interruptOnProgramChangeButton setIntValue:[defaults boolForKey:SSEInterruptOnProgramChangePreferenceKey]];
    [self synchronizeReadTimeOutField];
    [sysExIntervalBetweenSentMessagesSlider setIntegerValue:[defaults integerForKey: SSESysExIntervalBetweenSentMessagesPreferenceKey]];
    [self synchronizeIntervalBetweenSentMessagesField];
}

- (void)synchronizeReadTimeOutField
{
    [sysExReadTimeOutField setStringValue:[self formatMilliseconds:[[NSUserDefaults standardUserDefaults] integerForKey:SSESysExReadTimeOutPreferenceKey]]];
}

- (void)synchronizeIntervalBetweenSentMessagesField
{
    [sysExIntervalBetweenSentMessagesField setStringValue:[self formatMilliseconds:[[NSUserDefaults standardUserDefaults] integerForKey: SSESysExIntervalBetweenSentMessagesPreferenceKey]]];
}

- (NSString *)formatMilliseconds:(NSInteger)msec
{
    static NSString *oneSecond = nil;
    static NSString *millisecondsFormat = nil;

    if (!oneSecond)
        oneSecond = [NSLocalizedStringFromTableInBundle(@"1 second", @"SysExLibrarian", SMBundleForObject(self), "one second (formatting of milliseconds)") retain];
    if (!millisecondsFormat)
        millisecondsFormat = [NSLocalizedStringFromTableInBundle(@"%ld milliseconds", @"SysExLibrarian", SMBundleForObject(self), "format for milliseconds") retain];
    
    if (msec == 1000)
        return oneSecond;
    else
        return [NSString stringWithFormat:millisecondsFormat, (long)msec];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSOKButton) {
        if ([[sheet URLs] count] == 1) {
            NSURL* url = [[sheet URLs] objectAtIndex:0];
            [[SSELibrary sharedLibrary] setFileDirectoryPath:[url path]];
            [self synchronizeControls];
        }
    }
}

@end
