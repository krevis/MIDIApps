#import "SSEMainWindowController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "NSPopUpButton-Extensions.h"
#import "SSELibrary.h"
#import "SSELibraryEntry.h"
#import "SSEMainController.h"


@interface SSEMainWindowController (Private)

- (void)_autosaveWindowFrame;

- (void)_synchronizePopUpButton:(NSPopUpButton *)popUpButton withDescriptions:(NSArray *)descriptions currentDescription:(NSDictionary *)currentDescription;

- (void)_openPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void  *)contextInfo;

- (void)_sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)_updateSysExReadIndicator;
- (void)_updateSingleSysExReadIndicatorWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;
- (void)_updateMultipleSysExReadIndicatorWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;

- (void)_updatePlayProgressAndRepeat;
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

    library = [[SSELibrary alloc] init];
    
    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [progressUpdateEvent release];
    progressUpdateEvent = nil;
    
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
    NSOpenPanel *openPanel;

    openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
    // TODO should specify types
    // TODO it would be cool to be able to specify a directory, and then get all the appropriate files out of it
}

- (IBAction)delete:(id)sender;
{
    // TODO
    // delete the selected files from the library
    // this should also be hooked up via delete key in the table view
    // should only be enabled when file(s) are selected in the library
    // should we have a confirmation dialog?
    // ask whether to delete the file or just the reference? (see how Project Builder or iTunes do it)
}

- (IBAction)recordOne:(id)sender;
{
    [self _updateSingleSysExReadIndicatorWithMessageCount:0 bytesRead:0 totalBytesRead:0];

    [[NSApplication sharedApplication] beginSheet:recordSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];    

    [mainController listenForOneMessage];
}

- (IBAction)recordMultiple:(id)sender;
{
    [self _updateMultipleSysExReadIndicatorWithMessageCount:0 bytesRead:0 totalBytesRead:0];

    [[NSApplication sharedApplication] beginSheet:recordMultipleSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];

    [mainController listenForMultipleMessages];
}

- (IBAction)play:(id)sender;
{
    int selectedRow;
    NSArray *messages;

    selectedRow = [libraryTableView selectedRow];
    OBASSERT(selectedRow != -1);

    messages = [[[library entries] objectAtIndex:selectedRow] messages];
    [mainController setMessages:messages];
    [mainController sendMessages];
}

- (IBAction)cancelRecordSheet:(id)sender;
{
    [mainController cancelMessageListen];
    [[NSApplication sharedApplication] endSheet:[[self window] attachedSheet]];
}

- (IBAction)doneWithRecordMultipleSheet:(id)sender;
{
    [mainController doneWithMultipleMessageListen];
    [[NSApplication sharedApplication] endSheet:recordMultipleSheetWindow];
}

- (IBAction)cancelPlaySheet:(id)sender;
{
    [mainController cancelSendingMessages];
    // -hideSysExSendStatusWithSuccess: will get called soon; it will end the sheet
}

//
// Other API
//

- (void)synchronizeInterface;
{
    [self synchronizeSources];
    [self synchronizeDestinations];
    [self synchronizeLibrary];
    [self synchronizePlayButton];
}

- (void)synchronizeSources;
{
    [self _synchronizePopUpButton:sourcePopUpButton withDescriptions:[mainController sourceDescriptions] currentDescription:[mainController sourceDescription]];
}

- (void)synchronizeDestinations;
{
    [self _synchronizePopUpButton:destinationPopUpButton withDescriptions:[mainController destinationDescriptions] currentDescription:[mainController destinationDescription]];
}

- (void)synchronizeLibrary;
{
    // TODO may need code to keep selection
    [libraryTableView reloadData];
}

- (void)synchronizePlayButton;
{
    [playButton setEnabled:([libraryTableView numberOfSelectedRows] > 0)];
}


//
// Reading SysEx
//

- (void)updateSysExReadIndicator;
{
    if (!progressUpdateEvent) {
        progressUpdateEvent = [[[OFScheduler mainScheduler] scheduleSelector:@selector(_updateSysExReadIndicator) onObject:self afterTime:[recordProgressIndicator animationDelay]] retain];
    }
}

- (void)stopSysExReadIndicator;
{
    // If there is an update pending, try to cancel it. If that succeeds, then we know the event never happened, and we do it ourself now.
    if (progressUpdateEvent && [[OFScheduler mainScheduler] abortEvent:progressUpdateEvent])
        [progressUpdateEvent invoke];

    // Close the sheet, after a little bit of a delay (makes it look nicer)
    [[NSApplication sharedApplication] performSelector:@selector(endSheet:) withObject:[[self window] attachedSheet] afterDelay:0.5];
}

//
// Sending SysEx
//

