#import "SMMMonitorWindowController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "NSPopUpButton-MIDIMonitorExtensions.h"
#import "SMMDocument.h"
#import "SMMPreferencesWindowController.h"
#import "SMMDisclosableView.h"
#import "SMMSysExRow.h"


@interface SMMMonitorWindowController (Private)

- (void)_displayPreferencesDidChange:(NSNotification *)notification;
- (void)_sysExBytesPerRowDidChange:(NSNotification *)notification;

- (NSArray *)_sysExRowsForMessage:(SMSystemExclusiveMessage *)message;
- (void)_removeSysExRowsForMessagesNotIn:(NSArray *)newMessages;

- (void)_setupWindowCascading;
- (void)_setWindowFrameFromDocument;
- (void)_updateDocumentWindowFrameDescription;

- (void)_showSysExProgressIndicator;
- (void)_hideSysExProgressIndicator;

@end


@implementation SMMMonitorWindowController

- (id)init;
{
    if (!(self = [super initWithWindowNibName:@"MIDIMonitor"]))
        return nil;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_displayPreferencesDidChange:) name:SMMDisplayPreferenceChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_sysExBytesPerRowDidChange:) name:SMMSysExBytesPerRowPreferenceChangedNotification object:nil];

    oneChannel = 1;

    displayedMessages = nil;
    sysExRowsMapTable = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 10);

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
    NSFreeMapTable(sysExRowsMapTable);

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
    
    [messagesOutlineView setAutosaveName:@"MessagesOutlineView2"];
        // NOTE: Added the 2 so that old saved values (pre-1.0) don't make the outline column too small
    [messagesOutlineView setAutosaveTableColumns:YES];

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

//
// Actions
//

- (IBAction)selectSource:(id)sender;
{
    [[self document] setSourceDescription:[(NSMenuItem *)[sender selectedItem] representedObject]];
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
    [self _removeSysExRowsForMessagesNotIn:newMessages];

    [displayedMessages release];
    displayedMessages = [newMessages retain];

    [messagesOutlineView reloadData];
}

- (void)synchronizeSources;
{
    NSDictionary *currentDescription;
    BOOL wasAutodisplay;
    NSArray *descriptions;
    unsigned int sourceCount, sourceIndex;
    BOOL foundSource = NO;
    BOOL addedSeparatorBetweenPortAndVirtual = NO;

    currentDescription = [[self document] sourceDescription];

    // The pop up button redraws whenever it's changed, so turn off autodisplay to stop the blinkiness
    wasAutodisplay = [[self window] isAutodisplay];
    [[self window] setAutodisplay:NO];

    [sourcePopUpButton removeAllItems];

    descriptions = [[self document] sourceDescriptions];
    sourceCount = [descriptions count];
    for (sourceIndex = 0; sourceIndex < sourceCount; sourceIndex++) {
        NSDictionary *description;
        
        description = [descriptions objectAtIndex:sourceIndex];
        if (!addedSeparatorBetweenPortAndVirtual && [description objectForKey:@"endpoint"] == nil) {
            if (sourceIndex > 0)
                [sourcePopUpButton addSeparatorItem];
            addedSeparatorBetweenPortAndVirtual = YES;
        }
        [sourcePopUpButton addItemWithTitle:[description objectForKey:@"name"] representedObject:description];

        if (!foundSource && [description isEqual:currentDescription]) {
            [sourcePopUpButton selectItemAtIndex:[sourcePopUpButton numberOfItems] - 1];
                // Don't use sourceIndex because it may be off by one (because of the separator item)
            foundSource = YES;
        }
    }

    if (!foundSource)
        [sourcePopUpButton selectItem:nil];
        
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
        [messagesOutlineView scrollRowToVisible:[messagesOutlineView rowForItem:[displayedMessages lastObject]]];
}

