/*
 Copyright (c) 2001-2014, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SMMDocument.h"

#import <objc/objc-runtime.h>

#import "SMMCombinationInputStream.h"
#import "SMMMonitorWindowController.h"


NSString* const SMMAutoSelectFirstSourceInNewDocumentPreferenceKey = @"SMMAutoSelectFirstSource";
    // NOTE: The above is obsolete; it's included only for compatibility
NSString* const SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey = @"SMMAutoSelectOrdinarySources";
NSString* const SMMAutoSelectVirtualDestinationInNewDocumentPreferenceKey = @"SMMAutoSelectVirtualDestination";
NSString* const SMMAutoSelectSpyingDestinationsInNewDocumentPreferenceKey = @"SMMAutoSelectSpyingDestinations";
NSString* const SMMAskBeforeClosingModifiedWindowPreferenceKey = @"SMMAskBeforeClosingModifiedWindow";

@interface SMMDocument ()

// MIDI processing
@property (nonatomic, retain) SMMCombinationInputStream *stream;
@property (nonatomic, retain) SMMessageFilter *messageFilter;
@property (nonatomic, retain) SMMessageHistory *history;

// Other settings
@property (nonatomic, assign) NSPoint messagesScrollPoint;

// Transient data
@property (nonatomic, retain) NSArray *missingSourceNames;
@property (nonatomic, assign) NSUInteger sysExBytesRead;
@property (nonatomic, assign) BOOL isSysExUpdateQueued;

@end


@implementation SMMDocument

- (id)init
{
    if ((self = [super init])) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

        _stream = [[SMMCombinationInputStream alloc] init];
        [center addObserver:self selector:@selector(readingSysEx:) name:SMInputStreamReadingSysExNotification object:_stream];
        [center addObserver:self selector:@selector(doneReadingSysEx:) name:SMInputStreamDoneReadingSysExNotification object:_stream];
        [center addObserver:self selector:@selector(sourceListDidChange:) name:SMInputStreamSourceListChangedNotification object:_stream];
        [self updateVirtualEndpointName];

        _messageFilter = [[SMMessageFilter alloc] init];
        _stream.messageDestination = _messageFilter;
        _messageFilter.filterMask = SMMessageTypeAllMask;
        _messageFilter.channelMask = SMChannelMaskAll;

        _history = [[SMMessageHistory alloc] init];
        _messageFilter.messageDestination = _history;
        [center addObserver:self selector:@selector(historyDidChange:) name:SMMessageHistoryChangedNotification object:_history];

        // If the user changed the value of this old obsolete preference, bring its value forward to our new preference
        // (the default value was YES)
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        if (![ud boolForKey:SMMAutoSelectFirstSourceInNewDocumentPreferenceKey]) {
            [ud setBool:NO forKey:SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey];
            [ud setBool:YES forKey:SMMAutoSelectFirstSourceInNewDocumentPreferenceKey];
            [ud synchronize];
        }

        [self autoselectSources];

        [self updateChangeCount:NSChangeCleared];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    _stream.messageDestination = nil;
    [_stream release];
    _stream = nil;
    _messageFilter.messageDestination = nil;
    [_messageFilter release];
    _messageFilter = nil;
    [_windowFrameDescription release];
    _windowFrameDescription = nil;
    [_missingSourceNames release];
    _missingSourceNames = nil;
    [_history release];
    _history = nil;

    [super dealloc];
}

- (void)makeWindowControllers
{
    NSWindowController *controller = [[SMMMonitorWindowController alloc] init];
    [self addWindowController:controller];
    [controller release];
}

- (void)showWindows
{
    [super showWindows];

    if (self.missingSourceNames) {
        [self.windowControllers makeObjectsPerformSelector:@selector(couldNotFindSourcesNamed:) withObject:self.missingSourceNames];
        self.missingSourceNames = nil;
    }
}

- (NSData *)dataRepresentationOfType:(NSString *)type
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    dict[@"version"] = @2;

    NSDictionary* streamSettings = self.stream.persistentSettings;
    if (streamSettings) {
        dict[@"streamSettings"] = streamSettings;
    }

    NSUInteger historySize = self.history.historySize;
    if (historySize != [SMMessageHistory defaultHistorySize]) {
        dict[@"maxMessageCount"] = @(historySize);
    }

    SMMessageType filterMask = self.messageFilter.filterMask;
    if (filterMask != SMMessageTypeAllMask) {
        dict[@"filterMask"] = @(filterMask);
    }

    SMChannelMask channelMask = self.messageFilter.channelMask;
    if (channelMask != SMChannelMaskAll) {
        dict[@"channelMask"] = @(channelMask);
    }

    if (self.areSourcesShown) {
        dict[@"areSourcesShown"] = @YES;
    }

    if (self.isFilterShown) {
        dict[@"isFilterShown"] = @YES;
    }

    if (self.windowFrameDescription) {
        dict[@"windowFrame"] = self.windowFrameDescription;
    }

    NSArray* savedMessages = self.history.savedMessages;
    if (savedMessages.count) {
        NSData* messageData = [NSKeyedArchiver archivedDataWithRootObject:savedMessages];
        if (messageData) {
            dict[@"messageData"] = messageData;
        }
    }
    
    SMMMonitorWindowController* wc = self.windowControllers.lastObject;
    if (wc) {
        self.messagesScrollPoint = wc.messagesScrollPoint;
        dict[@"messagesScrollPointX"] = @(self.messagesScrollPoint.x);
        dict[@"messagesScrollPointY"] = @(self.messagesScrollPoint.y);
    }
    
    NSData* data = [NSPropertyListSerialization dataFromPropertyList:dict format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
    
    [dict release];
    
    return data;
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)type
{
    id propertyList = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
    if (!propertyList || ![propertyList isKindOfClass:[NSDictionary class]]) {
        return NO;
	}

    NSDictionary *dict = propertyList;
    NSNumber *number;
    NSString *string;
    NSDictionary *streamSettings = nil;

    int version = [dict[@"version"] intValue];
    switch (version) {
        case 1:
            if ((number = dict[@"sourceEndpointUniqueID"])) {
                streamSettings = [NSDictionary dictionaryWithObjectsAndKeys:number, @"portEndpointUniqueID", [dict objectForKey:@"sourceEndpointName"], @"portEndpointName", nil];
                // NOTE: [dict objectForKey:@"sourceEndpointName"] may be nil--that's acceptable
            } else if ((number = dict[@"virtualDestinationEndpointUniqueID"])) {
                streamSettings = @{@"virtualEndpointUniqueID": number};
            }
            break;

        case 2:
            streamSettings = dict[@"streamSettings"];
            break;

        default:
            return NO;
    }

    if (streamSettings) {
        self.missingSourceNames = [self.stream takePersistentSettings:streamSettings];
        [self.windowControllers makeObjectsPerformSelector:@selector(synchronizeSources)];
    } else {
        self.selectedInputSources = [NSSet set];
    }
    
    number = dict[@"maxMessageCount"];
    self.maxMessageCount = number ? [number unsignedIntValue] : [SMMessageHistory defaultHistorySize];

    number = dict[@"filterMask"];
    self.filterMask = number ? [number unsignedIntValue] : SMMessageTypeAllMask;

    number = dict[@"channelMask"];
    self.channelMask = number ? [number unsignedIntValue] : SMChannelMaskAll;

    number = dict[@"areSourcesShown"];
    self.areSourcesShown = number ? [number boolValue] : NO;

    number = dict[@"isFilterShown"];
    self.isFilterShown = number ? [number boolValue] : NO;

    if ((string = dict[@"windowFrame"])) {
        self.windowFrameDescription = string;
    }

    NSPoint messagesScrollPoint = NSZeroPoint;
    if ((number = [dict objectForKey:@"messagesScrollPointX"])) {
        messagesScrollPoint.x = [number floatValue];
    }
    if ((number = [dict objectForKey:@"messagesScrollPointY"])) {
        messagesScrollPoint.y = [number floatValue];
    }
    self.messagesScrollPoint = messagesScrollPoint;
    
    NSData* messageData = [dict objectForKey:@"messageData"];
    if (messageData) {
        id obj = [NSKeyedUnarchiver unarchiveObjectWithData:messageData];
        if (obj && [obj isKindOfClass:[NSArray class]]) {
            self.history.savedMessages = (NSArray*)obj;
        }
    }
    
    [self.windowControllers makeObjectsPerformSelector:@selector(setWindowStateFromDocument)];

    // Doing the above caused undo actions to be remembered, but we don't want the user to see them
    [self updateChangeCount:NSChangeCleared];

    return YES;
}

- (void)updateChangeCount:(NSDocumentChangeType)change
{
    // This clears the undo stack whenever we load or save.
    [super updateChangeCount:change];
    if (change == NSChangeCleared) {
        [self.undoManager removeAllActions];
    }
}

- (void)setFileURL:(NSURL*)url
{
    [super setFileURL:url];

    [self updateVirtualEndpointName];
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SMMAskBeforeClosingModifiedWindowPreferenceKey]) {
        [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
    } else {
        // Tell the delegate to close now, regardless of what the document's dirty flag may be.
        // Unfortunately this is not easy in Objective-C...
        void (*objc_msgSendTyped)(id self, SEL _cmd, NSDocument *document, BOOL shouldClose, void *contextInfo) = (void*)objc_msgSend;
        objc_msgSendTyped(delegate, shouldCloseSelector, self, YES /* close now */, contextInfo);
    }
}


