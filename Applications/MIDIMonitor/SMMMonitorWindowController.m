#import "SMMMonitorWindowController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>
#import <DisclosableView/DisclosableView.h>

#import "SMMDocument.h"
#import "SMMNonHighlightingCells.h"
#import "SMMPreferencesWindowController.h"
#import "SMMSourcesOutlineView.h"
#import "SMMDetailsWindowController.h"


@interface SMMMonitorWindowController (Private)

- (void)displayPreferencesDidChange:(NSNotification *)notification;

- (void)setupWindowCascading;
- (void)setWindowFrameFromDocument;
- (void)updateDocumentWindowFrameDescription;

- (void)refreshMessagesTableView;
- (void)refreshMessagesTableViewFromScheduledEvent;

- (void)showSysExProgressIndicator;
- (void)hideSysExProgressIndicator;

- (NSArray *)selectedMessagesWithDetails;

- (NSCellStateValue)buttonStateForInputSources:(NSArray *)sources;

- (void)synchronizeDisclosableView:(SNDisclosableView *)view button:(NSButton *)button withIsShown:(BOOL)isShown;

@end


@implementation SMMMonitorWindowController

static NSString *kFromString = nil;
static NSString *kToString = nil;

static const NSTimeInterval kMinimumMessagesRefreshDelay = 0.20; // seconds


+ (void)didLoad
{
    kFromString = [NSLocalizedStringFromTableInBundle(@"From", @"MIDIMonitor", [self bundle], "Prefix for endpoint name when it's a source") retain];
    kToString = [NSLocalizedStringFromTableInBundle(@"To", @"MIDIMonitor", [self bundle], "Prefix for endpoint name when it's a destination") retain];
}

- (id)init;
{
    if (!(self = [super initWithWindowNibName:@"MIDIMonitor"]))
        return nil;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayPreferencesDidChange:) name:SMMDisplayPreferenceChangedNotification object:nil];

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

    [groupedInputSources release];

    [displayedMessages release];

    [nextSysExAnimateDate release];
    nextSysExAnimateDate = nil;

    [nextMessagesRefreshDate release];
    nextMessagesRefreshDate = nil;

    if (nextMessagesRefreshEvent) {
        [[OFScheduler mainScheduler] abortEvent:nextMessagesRefreshEvent];
        [nextMessagesRefreshEvent release];
        nextMessagesRefreshEvent = nil;
    }

    [super dealloc];
}