- (void)showSysExSendStatus;
{
    unsigned int bytesToSend;

    [playProgressIndicator setMinValue:0.0];
    [playProgressIndicator setDoubleValue:0.0];
    [mainController getMessageCount:NULL messageIndex:NULL bytesToSend:&bytesToSend bytesSent:NULL];
    [playProgressIndicator setMaxValue:bytesToSend];

    [self _updatePlayProgressAndRepeat];

    [[NSApplication sharedApplication] beginSheet:playSheetWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)hideSysExSendStatusWithSuccess:(BOOL)success;
{
    // If there is an update pending, try to cancel it. If that succeeds, then we know the event never happened, and we do it ourself now.
    if (progressUpdateEvent && [[OFScheduler mainScheduler] abortEvent:progressUpdateEvent]) {
        [self _updatePlayProgress];
        [progressUpdateEvent release];
        progressUpdateEvent = nil;
    }
    
    if (!success) {
        [playProgressMessageField setStringValue:@"Cancelled."];
            // TODO localize
    }

    // Even if we have set the progress indicator to its maximum value, it won't get drawn on the screen that way immediately,
    // probably because it tries to smoothly animate to that state. The only way I have found to show the maximum value is to just
    // wait a little while for the animation to finish. This looks nice, too.
    [[NSApplication sharedApplication] performSelector:@selector(endSheet:) withObject:playSheetWindow afterDelay:0.5];    
}

@end


@implementation SSEMainWindowController (NotificationsDelegatesDataSources)

//
// Window delegate
//

- (void)windowDidResize:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

- (void)windowDidMove:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

//
// NSTableView data source
//

- (int)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [[library entries] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    SSELibraryEntry *entry;

    entry = [[library entries] objectAtIndex:row];
    return [entry name];
}

//
// NSTableView notifications
//

- (void)tableViewSelectionDidChange:(NSNotification *)notification;
{
    [self synchronizePlayButton];
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

- (void)_openPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void  *)contextInfo;
{
    NSArray *filePaths;
    unsigned int fileIndex, fileCount;

    if (returnCode != NSOKButton)
        return;

    filePaths = [openPanel filenames];
    fileCount = [filePaths count];
    for (fileIndex = 0; fileIndex < fileCount; fileIndex++) {
        [library addEntryForFile:[filePaths objectAtIndex:fileIndex]];
    }

    [self synchronizeInterface];

    // TODO we ought to select the new entry (the first one if there are more than one) and scroll to it
}

- (void)_sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    // At this point, we don't really care how this sheet ended
    [sheet orderOut:nil];
}

- (void)_updateSysExReadIndicator;
{
    unsigned int messageCount, bytesRead, totalBytesRead;

    [mainController getMessageCount:&messageCount bytesRead:&bytesRead totalBytesRead:&totalBytesRead];

    if ([[self window] attachedSheet] == recordSheetWindow)
        [self _updateSingleSysExReadIndicatorWithMessageCount:messageCount bytesRead:bytesRead totalBytesRead:totalBytesRead];
    else
        [self _updateMultipleSysExReadIndicatorWithMessageCount:messageCount bytesRead:bytesRead totalBytesRead:totalBytesRead];

    [progressUpdateEvent release];
    progressUpdateEvent = nil;
}

- (void)_updateSingleSysExReadIndicatorWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;
{
    if ((bytesRead == 0 && messageCount == 0)) {
        [recordProgressMessageField setStringValue:@"Waiting for SysEx message..."]; // TODO localize
        [recordProgressBytesField setStringValue:@""];
    } else {
        [recordProgressIndicator animate:nil];
        [recordProgressMessageField setStringValue:@"Receiving SysEx message..."];	// TODO localize
        [recordProgressBytesField setStringValue:[NSString abbreviatedStringForBytes:bytesRead + totalBytesRead]];
    }
}

- (void)_updateMultipleSysExReadIndicatorWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;
{
    NSString *totalProgress;
    BOOL hasAtLeastOneCompleteMessage;

    if (bytesRead == 0) {
        [recordMultipleProgressMessageField setStringValue:@"Waiting for SysEx message..."]; 	// TODO localize
        [recordMultipleProgressBytesField setStringValue:@""];
    } else {
        [recordMultipleProgressIndicator animate:nil];
        [recordMultipleProgressMessageField setStringValue:@"Receiving SysEx message..."]; 	// TODO localize
        [recordMultipleProgressBytesField setStringValue:[NSString abbreviatedStringForBytes:bytesRead]];
    }

    hasAtLeastOneCompleteMessage = (messageCount > 0);
    if (hasAtLeastOneCompleteMessage) {
        totalProgress = [NSString stringWithFormat:@"Total: %u message%@, %@", messageCount, (messageCount > 1) ? @"s" : @"", [NSString abbreviatedStringForBytes:totalBytesRead]];
        // TODO localize -- the "s" vs "" trick will have to change
    } else {
        totalProgress = @"";
    }

    [recordMultipleTotalProgressField setStringValue:totalProgress];
    [recordMultipleDoneButton setEnabled:hasAtLeastOneCompleteMessage];
}

- (void)_updatePlayProgressAndRepeat;
{
    [self _updatePlayProgress];

    [progressUpdateEvent release];
    progressUpdateEvent = [[[OFScheduler mainScheduler] scheduleSelector:@selector(_updatePlayProgressAndRepeat) onObject:self afterTime:[playProgressIndicator animationDelay]] retain];
}

- (void)_updatePlayProgress;
{
    unsigned int messageIndex, messageCount, bytesToSend, bytesSent;
    NSString *message;

    [mainController getMessageCount:&messageCount messageIndex:&messageIndex bytesToSend:&bytesToSend bytesSent:&bytesSent];

    OBASSERT(bytesSent >= [playProgressIndicator doubleValue]);
        // Make sure we don't go backwards somehow
        
    [playProgressIndicator setDoubleValue:bytesSent];
    [playProgressBytesField setStringValue:[NSString abbreviatedStringForBytes:bytesSent]];
    if (bytesSent < bytesToSend) {
        if (messageCount > 1)
            message = [NSString stringWithFormat:@"Sending message %u of %u...", messageIndex+1, messageCount];
        else
            message = @"Sending message...";
    } else {
        message = @"Done.";
    }
        // TODO localize all of the above
    [playProgressMessageField setStringValue:message];
}

@end
