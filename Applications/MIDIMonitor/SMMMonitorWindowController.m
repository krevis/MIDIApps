#import "SMMMonitorWindowController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "NSPopUpButton-MIDIMonitorExtensions.h"
#import "SMMDisclosableView.h"
#import "SMMDocument.h"
#import "SMMPreferencesWindowController.h"
#import "SMMSysExWindowController.h"


@interface SMMMonitorWindowController (Private)

- (void)_displayPreferencesDidChange:(NSNotification *)notification;

- (void)_setupWindowCascading;
- (void)_setWindowFrameFromDocument;
- (void)_updateDocumentWindowFrameDescription;

- (void)_showSysExProgressIndicator;
- (void)_hideSysExProgressIndicator;

- (BOOL)_canShowSelectedMessageDetails;

@end


@implementation SMMMonitorWindowController

- (id)init;
{
    if (!(self = [super initWithWindowNibName:@"MIDIMonitor"]))
        return nil;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_displayPreferencesDidChange:) name:SMMDisplayPreferenceChangedNotification object:nil];

    oneChannel = 1;

    displayedMessages = nil;

    // We don't want to tell our document about window frame changes while we are still in the middle
    // of loading it, because we may do some resizing.
    sendWindowFrameChangesToDocument = NO;

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (![sysExProgressIndicator superview]) {
        [sysExProgressIndicator release];
        [sysExProgressField release];
    }

    [filterCheckboxes release];
    [filterMatrixCells release];

    [displayedMessages release];

    [nextSysExAnimateDate release];
    nextSysExAnimateDate = nil;

    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    filterCheckboxes = [[NSArray alloc] initWithObjects:voiceMessagesCheckBox, systemCommonCheckBox, realTimeCheckBox, systemExclusiveCheckBox, nil];
    filterMatrixCells = [[[[voiceMessagesMatrix cells] arrayByAddingObjectsFromArray:[systemCommonMatrix cells]] arrayByAddingObjectsFromArray:[realTimeMatrix cells]] retain];

    [voiceMessagesCheckBox setAllowsMixedState:YES];
    [systemCommonCheckBox setAllowsMixedState:YES];
    [realTimeCheckBox setAllowsMixedState:YES];
    
    [[maxMessageCountField formatter] setAllowsFloats:NO];
    [[oneChannelField formatter] setAllowsFloats:NO];
    
    [messagesTableView setAutosaveName:@"MessagesTableView"];
    [messagesTableView setAutosaveTableColumns:YES];
    [messagesTableView setTarget:self];
    [messagesTableView setDoubleAction:@selector(showSelectedMessageDetails:)];

    [filterDisclosableView setHiddenHeight:10];	// TODO This is sort of hacky but I'm not sure how to calculate this based on the nib
    
    [self _hideSysExProgressIndicator];
}

- (void)setDocument:(NSDocument *)document
{
    [super setDocument:document];

    if (document) {
        [self _setupWindowCascading];
        [self window];	// Make sure the window is loaded
        [self synchronizeInterface];
        [self _setWindowFrameFromDocument];
    }
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    if ([anItem action] == @selector(showSelectedMessageDetails:)) {
        return [self _canShowSelectedMessageDetails];
    } else {
        return YES;
    }
}

//
// Actions
//

- (IBAction)selectSource:(id)sender;
{
    SMMDocument *document;
    id source;
    NSArray *selectedSources;
    NSArray *newSelectedSources;

    source = [(NSMenuItem *)[sender selectedItem] representedObject];    
    document = [self document];
    selectedSources = [document selectedInputSources];

    if ([selectedSources indexOfObject:source] == NSNotFound)
        newSelectedSources = [selectedSources arrayByAddingObject:source];
    else
        newSelectedSources = [selectedSources arrayByRemovingObjectIdenticalTo:source];

    [document setSelectedInputSources:newSelectedSources];
}

- (IBAction)clearMessages:(id)sender;
{
    [[self document] clearSavedMessages];
}

- (IBAction)setMaximumMessageCount:(id)sender;
{
    NSNumber *number;
    unsigned int maxMessageCount;
    
    if ((number = [sender objectValue])) {
        maxMessageCount = [number unsignedIntValue];
        [[self document] setMaxMessageCount:maxMessageCount];
    } else {
        [self synchronizeMaxMessageCount];
    }
}

