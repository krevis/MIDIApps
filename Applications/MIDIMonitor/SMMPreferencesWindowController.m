//
//  SMMPreferencesWindowController.m
//  MIDIMonitor
//
//  Created by krevis on Sun Sep 23 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import "SMMPreferencesWindowController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SMMAppController.h"
#import "SMMDocument.h"
#import "SMMSysExRow.h"
#import "NSPopUpButton-MIDIMonitorExtensions.h"


@interface  SMMPreferencesWindowController (Private)

- (void)_synchronizeDefaults;
- (void)_sendDisplayPreferenceChangedNotification;
- (void)_autosaveWindowFrame;

@end


@implementation SMMPreferencesWindowController

DEFINE_NSSTRING(SMMDisplayPreferenceChangedNotification);
DEFINE_NSSTRING(SMMSysExBytesPerRowPreferenceChangedNotification);

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
    sysExBytesPerRowPreference = [[OFPreference preferenceForKey:SMMSysExBytesPerRowPreferenceKey] retain];
    autoSelectFirstSourceInNewDocumentPreference = [[OFPreference preferenceForKey:SMMAutoSelectFirstSourceInNewDocumentPreferenceKey] retain];
    autoSelectFirstSourceIfSourceDisappearsPreference = [[OFPreference preferenceForKey:SMMAutoSelectFirstSourceIfSourceDisappearsPreferenceKey] retain];
    openWindowsForNewSourcesPreference = [[OFPreference preferenceForKey:SMMOpenWindowsForNewSourcesPreferenceKey] retain];

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
    [sysExBytesPerRowPreference release];
    [autoSelectFirstSourceInNewDocumentPreference release];
    [autoSelectFirstSourceIfSourceDisappearsPreference release];
    [openWindowsForNewSourcesPreference release];
    
    [super dealloc];
}

- (void)awakeFromNib
{
    [[self window] setFrameAutosaveName:[self windowNibName]];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [timeFormatMatrix selectCellWithTag:[timeFormatPreference integerValue]];
    [noteFormatMatrix selectCellWithTag:[noteFormatPreference integerValue]];
    [controllerFormatMatrix selectCellWithTag:[controllerFormatPreference integerValue]];
    [dataFormatMatrix selectCellWithTag:[dataFormatPreference integerValue]];
    [sysExBytesPerRowMatrix selectCellWithTag:[sysExBytesPerRowPreference integerValue]];
    [autoSelectFirstSourceInNewDocumentMatrix selectCellWithTag:[autoSelectFirstSourceInNewDocumentPreference boolValue]];
    [autoSelectFirstSourceIfSourceDisappearsCheckbox setIntValue:[autoSelectFirstSourceIfSourceDisappearsPreference boolValue]];
    [openWindowsForNewSourcesCheckbox setIntValue:[openWindowsForNewSourcesPreference boolValue]];
}


//
// Actions
//

- (IBAction)changeTimeFormat:(id)sender;
{
    [timeFormatPreference setIntegerValue:[[sender selectedCell] tag]];
    [self _synchronizeDefaults];
    [self _sendDisplayPreferenceChangedNotification];
}

- (IBAction)changeNoteFormat:(id)sender;
{
    [noteFormatPreference setIntegerValue:[[sender selectedCell] tag]];
    [self _synchronizeDefaults];
    [self _sendDisplayPreferenceChangedNotification];
}
 
- (IBAction)changeControllerFormat:(id)sender;
{
    [controllerFormatPreference setIntegerValue:[[sender selectedCell] tag]];
    [self _synchronizeDefaults];
    [self _sendDisplayPreferenceChangedNotification];
}

- (IBAction)changeDataFormat:(id)sender;
{
    [dataFormatPreference setIntegerValue:[[sender selectedCell] tag]];
    [self _synchronizeDefaults];
    [self _sendDisplayPreferenceChangedNotification];
}

- (IBAction)changeSysExBytesPerRow:(id)sender;
{
    [sysExBytesPerRowPreference setIntegerValue:[[sender selectedCell] tag]];
    [self _synchronizeDefaults];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMMSysExBytesPerRowPreferenceChangedNotification object:nil];
}

- (IBAction)changeAutoSelectFirstSourceInNewDocument:(id)sender;
{
    [autoSelectFirstSourceInNewDocumentPreference setBoolValue:[[sender selectedCell] tag]];
    [self _synchronizeDefaults];
}

- (IBAction)changeAutoSelectFirstSourceIfSourceDisappears:(id)sender;
{
    [autoSelectFirstSourceIfSourceDisappearsPreference setBoolValue:[sender intValue]];
    [self _synchronizeDefaults];
}

- (IBAction)changeOpenWindowsForNewSources:(id)sender;
{
    [openWindowsForNewSourcesPreference setBoolValue:[sender intValue]];
    [self _synchronizeDefaults];
}

@end


@implementation SMMPreferencesWindowController (NotificationsDelegatesDataSources)

- (void)windowDidResize:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

- (void)windowDidMove:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

@end


@implementation SMMPreferencesWindowController (Private)

- (void)_synchronizeDefaults;
{
    [[NSUserDefaults standardUserDefaults] autoSynchronize];
}

- (void)_sendDisplayPreferenceChangedNotification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMMDisplayPreferenceChangedNotification object:nil];
}

- (void)_autosaveWindowFrame;
{
    // Work around an AppKit bug: the frame that gets saved in NSUserDefaults is the window's old position, not the new one.
    // We get notified after the window has been moved/resized and the defaults changed.

    NSWindow *window;
    NSString *autosaveName;
    
    window = [self window];
    // Sometimes we get called before the window's autosave name is set (when the nib is loading), so check that.
    if ((autosaveName = [window frameAutosaveName])) {
        [window saveFrameUsingName:autosaveName];
        [self _synchronizeDefaults];
    }
}

@end
