/*
 Copyright (c) 2002-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSEWindowController.h"

#import "NSToolbarItem-Extensions.h"


@interface SSEWindowController (Private)

// Window stuff
- (void)autosaveCurrentWindowFrame;

// Toolbar
- (void)loadToolbarNamed:(NSString *)toolbarName;

@end


@implementation SSEWindowController

//
// Init and dealloc
//

- (id)initWithWindowNibName:(NSString *)nibName;
{    
    if (!(self = [super initWithWindowNibName:nibName]))
        return nil;

    [self setWindowFrameAutosaveName:nibName];
    [self setShouldCascadeWindows:NO];

    undoManager = [[NSUndoManager alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willUndoOrRedo:) name:NSUndoManagerWillUndoChangeNotification object:undoManager];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willUndoOrRedo:) name:NSUndoManagerWillRedoChangeNotification object:undoManager];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didUndoOrRedo:) name:NSUndoManagerDidUndoChangeNotification object:undoManager];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didUndoOrRedo:) name:NSUndoManagerDidRedoChangeNotification object:undoManager];
        
    toolbarItemInfo = nil;
    allowedToolbarItems = nil;
    defaultToolbarItems = nil;

    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [undoManager removeAllActionsWithTarget:self];

    [undoManager release];
    [toolbarItemInfo release];
    [allowedToolbarItems release];
    [defaultToolbarItems release];

    [super dealloc];
}

//
// Other initialization
//

- (void)awakeFromNib
{
    [[self window] setFrameAutosaveName:[self windowNibName]];
}

- (void)windowDidLoad;
{
    [super windowDidLoad];

    // Make sure that we are the window's delegate (it might not have been set in the nib)
    [[self window] setDelegate:self];

    // The new Unified toolbar style doesn't leave much room for items, so use the old Expanded version
    // with the toolbar items under the title
    if (@available(macOS 11.0, *)) {
        [[self window] setToolbarStyle:NSWindowToolbarStyleExpanded];
    }

    [self loadToolbarNamed:[self windowNibName]]; // Might fail; that's OK
}

- (void)speciallyInitializeToolbarItem:(NSToolbarItem *)toolbarItem;
{
    // Subclasses should override to do something special to this item (like set up a view).
}

//
// UI validation
//

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)theItem;
{
    // Override in subclasses as necessary

    return YES;
}

//
// Window utility methods
//

- (void)finishEditingInWindow;
{
    if ([[self window] makeFirstResponder:[self firstResponderWhenNotEditing]]) {
        // Validation turned out OK
    } else {
        // Validation of the field didn't work, but we need to end editing NOW regardless
        [[self window] endEditingFor:nil];
    }
}

- (NSResponder *)firstResponderWhenNotEditing
{
    return [self window];
}

//
// Undo-related
//

// Override NSResponder method
- (NSUndoManager *)undoManager
{
    return undoManager;
}

- (void)willUndoOrRedo:(NSNotification *)notification;
{
    // If we're going to undo, anything can happen, and we really need to stop editing first
    [self finishEditingInWindow];

    // More can be done by subclasses
}

- (void)didUndoOrRedo:(NSNotification *)notification;
{
    // Can be overridden by subclasses if they want to.
    // You definitely want to resynchronize your UI here. Just about anything could have happened.
}

@end


@implementation SSEWindowController (NotificationsDelegatesDataSources)

//
// NSWindow delegate
//

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window;
{
    // Make sure our undo manager gets used, not the window's default one.
    return undoManager;
}

- (BOOL)windowShouldClose:(id)sender;
{
    [self finishEditingInWindow];

    // It is possible that something caused by -finishEditingInWindow has caused a sheet to open; we shouldn't close the window in that case, because it really confuses the app (and makes it impossible to quit).
    // (Also: As of 10.1.3, we can get here if someone option-clicks on the close button of a different window, even if this window has a sheet up at the time.)
    if ([[self window] attachedSheet])
        return NO;
    
    return YES;
}

- (void)windowDidResize:(NSNotification *)notification;
{
    [self autosaveCurrentWindowFrame];
}

- (void)windowDidMove:(NSNotification *)notification;
{
    [self autosaveCurrentWindowFrame];
}

//
// NSToolbar delegate
//

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar;
{
    return defaultToolbarItems;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;
{
    return allowedToolbarItems;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
{
    NSToolbarItem *toolbarItem;
    NSDictionary *itemInfoDictionary;

    toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    [toolbarItem setLabel:itemIdentifier];
    [toolbarItem setEnabled:YES];
    itemInfoDictionary = [toolbarItemInfo objectForKey:itemIdentifier];
    [toolbarItem SSE_takeValuesFromDictionary:itemInfoDictionary target:self];

    if ([itemInfoDictionary objectForKey:@"needsSpecialInitialization"])
        [self speciallyInitializeToolbarItem:toolbarItem];

    return toolbarItem;
}

@end


@implementation SSEWindowController (Private)

//
// Window stuff
//

- (void)autosaveCurrentWindowFrame;
{
    // Work around an AppKit bug: the frame that gets saved in NSUserDefaults is the window's old position, not the new one.
    // We get notified after the window has been moved/resized and the defaults changed.

    NSWindow *window;
    NSString *autosaveName;

    window = [self window];
    // Sometimes we get called before the window's autosave name is set (when the nib is loading), so check that.
    if ((autosaveName = [window frameAutosaveName])) {
        [window saveFrameUsingName:autosaveName];
    }
}

//
// Toolbars
//

- (void)loadToolbarNamed:(NSString *)toolbarName;
{
    NSString *toolbarFilePath;
    NSDictionary *toolbarPropertyList;
    NSToolbar *toolbar;

    // If we have a plist specifying a toolbar, then add one to the window.
    toolbarFilePath = [[NSBundle mainBundle] pathForResource:toolbarName ofType:@"toolbar"];
    if (!toolbarFilePath)
        return;

    toolbarPropertyList = [NSDictionary dictionaryWithContentsOfFile:toolbarFilePath];
    if (!toolbarPropertyList)
        return;

    [toolbarItemInfo release];
    [allowedToolbarItems release];
    [defaultToolbarItems release];

    toolbarItemInfo = [[toolbarPropertyList objectForKey:@"itemInfoByIdentifier"] retain];
    allowedToolbarItems = [[toolbarPropertyList objectForKey:@"allowedItemIdentifiers"] retain];
    defaultToolbarItems = [[toolbarPropertyList objectForKey:@"defaultItemIdentifiers"] retain];

    toolbar = [[NSToolbar alloc] initWithIdentifier:toolbarName];
    [toolbar setAllowsUserCustomization:NO];
    [toolbar setAutosavesConfiguration:YES];
    [toolbar setDelegate:self];
    [[self window] setToolbar:toolbar];
    [toolbar release];
}

@end
