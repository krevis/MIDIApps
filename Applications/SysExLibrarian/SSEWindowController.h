#import <Cocoa/Cocoa.h>

@interface SSEWindowController : NSWindowController
{
    NSUndoManager *undoManager;
    NSDictionary *toolbarItemInfo;
    NSArray *allowedToolbarItems;
    NSArray *defaultToolbarItems;
}

// Initialization
- (void)speciallyInitializeToolbarItem:(NSToolbarItem *)toolbarItem;

// UI validation
- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)theItem;

// Window utility methods
- (void)finishEditingInWindow;

// Undo-related
- (void)willUndoOrRedo:(NSNotification *)notification;
- (void)didUndoOrRedo:(NSNotification *)notification;

@end