- (void)windowDidLoad
{
    SMMNonHighlightingButtonCell *checkboxCell;
    SMMNonHighlightingTextFieldCell *textFieldCell;
    
    [super windowDidLoad];
    
    [sourcesOutlineView setOutlineTableColumn:[sourcesOutlineView tableColumnWithIdentifier:@"name"]];
    [sourcesOutlineView setAutoresizesOutlineColumn:NO];

    checkboxCell = [[SMMNonHighlightingButtonCell alloc] initTextCell:@""];
    [checkboxCell setButtonType:NSSwitchButton];
    [checkboxCell setControlSize:NSSmallControlSize];
    [checkboxCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
    [checkboxCell setAllowsMixedState:YES];
    [[sourcesOutlineView tableColumnWithIdentifier:@"enabled"] setDataCell:checkboxCell];
    [checkboxCell release];

    textFieldCell = [[SMMNonHighlightingTextFieldCell alloc] initTextCell:@""];
    [textFieldCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
    [[sourcesOutlineView tableColumnWithIdentifier:@"name"] setDataCell:textFieldCell];
    [textFieldCell release];
    
    filterCheckboxes = [[NSArray alloc] initWithObjects:voiceMessagesCheckBox, systemCommonCheckBox, realTimeCheckBox, systemExclusiveCheckBox, invalidCheckBox, nil];
    filterMatrixCells = [[[[voiceMessagesMatrix cells] arrayByAddingObjectsFromArray:[systemCommonMatrix cells]] arrayByAddingObjectsFromArray:[realTimeMatrix cells]] retain];

    [voiceMessagesCheckBox setAllowsMixedState:YES];
    [systemCommonCheckBox setAllowsMixedState:YES];
    [realTimeCheckBox setAllowsMixedState:YES];
    
    [[maxMessageCountField formatter] setAllowsFloats:NO];
    [[oneChannelField formatter] setAllowsFloats:NO];
    
    [messagesTableView setAutosaveName:@"MessagesTableView2"];
    [messagesTableView setAutosaveTableColumns:YES];
    [messagesTableView setTarget:self];
    [messagesTableView setDoubleAction:@selector(showDetailsOfSelectedMessages:)];

    [self hideSysExProgressIndicator];
}

- (void)setDocument:(NSDocument *)document
{
    [super setDocument:document];

    if (document) {
        [self setupWindowCascading];
        [self window];	// Make sure the window is loaded
        [self synchronizeInterface];
        [self setWindowFrameFromDocument];
    }
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    if ([anItem action] == @selector(copy:)) {
        if ([[self window] firstResponder] == messagesTableView)
            return ([messagesTableView numberOfSelectedRows] > 0);
        else
            return NO;
    } else if ([anItem action] == @selector(showDetailsOfSelectedMessages:)) {
        return ([[self selectedMessagesWithDetails] count] > 0);
    } else {
        return YES;
    }
}

//
// Actions
//

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
    BOOL isShown;

    // Toggle the button immediately, which looks better.
    // NOTE This is absolutely a dumb place to do it, but I CANNOT get it to work any other way. See comment in -synchronizeDisclosableView:button:withIsShown:.
    [sender setIntValue:![sender intValue]];

    isShown = [[self document] isFilterShown];
    [[self document] setIsFilterShown:!isShown];    
}

- (IBAction)toggleSourcesShown:(id)sender;
{
    BOOL isShown;

    // Toggle the button immediately, which looks better.
    // NOTE This is absolutely a dumb place to do it, but I CANNOT get it to work any other way. See comment in -synchronizeDisclosableView:button:withIsShown:.
    [sender setIntValue:![sender intValue]];

    isShown = [[self document] areSourcesShown];
    [[self document] setAreSourcesShown:!isShown];
}

- (IBAction)showDetailsOfSelectedMessages:(id)sender;
{
    NSEnumerator *enumerator;
    SMSystemExclusiveMessage *message;

    enumerator = [[self selectedMessagesWithDetails] objectEnumerator];
    while ((message = [enumerator nextObject]))
        [[SMMDetailsWindowController detailsWindowControllerWithMessage:message] showWindow:nil];
}

- (IBAction)copy:(id)sender;
{
    if ([[self window] firstResponder] == messagesTableView) {
        NSMutableString *totalString;
        NSArray *columns;
        NSEnumerator *rowEnumerator;
        NSNumber *rowNumber;
        NSPasteboard *pasteboard;
    
        totalString = [NSMutableString string];
        columns = [messagesTableView tableColumns];
        
        rowEnumerator = [messagesTableView selectedRowEnumerator];
        while ((rowNumber = [rowEnumerator nextObject])) {
            unsigned int row = [rowNumber intValue];
            NSMutableArray *columnStrings;
            NSEnumerator *columnEnumerator;
            NSTableColumn *column;

            columnStrings = [[NSMutableArray alloc] init];
            
            columnEnumerator = [columns objectEnumerator];
            while ((column = [columnEnumerator nextObject]))
                [columnStrings addObject:[self tableView:messagesTableView objectValueForTableColumn:column row:row]];

            [totalString appendString:[columnStrings componentsJoinedByString:@"\t"]];
            [totalString appendString:@"\n"];

            [columnStrings release];
        }

        pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
        [pasteboard setString:totalString forType:NSStringPboardType];
    }
}

//
// Other API
//

- (void)synchronizeInterface;
{
    [self synchronizeMessagesWithScrollToBottom:NO];
    [self synchronizeSources];
    [self synchronizeSourcesShown];
    [self synchronizeMaxMessageCount];
    [self synchronizeFilterControls];
    [self synchronizeFilterShown];
}

- (void)synchronizeMessagesWithScrollToBottom:(BOOL)shouldScrollToBottom
{
    // Reloading the NSTableView can be excruciatingly slow, and if messages are coming in quickly,
    // we will hog a lot of CPU. So we make sure that we don't do it too often.

    if (shouldScrollToBottom)
        messagesNeedScrollToBottom = YES;

    if (nextMessagesRefreshEvent) {
        // We're going to refresh soon, so don't do anything now.
        return;
    }
    
    if (!nextMessagesRefreshDate || [[NSDate date] isAfterDate:nextMessagesRefreshDate]) {
        // Refresh right away, since we haven't recently.
        [self refreshMessagesTableView];
    } else {
        // We have refreshed recently.
        // Schedule an event to make us refresh when we are next allowed to do so.
        nextMessagesRefreshEvent = [[[OFScheduler mainScheduler] scheduleSelector:@selector(refreshMessagesTableViewFromScheduledEvent) onObject:self atDate:nextMessagesRefreshDate] retain];
    }
}

- (void)synchronizeSources;
{
    NSArray *newGroupedInputSources;

    newGroupedInputSources = [[self document] groupedInputSources];
    if (newGroupedInputSources != groupedInputSources) {
        [groupedInputSources release];
        groupedInputSources = [newGroupedInputSources retain];
    }

    [sourcesOutlineView reloadData];
}

- (void)synchronizeSourcesShown;
{
    [self synchronizeDisclosableView:sourcesDisclosableView button:sourcesDisclosureButton withIsShown:[[self document] areSourcesShown]];
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
    [self synchronizeDisclosableView:filterDisclosableView button:filterDisclosureButton withIsShown:[[self document] isFilterShown]];
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
    [self showSysExProgressIndicator];

    if (!nextSysExAnimateDate || [[NSDate date] isAfterDate:nextSysExAnimateDate]) {
        [sysExProgressIndicator animate:nil];
        [nextSysExAnimateDate release];
        nextSysExAnimateDate = [[NSDate alloc] initWithTimeIntervalSinceNow:[sysExProgressIndicator animationDelay]];
    }
}

- (void)stopSysExReadIndicatorWithBytes:(NSNumber *)bytesReadNumber;
{
    [self hideSysExProgressIndicator];
    [nextSysExAnimateDate release];
    nextSysExAnimateDate = nil;
}

- (void)revealInputSources:(NSSet *)inputSources;
{
    // Of all of the input sources, find the first one which is in the given set.
    // Then expand the outline view to show this source, and scroll it to be visible.

    unsigned int groupCount, groupIndex;

    groupCount = [groupedInputSources count];
    for (groupIndex = 0; groupIndex < groupCount; groupIndex++) {
        NSDictionary *group;
        
        group = [groupedInputSources objectAtIndex:groupIndex];
        if (![[group objectForKey:@"isNotExpandable"] boolValue]) {
            NSArray *groupSources;
            unsigned int groupSourceCount, groupSourceIndex;

            groupSources = [group objectForKey:@"sources"];
            groupSourceCount = [groupSources count];
            for (groupSourceIndex = 0; groupSourceIndex < groupSourceCount; groupSourceIndex++) {
                id source;

                source = [groupSources objectAtIndex:groupSourceIndex];
                if ([inputSources containsObject:source]) {
                    // Found one!
                    [sourcesOutlineView expandItem:group];
                    [sourcesOutlineView scrollRowToVisible:[sourcesOutlineView rowForItem:source]];

                    // And now we're done
                    return;
                }
            }            
        }
    }
}

@end


@implementation SMMMonitorWindowController (NotificationsDelegatesDataSources)

//
// NSWindow delegate
//

- (void)windowDidResize:(NSNotification *)notification;
{
    [self updateDocumentWindowFrameDescription];
}

- (void)windowDidMove:(NSNotification *)notification;
{
    [self updateDocumentWindowFrameDescription];
}


//
// NSOutlineView data source
//

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item;
{
    if (item == nil)
        return [groupedInputSources objectAtIndex:index];
    else
        return [[item objectForKey:@"sources"] objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
{
    return ([item isKindOfClass:[NSDictionary class]] && ![[item objectForKey:@"isNotExpandable"] boolValue]);
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
{
    if (item == nil)
        return [groupedInputSources count];
    else if ([item isKindOfClass:[NSDictionary class]])
        return [[item objectForKey:@"sources"] count];
    else
        return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;
{
    NSString *identifier;
    BOOL isCategory;

    identifier = [tableColumn identifier];
    isCategory = [item isKindOfClass:[NSDictionary class]];
    
    if ([identifier isEqualToString:@"name"]) {
        if (isCategory)
            return [item objectForKey:@"name"];
        else {
            NSString *name;
            NSArray *externalDeviceNames;

            name = [(id<SMInputStreamSource>)item inputStreamSourceName];
            externalDeviceNames = [(id<SMInputStreamSource>)item inputStreamSourceExternalDeviceNames];

            if ([externalDeviceNames count] > 0) {
                return [[name stringByAppendingString:[NSString emdashString]] stringByAppendingString:[externalDeviceNames componentsJoinedByString:@", "]];
            } else {
                return name;
            }
        }
        
    } else if ([identifier isEqualToString:@"enabled"]) {
        NSArray *sources;
        
        if (isCategory)
            sources = [item objectForKey:@"sources"];
        else
            sources = [NSArray arrayWithObject:item];
        
        return [NSNumber numberWithInt:[self buttonStateForInputSources:sources]];
        
    } else {
        return nil;
    }
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;
{
    int newState;
    NSArray *sources;
    NSMutableSet *newSelectedSources;

    newState = [object intValue];
    // It doesn't make sense to switch from off to mixed, so go directly to on
    if (newState == NSMixedState)
        newState = NSOnState;

    if ([item isKindOfClass:[NSDictionary class]])
        sources = [item objectForKey:@"sources"];
    else
        sources = [NSArray arrayWithObject:item];

    newSelectedSources = [NSMutableSet setWithSet:[(SMMDocument *)[self document] selectedInputSources]];
    if (newState == NSOnState)
        [newSelectedSources addObjectsFromArray:sources];
    else
        [newSelectedSources minusSet:[NSSet setWithArray:sources]];

    [(SMMDocument *)[self document] setSelectedInputSources:newSelectedSources];
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
        SMEndpoint *endpoint;

        if ((endpoint = [message originatingEndpoint])) {
            NSString *fromOrTo;

            fromOrTo = ([endpoint isKindOfClass:[SMSourceEndpoint class]] ? kFromString : kToString);
            return [[fromOrTo stringByAppendingString:@" "] stringByAppendingString:[endpoint alwaysUniqueName]];
        } else {
            return @"";            
        }
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

- (void)displayPreferencesDidChange:(NSNotification *)notification;
{
    [messagesTableView reloadData];
}

- (void)setupWindowCascading;
{
    // If the document specifies a window frame, we don't want to cascade.
    // Otherwise, this is a new document, and we do.
    // This must happen before the window is loaded (before we ever call [self window])
    // or it won't take effect.

    BOOL documentHasFrame;
    
    documentHasFrame = ([[self document] windowFrameDescription] != nil);
    [self setShouldCascadeWindows:!documentHasFrame];
}

- (void)setWindowFrameFromDocument;
{
    NSString *frameDescription;

    OBASSERT(sendWindowFrameChangesToDocument == NO);
    
    frameDescription = [[self document] windowFrameDescription];
    if (frameDescription)
        [[self window] setFrameFromString:frameDescription];    

    // From now on, tell the document about any window frame changes
    sendWindowFrameChangesToDocument = YES;
}

- (void)updateDocumentWindowFrameDescription;
{
    if (sendWindowFrameChangesToDocument) {
        NSString *frameDescription;
        
        frameDescription = [[self window] stringWithSavedFrame];
        [[self document] setWindowFrameDescription:frameDescription];
    }
}

- (void)refreshMessagesTableView
{
    NSArray *newMessages;
 
    newMessages = [[self document] savedMessages];

    [displayedMessages release];
    displayedMessages = [newMessages retain];
    
    [messagesTableView reloadData];

    if (messagesNeedScrollToBottom) {
        unsigned int messageCount = [displayedMessages count];
        if (messageCount > 0)
            [messagesTableView scrollRowToVisible:messageCount - 1];

        messagesNeedScrollToBottom = NO;
    }

    // Figure out when we should next be allowed to refresh.
    [nextMessagesRefreshDate release];
    nextMessagesRefreshDate = [[NSDate alloc] initWithTimeIntervalSinceNow:kMinimumMessagesRefreshDelay];
}

- (void)refreshMessagesTableViewFromScheduledEvent
{
    [nextMessagesRefreshEvent release];
    nextMessagesRefreshEvent = nil;

    [self refreshMessagesTableView];
}

- (void)showSysExProgressIndicator;
{
    if (![sysExProgressIndicator superview]) {
        [sysExProgressBox addSubview:sysExProgressIndicator];
        [sysExProgressIndicator release];
        
        [sysExProgressBox addSubview:sysExProgressField];
        [sysExProgressField release];
    }
}

- (void)hideSysExProgressIndicator;
{
    if ([sysExProgressIndicator superview]) {
        [sysExProgressIndicator retain];
        [sysExProgressIndicator removeFromSuperview];
        
        [sysExProgressField retain];
        [sysExProgressField removeFromSuperview];
    }
}

- (NSArray *)selectedMessagesWithDetails;
{
    int selectedRowCount;
    NSEnumerator *rowEnumerator;
    NSNumber *rowNumber;
    NSMutableArray *messages;

    selectedRowCount = [messagesTableView numberOfSelectedRows];
    if (selectedRowCount == 0)
        return [NSArray array];

    messages = [NSMutableArray arrayWithCapacity:selectedRowCount];

    rowEnumerator = [messagesTableView selectedRowEnumerator];
    while ((rowNumber = [rowEnumerator nextObject])) {
        SMMessage *message = [displayedMessages objectAtIndex:[rowNumber unsignedIntValue]];
        if ([SMMDetailsWindowController canShowDetailsForMessage:message])
            [messages addObject:message];
    }

    return messages;
}

- (NSCellStateValue)buttonStateForInputSources:(NSArray *)sources;
{
    NSSet *selectedSources;
    unsigned int sourceIndex;
    BOOL areAnySelected = NO, areAnyNotSelected = NO;
    
    selectedSources = [(SMMDocument *)[self document] selectedInputSources];
    sourceIndex = [sources count];
    while (sourceIndex--) {
        if ([selectedSources containsObject:[sources objectAtIndex:sourceIndex]])
            areAnySelected = YES;
        else
            areAnyNotSelected = YES;

        if (areAnySelected && areAnyNotSelected)
            return NSMixedState;
    }

    return areAnySelected ? NSOnState : NSOffState;
}

- (void)synchronizeDisclosableView:(SNDisclosableView *)view button:(NSButton *)button withIsShown:(BOOL)isShown;
{
    BOOL savedSendWindowFrameChangesToDocument;

    // Temporarily stop sending window frame changes to the document,
    // while we're doing the animated resize.
    savedSendWindowFrameChangesToDocument = sendWindowFrameChangesToDocument;
    sendWindowFrameChangesToDocument = NO;

    // NOTE We ought to be able to swap these to get the button to draw first. However, that just doesn't work, and I can't figure out why. Grrr!
    [view setIsShown:isShown];
    [button setIntValue:(isShown ? 1 : 0)];

    sendWindowFrameChangesToDocument = savedSendWindowFrameChangesToDocument;
    // Now we can update the document, once instead of many times.
    [self updateDocumentWindowFrameDescription];
}

@end
