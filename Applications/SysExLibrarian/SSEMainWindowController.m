#import "SSEMainWindowController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "NSPopUpButton-Extensions.h"
#import "SSEMainController.h"


@interface SSEMainWindowController (Private)

- (void)_autosaveWindowFrame;

- (void)_synchronizePopUpButton:(NSPopUpButton *)popUpButton withDescriptions:(NSArray *)descriptions currentDescription:(NSDictionary *)currentDescription;

- (void)_recordSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)_playSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)_updatePlayProgress;

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
    [nextSysExAnimateDate release];
    nextSysExAnimateDate = nil;

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

- (IBAction)open:(id)sender;
{
    // TODO
    // using standard open file sheet,
    // open a file
    // (what file types, etc. are acceptable?)
    // then add it to the library
    // should allow multiple file selection
}

- (IBAction)delete:(id)sender;
{
    // TODO
    // delete the selected files from the library
    // this should also be hooked up via delete key in the table view
    // should only be enabled when file(s) are selected in the library
    // should we have a confirmation dialog?
    // ask whether to delete the file or just the reference? (see how Project Builder does it)
}

- (IBAction)recordOne:(id)sender;
{
    [recordSheetTabView selectTabViewItemWithIdentifier:@"waiting"];    
    [[NSApplication sharedApplication] beginSheet:recordSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_recordSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];    
    [mainController waitForOneSysExMessage];
}

- (IBAction)record:(id)sender;
{
    // TODO
    // similar to recordOne:, but don't terminate the sheet after one message comes in.
    // instead, keep recording the messages, until a "done" button is pressed (or cancel).
}

- (IBAction)play:(id)sender;
{
    // TODO
    // disable if no files are selected.

    [mainController playSysExMessage];
}

- (IBAction)cancelRecordSheet:(id)sender;
{
    [mainController cancelSysExMessageWait];
    [[NSApplication sharedApplication] endSheet:recordSheetWindow returnCode:NSRunAbortedResponse];
}

- (IBAction)cancelPlaySheet:(id)sender;
{
    [mainController cancelPlayingSysExMessage];
    [[NSApplication sharedApplication] endSheet:playSheetWindow returnCode:NSRunAbortedResponse];
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

- (void)updateSysExReadIndicatorWithBytes:(unsigned int)bytesRead;
{
    [recordSheetTabView selectTabViewItemWithIdentifier:@"receiving"];    

    if (!nextSysExAnimateDate || [[NSDate date] isAfterDate:nextSysExAnimateDate]) {
        [recordProgressIndicator animate:nil];
        [nextSysExAnimateDate release];
        nextSysExAnimateDate = [[NSDate alloc] initWithTimeIntervalSinceNow:[recordProgressIndicator animationDelay]];

        [recordProgressField setStringValue:[@"Received " stringByAppendingString:[NSString abbreviatedStringForBytes:bytesRead]]];
        // TODO localize
    }
}

- (void)stopSysExReadIndicatorWithBytes:(unsigned int)bytesRead;
{
    [nextSysExAnimateDate release];
    nextSysExAnimateDate = nil;

    [[NSApplication sharedApplication] endSheet:recordSheetWindow returnCode:NSRunStoppedResponse];
}

- (void)showSysExSendStatusWithBytesToSend:(unsigned int)bytesToSend;
{
    [playProgressIndicator setMinValue:0.0];
    [playProgressIndicator setMaxValue:bytesToSend];

    [self _updatePlayProgress];
    [[NSApplication sharedApplication] beginSheet:playSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_playSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)hideSysExSendStatus;
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updatePlayProgress) object:nil];
    [self _updatePlayProgress];

    [[NSApplication sharedApplication] endSheet:playSheetWindow returnCode:NSRunStoppedResponse];
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

- (void)_recordSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    switch (returnCode) {
        case NSRunAbortedResponse:
            // User pressed "cancel"
            // TODO
            break;

        case NSRunStoppedResponse:
            // Success
            // TODO
            break;

        default:
            NSLog(@"Unknown return code in -[%@ %@]: %d", NSStringFromClass([self class]), NSStringFromSelector(_cmd), returnCode);
            break;
    }

    [sheet orderOut:nil];
}

- (void)_playSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    // At this point, we don't really care how this sheet ended
    [sheet orderOut:nil];
}

- (void)_updatePlayProgress;
{
    unsigned int bytesSent;

    bytesSent = [mainController sysExBytesSent];
    [playProgressIndicator setDoubleValue:bytesSent];
    [playProgressField setStringValue:[@"Sent " stringByAppendingString:[NSString abbreviatedStringForBytes:bytesSent]]];
    // TODO localize

    [self performSelector:_cmd withObject:nil afterDelay:[playProgressIndicator animationDelay]];
}

@end
