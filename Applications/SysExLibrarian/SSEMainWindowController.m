//
//  SSEMainWindowController.m
//  SysExLibrarian
//
//  Created by Kurt Revis on Mon Dec 31 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SSEMainWindowController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import "NSPopUpButton-Extensions.h"
#import "SSEMainController.h"

@interface SSEMainWindowController (Private)

- (void)_autosaveWindowFrame;

- (void)_synchronizePopUpButton:(NSPopUpButton *)popUpButton withDescriptions:(NSArray *)descriptions currentDescription:(NSDictionary *)currentDescription;

@end


@implementation SSEMainWindowController

static SSEMainWindowController *controller;

+ (SSEMainWindowController *)mainWindowController;
{
    if (!controller)
        controller = [[self alloc] init];

    return controller;
}

- (id)init;
{
    if (!(self = [super initWithWindowNibName:@"MainWindow"]))
        return nil;

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)awakeFromNib
{
    [[self window] setFrameAutosaveName:[self windowNibName]];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self synchronizeInterface];
}

//
// Actions
//

- (IBAction)selectSource:(id)sender;
{
    [mainController setSourceDescription:[(NSMenuItem *)[sender selectedItem] representedObject]];
}

- (IBAction)selectDestination:(id)sender;
{
    [mainController setDestinationDescription:[(NSMenuItem *)[sender selectedItem] representedObject]];
}

//
// Other API
//

- (void)synchronizeInterface;
{
    [self synchronizeSources];
    [self synchronizeDestinations];
    // TODO more of course
}

- (void)synchronizeSources;
{
    [self _synchronizePopUpButton:sourcePopUpButton withDescriptions:[mainController sourceDescriptions] currentDescription:[mainController sourceDescription]];
}

- (void)synchronizeDestinations;
{
    [self _synchronizePopUpButton:destinationPopUpButton withDescriptions:[mainController destinationDescriptions] currentDescription:[mainController destinationDescription]];
}

@end


@implementation SSEMainWindowController (NotificationsDelegatesDataSources)

- (void)windowDidResize:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

- (void)windowDidMove:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

@end


@implementation SSEMainWindowController (Private)

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
        [[NSUserDefaults standardUserDefaults] autoSynchronize];
    }
}

- (void)_synchronizePopUpButton:(NSPopUpButton *)popUpButton withDescriptions:(NSArray *)descriptions currentDescription:(NSDictionary *)currentDescription;
{
    BOOL wasAutodisplay;
    unsigned int count, index;
    BOOL found = NO;
    BOOL addedSeparatorBetweenPortAndVirtual = NO;

    // The pop up button redraws whenever it's changed, so turn off autodisplay to stop the blinkiness
    wasAutodisplay = [[self window] isAutodisplay];
    [[self window] setAutodisplay:NO];

    [popUpButton removeAllItems];

    count = [descriptions count];
    for (index = 0; index < count; index++) {
        NSDictionary *description;

        description = [descriptions objectAtIndex:index];
        if (!addedSeparatorBetweenPortAndVirtual && [description objectForKey:@"endpoint"] == nil) {
            if (index > 0)
                [popUpButton addSeparatorItem];
            addedSeparatorBetweenPortAndVirtual = YES;
        }
        [popUpButton addItemWithTitle:[description objectForKey:@"name"] representedObject:description];

        if (!found && [description isEqual:currentDescription]) {
            [popUpButton selectItemAtIndex:[popUpButton numberOfItems] - 1];
            // Don't use index because it may be off by one (because of the separator item)
            found = YES;
        }
    }

    if (!found)
        [popUpButton selectItem:nil];

    // ...and turn autodisplay on again
    if (wasAutodisplay)
        [[self window] displayIfNeeded];
    [[self window] setAutodisplay:wasAutodisplay];
}

@end