- (IBAction)changeFilter:(id)sender;
{
    BOOL turnBitsOn;

    switch ([sender state]) {
        case NSOnState:
        case NSMixedState:	// Changing from off to mixed state should be the same as changing to all-on
            turnBitsOn = YES;
            break;
            
        case NSOffState:
        default:
            turnBitsOn = NO;
            break;
    }
    
    [[self document] changeFilterMask:[sender tag] turnBitsOn:turnBitsOn];
}

- (IBAction)changeFilterFromMatrix:(id)sender;
{
    [self changeFilter:[sender selectedCell]];
}

- (IBAction)setChannelRadioButton:(id)sender;
{
    if ([[sender selectedCell] tag] == 0) {
        [[self document] showAllChannels];
    } else {
        [[self document] showOnlyOneChannel:oneChannel];
    }
}

- (IBAction)setChannel:(id)sender;
{
    [[self document] showOnlyOneChannel:[(NSNumber *)[sender objectValue] unsignedIntValue]];
}

- (IBAction)toggleFilterShown:(id)sender;
{
    BOOL isFilterShown;
    
    isFilterShown = [[self document] isFilterShown];
    [[self document] setIsFilterShown:!isFilterShown];
}

- (IBAction)showSelectedMessageDetails:(id)sender;
{
    if ([self _canShowSelectedMessageDetails]) {
        SMSystemExclusiveMessage *message;
        SMMSysExWindowController *sysExWindowController;

        message = [displayedMessages objectAtIndex:[messagesTableView selectedRow]];
        sysExWindowController = [SMMSysExWindowController sysExWindowControllerWithMessage:message];
        [sysExWindowController showWindow:nil];        
    }
}

//
// Other API
//

- (void)synchronizeInterface;
{
    [self synchronizeMessages];
    [self synchronizeSources];
    [self synchronizeMaxMessageCount];
    [self synchronizeFilterControls];
    [self synchronizeFilterShown];
}

- (void)synchronizeMessages;
{
    NSArray *newMessages;

    newMessages = [[self document] savedMessages];

    [displayedMessages release];
    displayedMessages = [newMessages retain];

    [messagesTableView reloadData];
}

- (void)synchronizeSources;
{
    BOOL wasAutodisplay;
    int itemCount;
    NSArray *groupedSources;
    NSArray *selectedSources;
    unsigned int groupCount, groupIndex;

    // The pop up button redraws whenever it's changed, so turn off autodisplay to stop the blinkiness
    wasAutodisplay = [[self window] isAutodisplay];
    [[self window] setAutodisplay:NO];

    // Remove all items in the menu except for the first one (which is displayed as the title)
    for (itemCount = [sourcePopUpButton numberOfItems]; itemCount > 1; itemCount--)
        [sourcePopUpButton removeItemAtIndex:itemCount - 1];

    groupedSources = [[self document] groupedInputSources];
    selectedSources = [[self document] selectedInputSources];

    groupCount = [groupedSources count];
    for (groupIndex = 0; groupIndex < groupCount; groupIndex++) {
        NSArray *sources;
        unsigned int sourceCount, sourceIndex;

        sources = [groupedSources objectAtIndex:groupIndex];
        sourceCount = [sources count];

        if ([sourcePopUpButton numberOfItems] > 1 && sourceCount > 0)
            [sourcePopUpButton addSeparatorItem];
        
        for (sourceIndex = 0; sourceIndex < sourceCount; sourceIndex++) {
            id <SMInputStreamSource> source;
            id <NSMenuItem> item;

            source = [sources objectAtIndex:sourceIndex];
            item = [sourcePopUpButton addItemWithTitle:[source inputStreamSourceName] representedObject:source];

            if ([selectedSources indexOfObject:source] != NSNotFound)
                [item setState:NSOnState];
        }
    }
        
    // ...and turn autodisplay on again
    if (wasAutodisplay)
        [[self window] displayIfNeeded];
    [[self window] setAutodisplay:wasAutodisplay];
}

- (void)synchronizeMaxMessageCount;
{
    unsigned int maxMessageCount;
    
    maxMessageCount = [[self document] maxMessageCount];    
    [maxMessageCountField setObjectValue:[NSNumber numberWithUnsignedInt:maxMessageCount]];
}

