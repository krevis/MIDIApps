#import "SMMWindowController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>



@interface SMMWindowController (Private)

- (void)autosaveWindowFrame;

@end


@implementation SMMWindowController

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    if (!(self = [super initWithWindowNibName:windowNibName]))
        return nil;

    [self setShouldCascadeWindows:NO];
    
    return self;
}

- (void)awakeFromNib
{
    [[self window] setFrameAutosaveName:[self windowNibName]];
}

@end


@implementation SMMWindowController (NotificationsDelegatesDataSources)

- (void)windowDidResize:(NSNotification *)notification;
{
    [self autosaveWindowFrame];
}

- (void)windowDidMove:(NSNotification *)notification;
{
    [self autosaveWindowFrame];
}

@end


@implementation SMMWindowController (Private)

- (void)autosaveWindowFrame;
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

@end