//
// API for SMMMonitorWindowController
//

- (NSArray *)groupedInputSources
{
    return self.stream.groupedInputSources;
}

- (NSSet *)selectedInputSources
{
    return self.stream.selectedInputSources;
}

- (void)setSelectedInputSources:(NSSet *)inputSources
{
    NSSet *oldInputSources = self.selectedInputSources;
    if (oldInputSources == inputSources || [oldInputSources isEqual:inputSources]) {
        return;
    }

    self.stream.selectedInputSources = inputSources;

    [(SMMDocument *)[self.undoManager prepareWithInvocationTarget:self] setSelectedInputSources:oldInputSources];
    [self.undoManager setActionName:NSLocalizedStringFromTableInBundle(@"Change Selected Sources", @"MIDIMonitor", SMBundleForObject(self), "change source undo action")];

    [self.windowControllers makeObjectsPerformSelector:@selector(synchronizeSources)];
}

- (void)revealInputSources:(NSSet *)inputSources
{
    [self.windowControllers makeObjectsPerformSelector:@selector(revealInputSources:) withObject:inputSources];
}

- (NSUInteger)maxMessageCount
{
    return self.history.historySize;
}

- (void)setMaxMessageCount:(NSUInteger)newValue
{
    if (newValue != self.maxMessageCount) {
        [[self.undoManager prepareWithInvocationTarget:self] setMaxMessageCount:self.maxMessageCount];
        [self.undoManager setActionName:NSLocalizedStringFromTableInBundle(@"Change Remembered Events", @"MIDIMonitor", SMBundleForObject(self), "change history limit undo action")];

        self.history.historySize = newValue;

        [self.windowControllers makeObjectsPerformSelector:@selector(synchronizeMaxMessageCount)];
    }
}