- (void)synchronizeFilterControls;
{
    SMMessageType currentMask;
    unsigned int buttonIndex;

    currentMask = [[self document] filterMask];
        
    buttonIndex = [filterCheckboxes count];
    while (buttonIndex--) {
        NSButton *checkbox;
        SMMessageType buttonMask;
        int newState;
        
        checkbox = [filterCheckboxes objectAtIndex:buttonIndex];
        buttonMask = [checkbox tag];

        if ((currentMask & buttonMask) == buttonMask)
            newState = NSOnState;
        else if ((currentMask & buttonMask) == 0)
            newState = NSOffState;
        else
            newState = NSMixedState;

        [checkbox setState:newState];
    }

    buttonIndex = [filterMatrixCells count];
    while (buttonIndex--) {
        NSButtonCell *checkbox;
        SMMessageType buttonMask;
        int newState;
        
        checkbox = [filterMatrixCells objectAtIndex:buttonIndex];
        buttonMask = [checkbox tag];
        if ((currentMask & buttonMask) == buttonMask)
            newState = NSOnState;
        else
            newState = NSOffState;

        [checkbox setState:newState];
    }

    if ([[self document] isShowingAllChannels]) {
        [channelRadioButtons selectCellWithTag:0];
        [oneChannelField setEnabled:NO];
    } else {
        [channelRadioButtons selectCellWithTag:1];
        [oneChannelField setEnabled:YES];
        oneChannel = [[self document] oneChannelToShow];
    }
    [oneChannelField setObjectValue:[NSNumber numberWithUnsignedInt:oneChannel]];
}

- (void)synchronizeFilterShown;
{
    BOOL savedSendWindowFrameChangesToDocument;
    BOOL isShown;

    // Temporarily stop sending window frame changes to the document,
    // while we're doing the animated resize.
    savedSendWindowFrameChangesToDocument = sendWindowFrameChangesToDocument;
    sendWindowFrameChangesToDocument = NO;

    isShown = [[self document] isFilterShown];
    [filterDisclosableView setIsShown:isShown];
    [filterDisclosureButton setIntValue:(isShown ? 1 : 0)];

    sendWindowFrameChangesToDocument = savedSendWindowFrameChangesToDocument;
    // Now we can update the document, once instead of many times.
    [self _updateDocumentWindowFrameDescription];
}

- (void)scrollToLastMessage;
{
    if ([displayedMessages count] > 0)
        [messagesTableView scrollRowToVisible:[displayedMessages count] - 1];
}

- (void)couldNotFindSourcesNamed:(NSArray *)sourceNames;
{
    NSString *title, *message;
    unsigned int sourceNamesCount;

    sourceNamesCount = [sourceNames count];

    if (sourceNamesCount == 0) {
        return;
    } else if (sourceNamesCount == 1) {
        NSString *messageFormat;
        
        title = NSLocalizedStringFromTableInBundle(@"Missing Source", @"MIDIMonitor", [self bundle], "if document's source is missing, title of sheet");    
        messageFormat = NSLocalizedStringFromTableInBundle(@"The source named \"%@\" could not be found.", @"MIDIMonitor", [self bundle], "if document's source is missing, message in sheet (with source name)");
        message = [NSString stringWithFormat:messageFormat, [sourceNames objectAtIndex:0]];
    } else {
        NSMutableArray *sourceNamesInQuotes;
        unsigned int sourceNamesIndex;
        NSString *concatenatedSourceNames;
        NSString *messageFormat;
        
        title = NSLocalizedStringFromTableInBundle(@"Missing Sources", @"MIDIMonitor", [self bundle], "if more than one of document's sources are missing, title of sheet");

        sourceNamesInQuotes = [NSMutableArray arrayWithCapacity:sourceNamesCount];
        for (sourceNamesIndex = 0; sourceNamesIndex < sourceNamesCount; sourceNamesIndex++)
            [sourceNamesInQuotes addObject:[NSString stringWithFormat:@"\"%@\"", [sourceNames objectAtIndex:sourceNamesIndex]]];

        concatenatedSourceNames = [sourceNamesInQuotes componentsJoinedByCommaAndAnd];
        
        messageFormat = NSLocalizedStringFromTableInBundle(@"The sources named %@ could not be found.", @"MIDIMonitor", [self bundle], "if more than one of document's sources are missing, message in sheet (with source names)");

        message = [NSString stringWithFormat:messageFormat, concatenatedSourceNames];        
    }

    NSBeginAlertSheet(title, nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"%@", message);
}

