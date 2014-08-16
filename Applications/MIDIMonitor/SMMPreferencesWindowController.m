/*
 Copyright (c) 2001-2014, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SMMPreferencesWindowController.h"

#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMAppController.h"
#import "SMMDocument.h"
#import "SMMMonitorWindowController.h"
#import "SMMSysExWindowController.h"


NSString* const SMMDisplayPreferenceChangedNotification = @"SMMDisplayPreferenceChangedNotification";

@interface SMMPreferencesWindowController ()

@property (nonatomic, assign) IBOutlet NSTabView *tabView;
@property (nonatomic, assign) IBOutlet NSMatrix *timeFormatMatrix;
@property (nonatomic, assign) IBOutlet NSMatrix *noteFormatMatrix;
@property (nonatomic, assign) IBOutlet NSMatrix *controllerFormatMatrix;
@property (nonatomic, assign) IBOutlet NSMatrix *dataFormatMatrix;
@property (nonatomic, assign) IBOutlet NSButton *autoSelectOrdinarySourcesCheckbox;
@property (nonatomic, assign) IBOutlet NSButton *autoSelectVirtualDestinationCheckbox;
@property (nonatomic, assign) IBOutlet NSButton *autoSelectSpyingDestinationsCheckbox;
@property (nonatomic, assign) IBOutlet NSButton *openWindowsForNewSourcesCheckbox;
@property (nonatomic, assign) IBOutlet NSButton *askBeforeClosingModifiedWindowCheckbox;
@property (nonatomic, assign) IBOutlet NSMatrix *alwaysSaveSysExWithEOXMatrix;
@property (nonatomic, assign) IBOutlet NSButton *expertModeCheckbox;
@property (nonatomic, assign) IBOutlet NSTextField *expertModeTextField;

@end

@implementation SMMPreferencesWindowController

+ (SMMPreferencesWindowController *)preferencesWindowController
{
    static SMMPreferencesWindowController *controller;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [[SMMPreferencesWindowController alloc] init];
    });

    return controller;
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    if (completionHandler) {
        completionHandler([[self preferencesWindowController] window], nil);
    }
}

- (id)init
{
    return [super initWithWindowNibName:@"Preferences"];
}

- (id)initWithWindowNibName:(NSString *)windowNibName
{
    SMRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)windowDidLoad
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
    [super windowDidLoad];

    self.window.restorationClass = [self class];

    // Make sure the first tab is selected (just in case someone changed it while editing the nib)
    [self.tabView selectFirstTabViewItem:nil];
    
    [self.timeFormatMatrix selectCellWithTag:[defaults integerForKey: SMTimeFormatPreferenceKey]];
    [self.noteFormatMatrix selectCellWithTag:[defaults integerForKey: SMNoteFormatPreferenceKey]];
    [self.controllerFormatMatrix selectCellWithTag:[defaults integerForKey: SMControllerFormatPreferenceKey]];
	[self.dataFormatMatrix selectCellWithTag:[defaults integerForKey: SMDataFormatPreferenceKey]];

    [self.expertModeCheckbox setIntValue:[defaults boolForKey:SMExpertModePreferenceKey]];
    [self updateExpertModeTextField];
    
    [self.autoSelectOrdinarySourcesCheckbox setIntValue:[defaults boolForKey:SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey]];
    [self.autoSelectVirtualDestinationCheckbox setIntValue:[defaults boolForKey:SMMAutoSelectVirtualDestinationInNewDocumentPreferenceKey]];
    [self.autoSelectSpyingDestinationsCheckbox setIntValue:[defaults boolForKey:SMMAutoSelectSpyingDestinationsInNewDocumentPreferenceKey]];
    [self.openWindowsForNewSourcesCheckbox setIntValue:[defaults boolForKey:SMMOpenWindowsForNewSourcesPreferenceKey]];

    [self.askBeforeClosingModifiedWindowCheckbox setIntValue:[defaults boolForKey:SMMAskBeforeClosingModifiedWindowPreferenceKey]];
    [self.alwaysSaveSysExWithEOXMatrix selectCellWithTag:[defaults boolForKey:SMMSaveSysExWithEOXAlwaysPreferenceKey]];
}


//
// Actions
//

- (IBAction)changeTimeFormat:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender selectedCell] tag] forKey:SMTimeFormatPreferenceKey];
    [self synchronizeDefaults];
    [self sendDisplayPreferenceChangedNotification];
}

- (IBAction)changeNoteFormat:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender selectedCell] tag] forKey:SMNoteFormatPreferenceKey];
    [self synchronizeDefaults];
    [self sendDisplayPreferenceChangedNotification];
}
 
- (IBAction)changeControllerFormat:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender selectedCell] tag] forKey: SMControllerFormatPreferenceKey];
    [self synchronizeDefaults];
    [self sendDisplayPreferenceChangedNotification];
}

- (IBAction)changeDataFormat:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender selectedCell] tag] forKey:SMDataFormatPreferenceKey];
    [self synchronizeDefaults];
    [self sendDisplayPreferenceChangedNotification];
}

- (IBAction)changeAutoSelectOrdinarySources:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender intValue] forKey: SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey];
    [self synchronizeDefaults];
}

- (IBAction)changeAutoSelectVirtualDestination:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender intValue] forKey: SMMAutoSelectVirtualDestinationInNewDocumentPreferenceKey];
    [self synchronizeDefaults];
}

- (IBAction)changeAutoSelectSpyingDestinations:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender intValue] forKey: SMMAutoSelectSpyingDestinationsInNewDocumentPreferenceKey];
    [self synchronizeDefaults];
}

- (IBAction)changeOpenWindowsForNewSources:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender intValue] forKey: SMMOpenWindowsForNewSourcesPreferenceKey];
    [self synchronizeDefaults];
}

- (IBAction)changeAskBeforeClosingModifiedWindow:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender intValue] forKey: SMMAskBeforeClosingModifiedWindowPreferenceKey];
    [self synchronizeDefaults];
}

- (IBAction)changeAlwaysSaveSysExWithEOX:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:[[sender selectedCell] tag] forKey: SMMSaveSysExWithEOXAlwaysPreferenceKey];
    [self synchronizeDefaults];
}

- (IBAction)changeExpertMode:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender intValue] forKey:SMExpertModePreferenceKey];
    [self synchronizeDefaults];
    [self updateExpertModeTextField];
    [self sendDisplayPreferenceChangedNotification];
}

#pragma mark Private

- (void)synchronizeDefaults
{
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)sendDisplayPreferenceChangedNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMMDisplayPreferenceChangedNotification object:nil];
}

- (void)updateExpertModeTextField
{
    BOOL expertMode = [[NSUserDefaults standardUserDefaults] boolForKey:SMExpertModePreferenceKey];
    NSString* text;

    if (expertMode)
        text = NSLocalizedStringWithDefaultValue(@"EXPERT_ON", @"MIDIMonitor", SMBundleForObject(self), @"• Note On with velocity 0 shows as Note On\n• Zero timestamp shows 0", "Explanation when expert mode is on");
    else
        text = NSLocalizedStringWithDefaultValue(@"EXPERT_OFF", @"MIDIMonitor", SMBundleForObject(self), @"• Note On with velocity 0 shows as Note Off\n• Zero timestamp shows time received", "Explanation when expert mode is off");
    
    self.expertModeTextField.stringValue = text;
}

@end