- (SMMessageType)filterMask
{
    return self.messageFilter.filterMask;
}

- (void)changeFilterMask:(SMMessageType)maskToChange turnBitsOn:(BOOL)turnBitsOn
{
    SMMessageType newMask = self.messageFilter.filterMask;
    if (turnBitsOn) {
        newMask |= maskToChange;
    } else {
        newMask &= ~maskToChange;
    }

    self.filterMask = newMask;
}

- (BOOL)isShowingAllChannels
{
    return self.messageFilter.channelMask == SMChannelMaskAll;
}

- (NSUInteger)oneChannelToShow
{
    // It is possible that something else could have set the mask to show more than one, or zero, channels.
    // We'll just return the lowest enabled channel (1-16), or 0 if no channel is enabled.

    SMAssert(![self isShowingAllChannels]);
    
    SMChannelMask mask = self.messageFilter.channelMask;

    for (NSUInteger channel = 0; channel < 16; channel++) {
        if (mask & 1) {
            return channel + 1;
        } else {
            mask >>= 1;
        }
    }
    
    return 0;    
}

- (void)showAllChannels
{
    self.channelMask = SMChannelMaskAll;
}

- (void)showOnlyOneChannel:(NSUInteger)channel
{
    self.channelMask = 1 << (channel - 1);
}

- (void)setAreSourcesShown:(BOOL)newValue
{
    if (newValue != _areSourcesShown) {
        _areSourcesShown = newValue;
        [self.windowControllers makeObjectsPerformSelector:@selector(synchronizeSourcesShown)];
    }
}

- (void)setIsFilterShown:(BOOL)newValue
{
    if (newValue != _isFilterShown) {
        _isFilterShown = newValue;
        [self.windowControllers makeObjectsPerformSelector:@selector(synchronizeFilterShown)];
    }
}

- (void)clearSavedMessages
{
    if (self.history.savedMessages.count > 0) {
        [self.history clearSavedMessages];
    }
}

- (NSArray *)savedMessages
{
    return self.history.savedMessages;
}

#pragma mark Private

