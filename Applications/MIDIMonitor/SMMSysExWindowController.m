#import "SMMSysExWindowController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMAppController.h"


@interface SMMSysExWindowController (Private)

- (void)_autosaveWindowFrame;

@end


@implementation SMMSysExWindowController

static NSMutableArray *controllers = nil;

+ (SMMSysExWindowController *)sysExWindowControllerWithMessage:(SMSystemExclusiveMessage *)inMessage;
{
    unsigned int controllerIndex;
    SMMSysExWindowController *controller;

    if (!controllers) {
        controllers = [[NSMutableArray alloc] init];
    }

    controllerIndex = [controllers count];
    while (controllerIndex--) {
        controller = [controllers objectAtIndex:controllerIndex];
        if ([controller message] == inMessage)
            return controller;
    }
    // TODO when window closes, need to get it out of this array

    controller = [[SMMSysExWindowController alloc] initWithMessage:inMessage];
    [controllers addObject:controller];
    [controller release];

    return controller;
}

- (id)initWithMessage:(SMSystemExclusiveMessage *)inMessage;
{
    if (!(self = [super initWithWindowNibName:@"SysEx"]))
        return nil;

    message = [inMessage retain];

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [message release];
    message = nil;
    
    [super dealloc];
}

- (void)awakeFromNib
{
    [[self window] setFrameAutosaveName:[self windowNibName]];
    // TODO We are not setting the window frame from this setting, though, it doesn't seem. Probably we should do that.
    // (still need to cascade)
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    // TODO stick dump of message into the window
    [textView setString:@"Your SysEx Here"];
}

- (SMSystemExclusiveMessage *)message;
{
    return message;
}

//
// Actions
//


@end


@implementation SMMSysExWindowController (NotificationsDelegatesDataSources)

- (void)windowDidResize:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

- (void)windowDidMove:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

- (void)windowWillClose:(NSNotification *)notification;
{
    [controllers removeObjectIdenticalTo:self];
    // NOTE We've now been released and probably deallocated! Don't do anything else!
}

@end


@implementation SMMSysExWindowController (Private)

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

@end
