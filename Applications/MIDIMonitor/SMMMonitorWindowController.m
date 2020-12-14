/*
 Copyright (c) 2001-2014, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SMMMonitorWindowController.h"

#import <SnoizeMIDI/SnoizeMIDI.h>

#import "MIDI_Monitor-Swift.h"
#import "SMMDocument.h"
#import "SMMPreferencesWindowController.h"
#import "SMMDetailsWindowController.h"
#import "SNDisclosableView.h"


@interface SMMMonitorWindowController ()

// Sources controls
@property (nonatomic, assign) IBOutlet SNDisclosureButton *sourcesDisclosureButton;
@property (nonatomic, assign) IBOutlet SNDisclosableView *sourcesDisclosableView;
@property (nonatomic, assign) IBOutlet SMMSourcesOutlineView *sourcesOutlineView;

// Filter controls
@property (nonatomic, assign) IBOutlet SNDisclosureButton *filterDisclosureButton;
@property (nonatomic, assign) IBOutlet SNDisclosableView *filterDisclosableView;
@property (nonatomic, assign) IBOutlet NSButton *voiceMessagesCheckBox;
@property (nonatomic, assign) IBOutlet NSMatrix *voiceMessagesMatrix;
@property (nonatomic, assign) IBOutlet NSButton *systemCommonCheckBox;
@property (nonatomic, assign) IBOutlet NSMatrix *systemCommonMatrix;
@property (nonatomic, assign) IBOutlet NSButton *realTimeCheckBox;
@property (nonatomic, assign) IBOutlet NSMatrix *realTimeMatrix;
@property (nonatomic, assign) IBOutlet NSButton *systemExclusiveCheckBox;
@property (nonatomic, assign) IBOutlet NSButton *invalidCheckBox;
@property (nonatomic, assign) IBOutlet NSMatrix *channelRadioButtons;
@property (nonatomic, assign) IBOutlet NSTextField *oneChannelField;
@property (nonatomic, retain) NSArray *filterCheckboxes;
@property (nonatomic, retain) NSArray *filterMatrixCells;

// Event controls
@property (nonatomic, assign) IBOutlet NSTableView *messagesTableView;
@property (nonatomic, assign) IBOutlet NSButton *clearButton;
@property (nonatomic, assign) IBOutlet NSTextField *maxMessageCountField;
@property (nonatomic, assign) IBOutlet NSProgressIndicator *sysExProgressIndicator;
@property (nonatomic, assign) IBOutlet NSTextField *sysExProgressField;

// Transient data
@property (nonatomic, assign) NSUInteger oneChannel;
@property (nonatomic, retain) NSArray *groupedInputSources;
@property (nonatomic, retain) NSArray *displayedMessages;
@property (nonatomic, assign) BOOL messagesNeedScrollToBottom;
@property (nonatomic, retain) NSDate *nextMessagesRefreshDate;
@property (nonatomic, assign) NSTimer *nextMessagesRefreshTimer;

@end

@implementation SMMMonitorWindowController

static const NSTimeInterval kMinimumMessagesRefreshDelay = 0.10; // seconds

- (instancetype)init
{
    if ((self = [super initWithWindowNibName:@"MIDIMonitor"])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayPreferencesDidChange:) name:SMMDisplayPreferenceChangedNotification object:nil];

        _oneChannel = 1;

        self.shouldCascadeWindows = YES;
        self.shouldCloseDocument = YES;
    }

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName
{
    SMRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_filterCheckboxes release];
    [_filterMatrixCells release];

    [_groupedInputSources release];

    [_displayedMessages release];

    [_nextMessagesRefreshDate release];

    if (_nextMessagesRefreshTimer) {
		[_nextMessagesRefreshTimer invalidate];
        _nextMessagesRefreshTimer = nil;
    }

    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    self.sourcesOutlineView.outlineTableColumn = [self.sourcesOutlineView tableColumnWithIdentifier:@"name"];
    self.sourcesOutlineView.autoresizesOutlineColumn = NO;

    SMMNonHighlightingButtonCell *checkboxCell = [[SMMNonHighlightingButtonCell alloc] initTextCell:@""];
    checkboxCell.buttonType = NSSwitchButton;
    checkboxCell.controlSize = NSSmallControlSize;
    checkboxCell.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    checkboxCell.allowsMixedState = YES;
    [self.sourcesOutlineView tableColumnWithIdentifier:@"enabled"].dataCell = checkboxCell;
    [checkboxCell release];

    SMMNonHighlightingTextFieldCell *textFieldCell = [[SMMNonHighlightingTextFieldCell alloc] initTextCell:@""];
    textFieldCell.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    [self.sourcesOutlineView tableColumnWithIdentifier:@"name"].dataCell = textFieldCell;
    [textFieldCell release];
    
    self.filterCheckboxes = [NSArray arrayWithObjects:self.voiceMessagesCheckBox, self.systemCommonCheckBox, self.realTimeCheckBox, self.systemExclusiveCheckBox, self.invalidCheckBox, nil];
    self.filterMatrixCells = [[self.voiceMessagesMatrix.cells arrayByAddingObjectsFromArray:self.systemCommonMatrix.cells] arrayByAddingObjectsFromArray:self.realTimeMatrix.cells];

    self.voiceMessagesCheckBox.allowsMixedState = YES;
    self.systemCommonCheckBox.allowsMixedState = YES;
    self.realTimeCheckBox.allowsMixedState = YES;
    
    ((NSNumberFormatter *)self.maxMessageCountField.formatter).allowsFloats = NO;
    ((NSNumberFormatter *)self.oneChannelField.formatter).allowsFloats = NO;
    
    self.messagesTableView.autosaveName = @"MessagesTableView2";
    self.messagesTableView.autosaveTableColumns = YES;
    self.messagesTableView.target = self;
    self.messagesTableView.doubleAction = @selector(showDetailsOfSelectedMessages:);

    [self hideSysExProgressIndicator];
}

- (void)setDocument:(NSDocument *)document
{
    [super setDocument:document];

    if (document) {
        [self window];	// Make sure the window is loaded

        [self synchronizeMessagesWithScrollToBottom:NO];
        [self synchronizeSources];
        [self synchronizeMaxMessageCount];
        [self synchronizeFilterControls];

        [self restoreWindowSettings:((SMMDocument *)document).windowSettings];
    }
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    if (anItem.action == @selector(copy:)) {
        if (self.window.firstResponder == self.messagesTableView) {
            return self.messagesTableView.numberOfSelectedRows > 0;
        } else {
            return NO;
        }
    } else if (anItem.action == @selector(showDetailsOfSelectedMessages:)) {
        return self.selectedMessagesWithDetails.count > 0;
    } else {
        return YES;
    }
}

//
// Actions
//

- (IBAction)clearMessages:(id)sender
{
    [self.midiDocument clearSavedMessages];
}

- (IBAction)setMaximumMessageCount:(id)sender
{
    NSNumber *number;

    if ((number = [(NSControl*)sender objectValue])) {
        self.midiDocument.maxMessageCount = [number unsignedIntValue];
    } else {
        [self synchronizeMaxMessageCount];
    }
}

- (IBAction)changeFilter:(id)sender
{
    BOOL turnBitsOn;

    switch ([(NSButton *)sender state]) {
        case NSOnState:
        case NSMixedState:	// Changing from off to mixed state should be the same as changing to all-on
            turnBitsOn = YES;
            break;
            
        case NSOffState:
        default:
            turnBitsOn = NO;
            break;
    }
    
    [self.midiDocument changeFilterMask:(SMMessageType)[sender tag] turnBitsOn:turnBitsOn];
}

- (IBAction)changeFilterFromMatrix:(id)sender
{
    [self changeFilter:[sender selectedCell]];
}

- (IBAction)setChannelRadioButton:(id)sender;
{
    if ([[sender selectedCell] tag] == 0) {
        [self.midiDocument showAllChannels];
    } else {
        [self.midiDocument showOnlyOneChannel:self.oneChannel];
    }
}

- (IBAction)setChannel:(id)sender
{
    [self.midiDocument showOnlyOneChannel:[(NSNumber *)[sender objectValue] unsignedIntValue]];
}

- (IBAction)toggleFilterShown:(id)sender
{
    [self.filterDisclosableView toggleDisclosure:sender];
    [self trivialWindowSettingsDidChange];
}

- (IBAction)toggleSourcesShown:(id)sender
{
    [self.sourcesDisclosableView toggleDisclosure:sender];
    [self trivialWindowSettingsDidChange];
}

- (IBAction)showDetailsOfSelectedMessages:(id)sender
{
    for (SMMessage *message in self.selectedMessagesWithDetails) {
        [[self.midiDocument detailsWindowControllerForMessage:message] showWindow:nil];
    }
}

- (IBAction)copy:(id)sender
{
    if (self.window.firstResponder == self.messagesTableView) {
        NSMutableString *totalString = [NSMutableString string];
        NSArray *columns = self.messagesTableView.tableColumns;
            
        NSIndexSet *selectedRowIndexes = self.messagesTableView.selectedRowIndexes;
        NSUInteger row;
        for (row = [selectedRowIndexes firstIndex]; row != NSNotFound; row = [selectedRowIndexes indexGreaterThanIndex:row]) {
            NSMutableArray *columnStrings = [[NSMutableArray alloc] init];
            for (NSTableColumn *column in columns) {
                [columnStrings addObject:[self tableView:self.messagesTableView objectValueForTableColumn:column row:row]];
            }

            [totalString appendString:[columnStrings componentsJoinedByString:@"\t"]];
            [totalString appendString:@"\n"];

            [columnStrings release];
        }

        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard declareTypes:@[NSStringPboardType] owner:nil];
        [pasteboard setString:totalString forType:NSStringPboardType];
    }
}

//
// Other API
//

- (void)synchronizeMessagesWithScrollToBottom:(BOOL)shouldScrollToBottom
{
    // Reloading the NSTableView can be excruciatingly slow, and if messages are coming in quickly,
    // we will hog a lot of CPU. So we make sure that we don't do it too often.

    if (shouldScrollToBottom) {
        self.messagesNeedScrollToBottom = YES;
    }

    if (self.nextMessagesRefreshTimer) {
        // We're going to refresh soon, so don't do anything now.
        return;
    }

    NSTimeInterval ti = self.nextMessagesRefreshDate.timeIntervalSinceNow;
    if (ti <= 0.0) {
        // Refresh right away, since we haven't recently.
        [self refreshMessagesTableView];
    } else {
        // We have refreshed recently.
        // Schedule an event to make us refresh when we are next allowed to do so.
		self.nextMessagesRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(refreshMessagesTableViewFromTimer:) userInfo:nil repeats:NO];
    }
}

- (void)synchronizeSources
{
    self.groupedInputSources = self.midiDocument.groupedInputSources;

    [self.sourcesOutlineView reloadData];
}

- (void)synchronizeMaxMessageCount
{
    self.maxMessageCountField.objectValue = @(self.midiDocument.maxMessageCount);
}

- (void)synchronizeFilterControls
{
    SMMessageType currentMask = self.midiDocument.filterMask;

    for (NSButton *checkbox in self.filterCheckboxes) {
        SMMessageType buttonMask = (SMMessageType)checkbox.tag;

        int newState;
        if ((currentMask & buttonMask) == buttonMask) {
            newState = NSOnState;
        } else if ((currentMask & buttonMask) == 0) {
            newState = NSOffState;
        } else {
            newState = NSMixedState;
        }

        checkbox.state = newState;
    }

    for (NSButtonCell *checkbox in self.filterMatrixCells) {
        SMMessageType buttonMask = (SMMessageType)checkbox.tag;

        int newState;
        if ((currentMask & buttonMask) == buttonMask) {
            newState = NSOnState;
        } else {
            newState = NSOffState;
        }

        checkbox.state = newState;
    }

    if (self.midiDocument.isShowingAllChannels) {
        [self.channelRadioButtons selectCellWithTag:0];
        self.oneChannelField.enabled = NO;
    } else {
        [self.channelRadioButtons selectCellWithTag:1];
        self.oneChannelField.enabled = YES;
        self.oneChannel = self.midiDocument.oneChannelToShow;
    }
    self.oneChannelField.objectValue = [NSNumber numberWithUnsignedInteger:self.oneChannel];
}

- (void)updateSysExReadIndicatorWithBytes:(NSNumber *)bytesReadNumber
{
    [self showSysExProgressIndicator];
}

- (void)stopSysExReadIndicatorWithBytes:(NSNumber *)bytesReadNumber
{
    [self hideSysExProgressIndicator];
}

- (void)revealInputSources:(NSSet *)inputSources
{
    // Show the sources first
    self.sourcesDisclosableView.shown = YES;
    [self.sourcesDisclosureButton setIntValue: 1];

    // Of all of the input sources, find the first one which is in the given set.
    // Then expand the outline view to show this source, and scroll it to be visible.
    for (NSDictionary *group in self.groupedInputSources) {
        if (![[group objectForKey:@"isNotExpandable"] boolValue]) {
            NSArray *groupSources;
            NSUInteger groupSourceCount, groupSourceIndex;

            groupSources = [group objectForKey:@"sources"];
            groupSourceCount = [groupSources count];
            for (groupSourceIndex = 0; groupSourceIndex < groupSourceCount; groupSourceIndex++) {
                id source;

                source = [groupSources objectAtIndex:groupSourceIndex];
                if ([inputSources containsObject:source]) {
                    // Found one!
                    [self.sourcesOutlineView expandItem:group];
                    [self.sourcesOutlineView scrollRowToVisible:[self.sourcesOutlineView rowForItem:source]];

                    // And now we're done
                    break;
                }
            }            
        }
    }
}

#pragma mark Window settings

static NSString * const SMMSourcesShownKey = @"areSourcesShown";
static NSString * const SMMFilterShownKey = @"isFilterShown";
static NSString * const SMMWindowFrameKey = @"windowFrame";
static NSString * const SMMMessagesScrollPointX = @"messagesScrollPointX";
static NSString * const SMMMessagesScrollPointY = @"messagesScrollPointY";

+ (NSArray *)windowSettingsKeys
{
    return @[SMMSourcesShownKey, SMMFilterShownKey, SMMWindowFrameKey, SMMMessagesScrollPointX, SMMMessagesScrollPointY];
}

- (NSDictionary *)windowSettings
{
    NSMutableDictionary *windowSettings = [NSMutableDictionary dictionary];

    // Remember whether our sections are shown or hidden
    if (self.sourcesDisclosableView.shown) {
        windowSettings[SMMSourcesShownKey] = @YES;
    }
    if (self.filterDisclosableView.shown) {
        windowSettings[SMMFilterShownKey] = @YES;
    }

    // And remember the window frame, so we can restore it after restoring those
    NSString *windowFrameDescription = self.window.stringWithSavedFrame;
    if (windowFrameDescription) {
        windowSettings[SMMWindowFrameKey] = windowFrameDescription;
    }

    // And the scroll position of the messages
    NSView *clipView = self.messagesTableView.enclosingScrollView.contentView;
    NSRect clipBounds = clipView.bounds;
    NSPoint scrollPoint = [self.messagesTableView convertPoint:clipBounds.origin fromView:clipView];
    windowSettings[SMMMessagesScrollPointX] = @(scrollPoint.x);
    windowSettings[SMMMessagesScrollPointY] = @(scrollPoint.y);

    return windowSettings;
}

- (void)restoreWindowSettings:(NSDictionary *)windowSettings
{
    // Restore visibility of sections
    BOOL sourcesShown = [@YES isEqual:windowSettings[SMMSourcesShownKey]];
    [self.sourcesDisclosureButton setIntValue:sourcesShown ? 1 : 0];
    self.sourcesDisclosableView.shown = sourcesShown;

    BOOL filterShown = [@YES isEqual:windowSettings[SMMFilterShownKey]];
    [self.filterDisclosureButton setIntValue:filterShown ? 1 : 0];
    self.filterDisclosableView.shown = filterShown;

    // Then, since those may have resized the window, set the frame back to what we expect.
    NSString *windowFrame = windowSettings[SMMWindowFrameKey];
    if ([windowFrame isKindOfClass:[NSString class]]) {
        [self.window setFrameFromString:windowFrame];
    }

    if ([windowSettings[SMMMessagesScrollPointX] isKindOfClass:[NSNumber class]] && [windowSettings[SMMMessagesScrollPointY] isKindOfClass:[NSNumber class]]) {
        NSPoint scrollPoint = (NSPoint){ [windowSettings[SMMMessagesScrollPointX] floatValue], [windowSettings[SMMMessagesScrollPointY] floatValue] };
        [self.messagesTableView scrollPoint:scrollPoint];
    }
}

#pragma mark Delegates & Data Sources

//
// NSWindowRestoration
//
// In some cases, the document's saved window settings will not match
// the window size that was automatically encoded in restorable state.
// (For instance, if we don't dirty the document when the window settings
// were changed, and the user didn't save before quitting, and autosave
// is turned off.)
// Therefore, we must also put the window settings into the restorable
// state, and restore that after the regular document settings are done.

- (void)window:(NSWindow *)window willEncodeRestorableState:(NSCoder *)state
{
    [state encodeObject:self.windowSettings forKey:@"windowSettings"];
}

- (void)window:(NSWindow *)window didDecodeRestorableState:(NSCoder *)state
{
    id obj = [state decodeObjectForKey:@"windowSettings"];
    if ([obj isKindOfClass:[NSDictionary class]]) {
        [self restoreWindowSettings:(NSDictionary *)obj];
    }
}

//
// NSOutlineView data source
//

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
    if (item == nil) {
        return self.groupedInputSources[index];
    } else {
        return item[@"sources"][index];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return [item isKindOfClass:[NSDictionary class]] && ![item[@"isNotExpandable"] boolValue];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil) {
        return self.groupedInputSources.count;
    } else if ([item isKindOfClass:[NSDictionary class]]) {
        return ((NSArray *)item[@"sources"]).count;
    } else {
        return 0;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    NSString *identifier = tableColumn.identifier;
    BOOL isCategory = [item isKindOfClass:[NSDictionary class]];
    
    if ([identifier isEqualToString:@"name"]) {
        if (isCategory) {
            return item[@"name"];
        } else {
            NSString *name = ((id<SMInputStreamSource>)item).inputStreamSourceName;
            NSArray *externalDeviceNames = ((id<SMInputStreamSource>)item).inputStreamSourceExternalDeviceNames;

            if ([externalDeviceNames count] > 0) {
                return [[name stringByAppendingString:@"—"] stringByAppendingString:[externalDeviceNames componentsJoinedByString:@", "]];
            } else {
                return name;
            }
        }
    } else if ([identifier isEqualToString:@"enabled"]) {
        NSArray *sources = isCategory ? item[@"sources"] : @[item];
        return @([self buttonStateForInputSources:sources]);
    } else {
        return nil;
    }
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    int newState = [object intValue];
    // It doesn't make sense to switch from off to mixed, so go directly to on
    if (newState == NSMixedState) {
        newState = NSOnState;
    }

    BOOL isCategory = [item isKindOfClass:[NSDictionary class]];
    NSArray *sources = isCategory ? item[@"sources"] : @[item];

    NSMutableSet *newSelectedSources = [NSMutableSet setWithSet:self.midiDocument.selectedInputSources];
    if (newState == NSOnState) {
        [newSelectedSources addObjectsFromArray:sources];
    } else {
        [newSelectedSources minusSet:[NSSet setWithArray:sources]];
    }

    self.midiDocument.selectedInputSources = newSelectedSources;
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayOutlineCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    // cause the button cell to always use a "dark" triangle
    ((NSCell *)cell).backgroundStyle = NSBackgroundStyleLight;
}


//
// NSTableView data source
//

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.displayedMessages.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    SMMessage *message = self.displayedMessages[row];

    NSString *identifier = tableColumn.identifier;
    if ([identifier isEqualToString:@"timeStamp"]) {
        return message.timeStampForDisplay;
    } else if ([identifier isEqualToString:@"source"]) {
        return message.originatingEndpointForDisplay;
    } else if ([identifier isEqualToString:@"type"]) {
        return message.typeForDisplay;
    } else if ([identifier isEqualToString:@"channel"]) {
        return message.channelForDisplay;
    } else if ([identifier isEqualToString:@"data"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SMExpertModePreferenceKey]) {
            return message.expertDataForDisplay;
        } else {
            return message.dataForDisplay;
        }
    } else {
        return nil;
    }
}

#pragma mark Private

- (SMMDocument *)midiDocument
{
    return (SMMDocument *)self.document;
}

- (void)trivialWindowSettingsDidChange
{
    // Mark the document as dirty, so the state of the window gets saved.
    // However, use NSChangeDiscardable, so it doesn't cause a locked document to get dirtied for a trivial change.
    // Also, don't do it for untitled, unsaved documents which have no fileURL yet, because that's annoying.
    // Similarly, don't do it if "Ask to keep changes when closing documents" is turned on.
    if (self.midiDocument.fileURL && ![[NSUserDefaults standardUserDefaults] boolForKey:@"NSCloseAlwaysConfirmsChanges"]) {
        [self.midiDocument updateChangeCount:(NSChangeDiscardable | NSChangeDone)];
    }
}

- (void)displayPreferencesDidChange:(NSNotification *)notification
{
    [self.messagesTableView reloadData];
}

- (void)updateDisplayedMessages
{
    self.displayedMessages = self.midiDocument.savedMessages;
}

- (void)refreshMessagesTableView
{
    [self updateDisplayedMessages];

    // Scroll to the botton, iff the table view is already scrolled to the bottom.
    BOOL isAtBottom = NSMaxY(self.messagesTableView.bounds) - NSMaxY(self.messagesTableView.visibleRect) < self.messagesTableView.rowHeight;
    
    [self.messagesTableView reloadData];

    if (self.messagesNeedScrollToBottom && isAtBottom) {
        NSUInteger messageCount = self.displayedMessages.count;
        if (messageCount > 0) {
            [self.messagesTableView scrollRowToVisible:messageCount - 1];
        }
    }

    self.messagesNeedScrollToBottom = NO;

    // Figure out when we should next be allowed to refresh.
    self.nextMessagesRefreshDate = [NSDate dateWithTimeIntervalSinceNow:kMinimumMessagesRefreshDelay];
}

- (void)refreshMessagesTableViewFromTimer:(NSTimer *)timer
{
    self.nextMessagesRefreshTimer = nil;

    [self refreshMessagesTableView];
}

- (void)showSysExProgressIndicator
{
    self.sysExProgressField.hidden = NO;
    [self.sysExProgressIndicator startAnimation:nil];
}

- (void)hideSysExProgressIndicator
{
    self.sysExProgressField.hidden = YES;
    [self.sysExProgressIndicator stopAnimation:nil];
}

- (NSArray *)selectedMessagesWithDetails
{
    NSInteger selectedRowCount = [self.messagesTableView numberOfSelectedRows];
    if (selectedRowCount == 0) {
        return [NSArray array];
    }

    NSMutableArray* messages = [NSMutableArray arrayWithCapacity:selectedRowCount];

    NSIndexSet* selectedRowIndexes = [self.messagesTableView selectedRowIndexes];
    NSUInteger row;
    for (row = selectedRowIndexes.firstIndex; row != NSNotFound; row = [selectedRowIndexes indexGreaterThanIndex:row]) {
        SMMessage *message = self.displayedMessages[row];
        if ([SMMDetailsWindowController canShowDetailsForMessage:message]) {
            [messages addObject:message];
        }
    }

    return messages;
}

- (NSCellStateValue)buttonStateForInputSources:(NSArray *)sources
{
    BOOL areAnySelected = NO, areAnyNotSelected = NO;
    
    NSSet *selectedSources = self.midiDocument.selectedInputSources;
    for (id source in sources) {
        if ([selectedSources containsObject:source]) {
            areAnySelected = YES;
        } else {
            areAnyNotSelected = YES;
        }

        if (areAnySelected && areAnyNotSelected) {
            return NSMixedState;
        }
    }

    return areAnySelected ? NSOnState : NSOffState;
}

@end