- (void)updateSysExReadIndicatorWithBytes:(NSNumber *)bytesReadNumber;
{
    [self _showSysExProgressIndicator];

    if (!nextSysExAnimateDate || [[NSDate date] isAfterDate:nextSysExAnimateDate]) {
        [sysExProgressIndicator animate:nil];
        [nextSysExAnimateDate release];
        nextSysExAnimateDate = [[NSDate alloc] initWithTimeIntervalSinceNow:[sysExProgressIndicator animationDelay]];
    }
}

- (void)stopSysExReadIndicatorWithBytes:(NSNumber *)bytesReadNumber;
{
    [self _hideSysExProgressIndicator];
    [nextSysExAnimateDate release];
    nextSysExAnimateDate = nil;
}

@end


@implementation SMMMonitorWindowController (NotificationsDelegatesDataSources)

//
// NSWindow delegate
//

- (void)windowDidResize:(NSNotification *)notification;
{
    [self _updateDocumentWindowFrameDescription];
}

- (void)windowDidMove:(NSNotification *)notification;
{
    [self _updateDocumentWindowFrameDescription];
}


//
// NSTableView data source
//

- (int)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [displayedMessages count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    NSString *identifier;
    SMMessage *message = nil;

    message = [displayedMessages objectAtIndex:row];

    identifier = [tableColumn identifier];
    if ([identifier isEqualToString:@"timeStamp"]) {
        return [message timeStampForDisplay];
    } else if ([identifier isEqualToString:@"source"]) {
        return [[message originatingEndpoint] shortName];
        // TODO we should indicate if name is a regular source, or spying on a destination
    } else if ([identifier isEqualToString:@"type"]) {
        return [message typeForDisplay];
    } else if ([identifier isEqualToString:@"channel"]) {
        return [message channelForDisplay];
    } else if ([identifier isEqualToString:@"data"]) {
        return [message dataForDisplay];
    } else {
        return nil;
    }
}

@end


@implementation SMMMonitorWindowController (Private)

- (void)_displayPreferencesDidChange:(NSNotification *)notification;
{
    [messagesTableView reloadData];
}

- (void)_setupWindowCascading;
{
    // If the document specifies a window frame, we don't want to cascade.
    // Otherwise, this is a new document, and we do.
    // This must happen before the window is loaded (before we ever call [self window])
    // or it won't take effect.

    BOOL documentHasFrame;
    
    documentHasFrame = ([[self document] windowFrameDescription] != nil);
    [self setShouldCascadeWindows:!documentHasFrame];
}

- (void)_setWindowFrameFromDocument;
{
    NSString *frameDescription;

    OBASSERT(sendWindowFrameChangesToDocument == NO);
    
    frameDescription = [[self document] windowFrameDescription];
    if (frameDescription)
        [[self window] setFrameFromString:frameDescription];    

    // From now on, tell the document about any window frame changes
    sendWindowFrameChangesToDocument = YES;
}

- (void)_updateDocumentWindowFrameDescription;
{
    if (sendWindowFrameChangesToDocument) {
        NSString *frameDescription;
        
        frameDescription = [[self window] stringWithSavedFrame];
        [[self document] setWindowFrameDescription:frameDescription];
    }
}

- (void)_showSysExProgressIndicator;
{
    if (![sysExProgressIndicator superview]) {
        [sysExProgressBox addSubview:sysExProgressIndicator];
        [sysExProgressIndicator release];
        
        [sysExProgressBox addSubview:sysExProgressField];
        [sysExProgressField release];
    }
}

- (void)_hideSysExProgressIndicator;
{
    if ([sysExProgressIndicator superview]) {
        [sysExProgressIndicator retain];
        [sysExProgressIndicator removeFromSuperview];
        
        [sysExProgressField retain];
        [sysExProgressField removeFromSuperview];
    }
}

- (BOOL)_canShowSelectedMessageDetails;
{
    int selectedRow;

    selectedRow = [messagesTableView selectedRow];
    if (selectedRow < 0)
        return NO;

    return [[displayedMessages objectAtIndex:selectedRow] isKindOfClass:[SMSystemExclusiveMessage class]];
}

@end
