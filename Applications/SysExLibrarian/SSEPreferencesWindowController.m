#import "SSEPreferencesWindowController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface  SSEPreferencesWindowController (Private)

- (void)_synchronizeDefaults;
- (void)_autosaveWindowFrame;

@end


@implementation SSEPreferencesWindowController

static SSEPreferencesWindowController *controller;

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

//    timeFormatPreference = [[OFPreference preferenceForKey:SMTimeFormatPreferenceKey] retain];

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
//    [timeFormatPreference release];
    
    [super dealloc];
}

- (void)awakeFromNib
{
    [[self window] setFrameAutosaveName:[self windowNibName]];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

//    [timeFormatMatrix selectCellWithTag:[timeFormatPreference integerValue]];
}


//
// Actions
//

/* TODO For example:
- (IBAction)changeTimeFormat:(id)sender;
{
    [timeFormatPreference setIntegerValue:[[sender selectedCell] tag]];
    [self _synchronizeDefaults];
}
*/

@end


@implementation SSEPreferencesWindowController (NotificationsDelegatesDataSources)

- (void)windowDidResize:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

- (void)windowDidMove:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

@end


@implementation SSEPreferencesWindowController (Private)

- (void)_synchronizeDefaults;
{
    [[NSUserDefaults standardUserDefaults] autoSynchronize];
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