- (void)couldNotFindSourceNamed:(NSString *)sourceName;
{
    NSString *title, *message;
    
    title = NSLocalizedStringFromTableInBundle(@"Missing Source", @"MIDIMonitor", [self bundle], "if document's source is missing, title of sheet");    
    message = NSLocalizedStringFromTableInBundle(@"The source named \"%@\" could not be found.", @"MIDIMonitor", [self bundle], "if document's source is missing, message in sheet (with source name)");

    NSBeginAlertSheet(title, nil, nil, nil, [self window], nil, NULL, NULL, NULL, message, sourceName);
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
// NSOutlineView data source
//

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item;
{
    if (item == nil) {
        return [displayedMessages objectAtIndex:index];    
    } else {
        OBASSERT([item isKindOfClass:[SMSystemExclusiveMessage class]]);

        return [[self _sysExRowsForMessage:item] objectAtIndex:index];
    }    
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
{
    return [item isKindOfClass:[SMSystemExclusiveMessage class]];
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
{
    if (item == nil) {
        return [displayedMessages count];
    } else {
        OBASSERT([item isKindOfClass:[SMSystemExclusiveMessage class]]);
        return [SMMSysExRow rowCountForMessage:item];
    }
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;
{
    NSString *identifier;
    SMMessage *message = nil;
    SMMSysExRow *sysExRow = nil;
    
    identifier = [tableColumn identifier];

    if ([item isKindOfClass:[SMMessage class]])
        message = (SMMessage *)item;
    else
        sysExRow = (SMMSysExRow *)item;
    
    if (message) {
        if ([identifier isEqualToString:@"timeStamp"]) {
            return [message timeStampForDisplay];
        } else if ([identifier isEqualToString:@"type"]) {
            return [message typeForDisplay];
        } else if ([identifier isEqualToString:@"channel"]) {
            return [message channelForDisplay];
        } else if ([identifier isEqualToString:@"data"]) {
            return [message dataForDisplay];
        } else {
            return nil;
        }
    } else {
       if ([identifier isEqualToString:@"type"]) {
            return [sysExRow formattedOffset];
        } else if ([identifier isEqualToString:@"data"]) {
            return [sysExRow formattedData];
        } else {
            return nil;
        }    
    }
}

@end


@implementation SMMMonitorWindowController (Private)

- (void)_displayPreferencesDidChange:(NSNotification *)notification;
{
    [messagesOutlineView reloadData];
}

- (void)_sysExBytesPerRowDidChange:(NSNotification *)notification;
{
    NSResetMapTable(sysExRowsMapTable);

    [messagesOutlineView reloadData];
}

- (NSArray *)_sysExRowsForMessage:(SMSystemExclusiveMessage *)message;
{
    NSArray *rows;

    // NOTE If NSOutlineView was smart, it would only ask for children when it needed to display them.
    // Unfortunately it seems that when the parent is expanded, NSOutlineView asks for EVERY child, sequentially,
    // whether or not they will be visible. Sigh.
    // So the current code is as good as we can get for now. If NSOutlineView ever gets fixed, we
    // should be able to be lazier about creating SMMSysExRows, instead of creating them all at once.

    rows = NSMapGet(sysExRowsMapTable, message);
    if (!rows) {
        rows = [SMMSysExRow sysExRowsForMessage:message];
        NSMapInsert(sysExRowsMapTable, message, rows);
    }

    return rows;
}

- (void)_removeSysExRowsForMessagesNotIn:(NSArray *)newMessages;
{
    NSArray *oldExpandedMessages;
    NSSet *newMessageSet;
    unsigned int messageIndex, messageCount;

    // Get the sysex messages which have been expanded
    oldExpandedMessages = NSAllMapTableKeys(sysExRowsMapTable);

    // Find out which ones are now gone, and remove them from the map table
    newMessageSet = [NSSet setWithArray:newMessages];    
    messageCount = [oldExpandedMessages count];
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMSystemExclusiveMessage *message;
    
        message = [oldExpandedMessages objectAtIndex:messageIndex];
        if (![newMessageSet containsObject:message]) {
            NSMapRemove(sysExRowsMapTable, message);        
        }    
    }
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

@end
