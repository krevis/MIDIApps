#import "SSEWindowController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import "NSToolbarItem-Extensions.h"


@interface SSEWindowController (Private)

// Window stuff
- (void)_autosaveWindowFrame;

// Toolbar
- (void)_loadToolbarNamed:(NSString *)toolbarName;
- (NSDictionary *)_toolbarPropertyListWithName:(NSString *)toolbarName;

@end


@implementation SSEWindowController

//
// Init and dealloc
//

- (id)initWithWindowNibName:(NSString *)nibName;
{    
    if ([super initWithWindowNibName:nibName] == nil)
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
    [[self window] setExcludedFromWindowsMenu:YES];
}

- (void)windowDidLoad;
{
    [super windowDidLoad];

    // Make sure that we are the window's delegate (it might not have been set in the nib)
    [[self window] setDelegate:self];

    [self _loadToolbarNamed:[self windowNibName]]; // Might fail; that's OK
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
    // Make sure that anything that happens because of this is in its own undo group
    [[self undoManager] beginUndoGrouping];

    if ([[self window] makeFirstResponder:nil]) {
        // Validation turned out OK
    } else {
        // Validation of the field didn't work, but we need to end editing NOW regardless
        [[self window] endEditingFor:nil];
    }

    [[self undoManager] endUndoGrouping];
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
    if ([[self window] attachedSheet])
        return NO;
    
    return YES;
}

- (void)windowDidResize:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

- (void)windowDidMove:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
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
    [toolbarItem takeValuesFromDictionary:itemInfoDictionary target:self];

    if ([itemInfoDictionary objectForKey:@"needsSpecialInitialization"])
        [self speciallyInitializeToolbarItem:toolbarItem];

    return toolbarItem;
}

@end


@implementation SSEWindowController (Private)

//
// Window stuff
//

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

//
// Toolbars
//

- (void)_loadToolbarNamed:(NSString *)toolbarName;
{
    NSDictionary *toolbarPropertyList;
    NSToolbar *toolbar;

    toolbarPropertyList = [self _toolbarPropertyListWithName:toolbarName];
    // If we have no plist specifying a toolbar, then don't add one to the window.
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

- (NSDictionary *)_toolbarPropertyListWithName:(NSString *)toolbarName;
{
    NSString *toolbarFilePath;

    toolbarFilePath = [[NSBundle mainBundle] pathForResource:toolbarName ofType:@"toolbar"];
    if (!toolbarFilePath)
        return nil;

    return [NSDictionary dictionaryWithContentsOfFile:toolbarFilePath];
}

@end