- (void)sourceListDidChange:(NSNotification *)notification
{
    [self.windowControllers makeObjectsPerformSelector:@selector(synchronizeSources)];

    // Also, it's possible that the endpoint names went from being unique to non-unique, so we need
    // to refresh the messages displayed.
    [self synchronizeMessagesWithScroll:NO];
}

- (void)setFilterMask:(SMMessageType)newMask
{
    SMMessageType oldMask = self.messageFilter.filterMask;
    if (newMask != oldMask) {
        [[self.undoManager prepareWithInvocationTarget:self] setFilterMask:oldMask];
        [self.undoManager setActionName:NSLocalizedStringFromTableInBundle(@"Change Filter", @"MIDIMonitor", SMBundleForObject(self), change filter undo action)];

        self.messageFilter.filterMask = newMask;
        [self.windowControllers makeObjectsPerformSelector:@selector(synchronizeFilterControls)];
    }
}

- (void)setChannelMask:(SMChannelMask)newMask
{
    SMChannelMask oldMask = self.messageFilter.channelMask;
    if (newMask != oldMask) {
        [[self.undoManager prepareWithInvocationTarget:self] setChannelMask:oldMask];
        [self.undoManager setActionName:NSLocalizedStringFromTableInBundle(@"Change Channel", @"MIDIMonitor", SMBundleForObject(self), change filter channel undo action)];

        self.messageFilter.channelMask = newMask;
        [self.windowControllers makeObjectsPerformSelector:@selector(synchronizeFilterControls)];
    }
}

- (void)updateVirtualEndpointName
{
    NSString *applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
    self.stream.virtualEndpointName = [NSString stringWithFormat:@"%@ (%@)", applicationName, self.displayName];
}

- (void)autoselectSources
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    NSArray *groupedInputSources = [self groupedInputSources];
    NSMutableSet *sourcesSet = [NSMutableSet set];
    NSArray *sourcesArray;

    if ([defaults boolForKey:SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey]) {
        if (groupedInputSources.count > 0 && 
            (sourcesArray = groupedInputSources[0][@"sources"])) {
            [sourcesSet addObjectsFromArray:sourcesArray];
        }
    }

    if ([defaults boolForKey:SMMAutoSelectVirtualDestinationInNewDocumentPreferenceKey]) {
        if (groupedInputSources.count > 1 && 
            (sourcesArray = groupedInputSources[1][@"sources"])) {
            [sourcesSet addObjectsFromArray:sourcesArray];
        }
    }

	if ([defaults boolForKey:SMMAutoSelectSpyingDestinationsInNewDocumentPreferenceKey]) {
        if (groupedInputSources.count > 2 && 
            (sourcesArray = groupedInputSources[2][@"sources"])) {
            [sourcesSet addObjectsFromArray:sourcesArray];
        }
    }
    
    self.selectedInputSources = sourcesSet;
}

- (void)historyDidChange:(NSNotification *)notification
{
    [self updateChangeCount:NSChangeDone];

    NSNumber *shouldScroll = notification.userInfo[SMMessageHistoryWereMessagesAdded];
	[self synchronizeMessagesWithScroll:[shouldScroll boolValue]];
}

- (void)synchronizeMessagesWithScroll:(BOOL)shouldScroll
{
    for (SMMMonitorWindowController *wc in self.windowControllers) {
        [wc synchronizeMessagesWithScrollToBottom:shouldScroll];
    }
}

- (void)readingSysEx:(NSNotification *)notification
{
    self.sysExBytesRead = [notification.userInfo[@"length"] unsignedIntegerValue];
    
    // We want multiple updates to get coalesced, so only queue it once
    if (!self.isSysExUpdateQueued) {
        self.isSysExUpdateQueued = YES;
        [self performSelector:@selector(updateSysExReadIndicators) withObject:nil afterDelay:0];
    }
}

- (void)updateSysExReadIndicators
{
    self.isSysExUpdateQueued = NO;
    [self.windowControllers makeObjectsPerformSelector:@selector(updateSysExReadIndicatorWithBytes:) withObject:[NSNumber numberWithUnsignedInteger:self.sysExBytesRead]];
}

- (void)doneReadingSysEx:(NSNotification *)notification
{
    NSNumber *number = notification.userInfo[@"length"];
    self.sysExBytesRead = [number unsignedIntegerValue];
    
    if (self.isSysExUpdateQueued) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateSysExReadIndicators) object:nil];
        self.isSysExUpdateQueued = NO;
    }
    
    [self.windowControllers makeObjectsPerformSelector:@selector(stopSysExReadIndicatorWithBytes:) withObject:number];
}

@end
