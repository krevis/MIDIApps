#import "SMMDocument.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMCombinationInputStream.h"
#import "SMMMonitorWindowController.h"


@interface SMMDocument (Private)

- (void)midiSetupDidChange:(NSNotification *)notification;

- (void)setFilterMask:(SMMessageType)newMask;
- (void)setChannelMask:(SMChannelMask)newMask;

- (void)updateVirtualEndpointName;

- (void)autoselectSources;

- (void)historyDidChange:(NSNotification *)notification;
- (void)mainThreadSynchronizeMessagesWithScroll:(BOOL)shouldScroll;

- (void)readingSysEx:(NSNotification *)notification;
- (void)mainThreadReadingSysEx;

- (void)doneReadingSysEx:(NSNotification *)notification;
- (void)mainThreadDoneReadingSysEx:(NSNumber *)bytesReadNumber;

@end


@implementation SMMDocument

NSString *SMMAutoSelectFirstSourceInNewDocumentPreferenceKey = @"SMMAutoSelectFirstSource";
    // NOTE: The above is obsolete; it's included only for compatibility
NSString *SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey = @"SMMAutoSelectOrdinarySources";
NSString *SMMAutoSelectVirtualDestinationInNewDocumentPreferenceKey = @"SMMAutoSelectVirtualDestination";
NSString *SMMAutoSelectSpyingDestinationsInNewDocumentPreferenceKey = @"SMMAutoSelectSpyingDestinations";


- (id)init
{
    NSNotificationCenter *center;
    OFPreference *oldAutoSelectPref, *autoSelectPref;

    if (!(self = [super init]))
        return nil;

    center = [NSNotificationCenter defaultCenter];

    stream = [[SMMCombinationInputStream alloc] init];
    [center addObserver:self selector:@selector(readingSysEx:) name:SMInputStreamReadingSysExNotification object:stream];
    [center addObserver:self selector:@selector(doneReadingSysEx:) name:SMInputStreamDoneReadingSysExNotification object:stream];
    [self updateVirtualEndpointName];

    messageFilter = [[SMMessageFilter alloc] init];
    [stream setMessageDestination:messageFilter];
    [messageFilter setFilterMask:SMMessageTypeAllMask];
    [messageFilter setChannelMask:SMChannelMaskAll];

    history = [[SMMessageHistory alloc] init];
    [messageFilter setMessageDestination:history];
    [center addObserver:self selector:@selector(historyDidChange:) name:SMMessageHistoryChangedNotification object:history];

    areSourcesShown = NO;
    isFilterShown = NO;
    listenToMIDISetupChanges = YES;
    missingSourceNames = nil;
    sysExBytesRead = 0;

    [center addObserver:self selector:@selector(midiSetupDidChange:) name:SMClientSetupChangedNotification object:[SMClient sharedClient]];

    oldAutoSelectPref = [OFPreference preferenceForKey:SMMAutoSelectFirstSourceInNewDocumentPreferenceKey];
    autoSelectPref = [OFPreference preferenceForKey:SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey];

    // If the user changed the value of this old obsolete preference, bring its value forward to our new preference
    if ([oldAutoSelectPref hasNonDefaultValue]) {
        [autoSelectPref setBoolValue:[oldAutoSelectPref boolValue]];
        [oldAutoSelectPref restoreDefaultValue];
    }

    [self autoselectSources];

    [self updateChangeCount:NSChangeCleared];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [stream release];
    stream = nil;
    [messageFilter release];
    messageFilter = nil;
    [windowFrameDescription release];
    windowFrameDescription = nil;
    [missingSourceNames release];
    missingSourceNames = nil;
    [history release];
    history = nil;

    [super dealloc];
}

- (void)makeWindowControllers;
{
    NSWindowController *controller;
    
    controller = [[SMMMonitorWindowController alloc] init];
    [self addWindowController:controller];
    [controller release];
}

- (void)showWindows;
{
    [super showWindows];

    if (missingSourceNames) {
        [[self windowControllers] makeObjectsPerformSelector:@selector(couldNotFindSourcesNamed:) withObject:missingSourceNames];
        [missingSourceNames release];
        missingSourceNames = nil;
    }
}

- (NSData *)dataRepresentationOfType:(NSString *)type;
{
    NSMutableDictionary *dict;
    NSDictionary *streamSettings;
    SMMessageType filterMask;
    SMChannelMask channelMask;
    unsigned int historySize;

    dict = [NSMutableDictionary dictionary];
    [dict setObject:[NSNumber numberWithInt:2] forKey:@"version"];

    streamSettings = [stream persistentSettings];
    if (streamSettings)
        [dict setObject:streamSettings forKey:@"streamSettings"];

    historySize = [history historySize];
    if (historySize != [SMMessageHistory defaultHistorySize])
        [dict setObject:[NSNumber numberWithUnsignedInt:historySize] forKey:@"maxMessageCount"];
        
    filterMask = [messageFilter filterMask];
    if (filterMask != SMMessageTypeAllMask)
        [dict setObject:[NSNumber numberWithUnsignedInt:filterMask] forKey:@"filterMask"];

    channelMask = [messageFilter channelMask];
    if (channelMask != SMChannelMaskAll)
        [dict setObject:[NSNumber numberWithUnsignedInt:channelMask] forKey:@"channelMask"];

    if (areSourcesShown)
        [dict setObject:[NSNumber numberWithBool:areSourcesShown] forKey:@"areSourcesShown"];

    if (isFilterShown)
        [dict setObject:[NSNumber numberWithBool:isFilterShown] forKey:@"isFilterShown"];

    if (windowFrameDescription)
        [dict setObject:windowFrameDescription forKey:@"windowFrame"];

    return [dict xmlPropertyListData];
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)type;
{
    NSDictionary *dict;
    int version;
    NSNumber *number;
    NSString *string;
    NSDictionary *streamSettings = nil;

    dict = [data propertyList];
    if (!dict || ![dict isKindOfClass:[NSDictionary class]])
        return NO;

    version = [[dict objectForKey:@"version"] intValue];    
    if (version == 2) {
        streamSettings = [dict objectForKey:@"streamSettings"];
    } else if (version == 1) {
        if ((number = [dict objectForKey:@"sourceEndpointUniqueID"])) {
            streamSettings = [NSDictionary dictionaryWithObjectsAndKeys:number, @"portEndpointUniqueID", [dict objectForKey:@"sourceEndpointName"], @"portEndpointName", nil];
            // NOTE: [dict objectForKey:@"sourceEndpointName"] may be nil--that's acceptable
        } else if ((number = [dict objectForKey:@"virtualDestinationEndpointUniqueID"])) {
            streamSettings = [NSDictionary dictionaryWithObject:number forKey:@"virtualEndpointUniqueID"];
        }
    } else {
        return NO;
    }

    if (streamSettings) {
        [missingSourceNames release];
        missingSourceNames = [[stream takePersistentSettings:streamSettings] retain];
        [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeSources)];
    } else {
        [self setSelectedInputSources:[NSSet set]];
    }
    
    if ((number = [dict objectForKey:@"maxMessageCount"]))
        [self setMaxMessageCount:[number unsignedIntValue]];
    else
        [self setMaxMessageCount:[SMMessageHistory defaultHistorySize]];
        
    if ((number = [dict objectForKey:@"filterMask"]))
        [self setFilterMask:[number unsignedIntValue]];
    else
        [self setFilterMask:SMMessageTypeAllMask];

    if ((number = [dict objectForKey:@"channelMask"]))
        [self setChannelMask:[number unsignedIntValue]];
    else
        [self setChannelMask:SMChannelMaskAll];

    if ((number = [dict objectForKey:@"areSourcesShown"]))
        [self setAreSourcesShown:[number boolValue]];
    else
        [self setAreSourcesShown:NO];
    
    if ((number = [dict objectForKey:@"isFilterShown"]))
        [self setIsFilterShown:[number boolValue]];
    else
        [self setIsFilterShown:NO];

    if ((string = [dict objectForKey:@"windowFrame"]))
        [self setWindowFrameDescription:string];

    // Doing the above caused undo actions to be remembered, but we don't want the user to see them
    [self updateChangeCount:NSChangeCleared];

    return YES;
}

- (void)updateChangeCount:(NSDocumentChangeType)change
{
    // This clears the undo stack whenever we load or save.
    [super updateChangeCount:change];
    if (change == NSChangeCleared)
        [[self undoManager] removeAllActions];
}

- (void)setFileName:(NSString *)fileName;
{
    [super setFileName:fileName];

    [self updateVirtualEndpointName];
}


//
// API for SMMMonitorWindowController
//

- (NSArray *)groupedInputSources
{
    return [stream groupedInputSources];
}

- (NSSet *)selectedInputSources;
{
    return [stream selectedInputSources];
}

- (void)setSelectedInputSources:(NSSet *)inputSources;
{
    NSSet *oldInputSources;
    BOOL savedListenFlag;

    oldInputSources = [self selectedInputSources];
    if (oldInputSources == inputSources || [oldInputSources isEqual:inputSources])
        return;

    savedListenFlag = listenToMIDISetupChanges;
    listenToMIDISetupChanges = NO;
    
    [stream setSelectedInputSources:inputSources];

    [(SMMDocument *)[[self undoManager] prepareWithInvocationTarget:self] setSelectedInputSources:oldInputSources];
    [[self undoManager] setActionName:NSLocalizedStringFromTableInBundle(@"Change Selected Sources", @"MIDIMonitor", [self bundle], "change source undo action")];

    listenToMIDISetupChanges = savedListenFlag;

    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeSources)];
}

- (void)revealInputSources:(NSSet *)inputSources;
{
    [[self windowControllers] makeObjectsPerformSelector:@selector(revealInputSources:) withObject:inputSources];
}

- (unsigned int)maxMessageCount;
{
    return [history historySize];
}

- (void)setMaxMessageCount:(unsigned int)newValue;
{
    if (newValue == [history historySize])
        return;

    [[[self undoManager] prepareWithInvocationTarget:self] setMaxMessageCount:[history historySize]];
    [[self undoManager] setActionName:NSLocalizedStringFromTableInBundle(@"Change Remembered Events", @"MIDIMonitor", [self bundle], "change history limit undo action")];

    [history setHistorySize:newValue];

    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeMaxMessageCount)];
}

- (SMMessageType)filterMask;
{
    return  [messageFilter filterMask];
}

- (void)changeFilterMask:(SMMessageType)maskToChange turnBitsOn:(BOOL)turnBitsOn;
{
    SMMessageType newMask;

    newMask = [messageFilter filterMask];
    if (turnBitsOn)
        newMask |= maskToChange;
    else
        newMask &= ~maskToChange;

    [self setFilterMask:newMask];
}

- (BOOL)isShowingAllChannels;
{
    return ([messageFilter channelMask] == SMChannelMaskAll);
}

- (unsigned int)oneChannelToShow;
{
    // It is possible that something else could have set the mask to show more than one, or zero, channels.
    // We'll just return the lowest enabled channel (1-16), or 0 if no channel is enabled.

    unsigned int channel;
    SMChannelMask mask;

    OBPRECONDITION(![self isShowingAllChannels]);
    
    mask = [messageFilter channelMask];

    for (channel = 0; channel < 16; channel++) {
        if (mask & 1)
            return (channel + 1);
        else
            mask >>= 1;
    }
    
    return 0;    
}

- (void)showAllChannels;
{
    [self setChannelMask:SMChannelMaskAll];
}

- (void)showOnlyOneChannel:(unsigned int)channel;
{
    [self setChannelMask:(1 << (channel - 1))];
}

- (BOOL)areSourcesShown;
{
    return areSourcesShown;
}

- (void)setAreSourcesShown:(BOOL)newValue;
{
    if (newValue == areSourcesShown)
        return;

    areSourcesShown = newValue;
    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeSourcesShown)];    
}

- (BOOL)isFilterShown;
{
    return isFilterShown;
}

- (void)setIsFilterShown:(BOOL)newValue;
{
    if (newValue == isFilterShown)
        return;

    isFilterShown = newValue;
    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeFilterShown)];
}

- (NSString *)windowFrameDescription;
{
    return windowFrameDescription;
}

- (void)setWindowFrameDescription:(NSString *)value;
{
    if (value == windowFrameDescription || [value isEqualToString:windowFrameDescription])
        return;

    [windowFrameDescription release];
    windowFrameDescription = [value retain];
}

- (void)clearSavedMessages;
{
    [history clearSavedMessages];
}

- (NSArray *)savedMessages;
{
    return [history savedMessages];
}

@end


@implementation SMMDocument (Private)

- (void)midiSetupDidChange:(NSNotification *)notification;
{
    if (!listenToMIDISetupChanges)
        return;
    
    // NOTE: It is unfortunate that we have to do this, since it is possible that only
    // destination endpoints changed. It takes a significant amount of time to regenerate the
    // displayed sources.
    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeSources)];

    // Also, it's possible that the endpoint names went from being unique to non-unique, so we need
    // to refresh the messages displayed.
    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeMessages)];
}

- (void)setFilterMask:(SMMessageType)newMask;
{
    SMMessageType oldMask;
    
    oldMask = [messageFilter filterMask];
    if (newMask == oldMask)
        return;

    [[[self undoManager] prepareWithInvocationTarget:self] setFilterMask:oldMask];
    [[self undoManager] setActionName:NSLocalizedStringFromTableInBundle(@"Change Filter", @"MIDIMonitor", [self bundle], change filter undo action)];

    [messageFilter setFilterMask:newMask];    
    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeFilterControls)];
}

- (void)setChannelMask:(SMChannelMask)newMask;
{
    SMChannelMask oldMask;

    oldMask = [messageFilter channelMask];
    if (newMask == oldMask)
        return;

    [[[self undoManager] prepareWithInvocationTarget:self] setChannelMask:oldMask];
    [[self undoManager] setActionName:NSLocalizedStringFromTableInBundle(@"Change Channel", @"MIDIMonitor", [self bundle], change filter channel undo action)];

    [messageFilter setChannelMask:newMask];    
    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeFilterControls)];
}

- (void)updateVirtualEndpointName;
{
    NSString *applicationName, *endpointName;

    applicationName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleNameKey];
    endpointName = [NSString stringWithFormat:@"%@ (%@)", applicationName, [self displayName]];
    [stream setVirtualEndpointName:endpointName];
}

- (void)autoselectSources;
{
    NSArray *groupedInputSources;
    NSMutableSet *sourcesSet;
    NSArray *sourcesArray;

    groupedInputSources = [self groupedInputSources];
    sourcesSet = [NSMutableSet set];
    
    if ([[OFPreference preferenceForKey:SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey] boolValue]) {
        if ((sourcesArray = [[groupedInputSources objectAtIndex:0] objectForKey:@"sources"]))
            [sourcesSet addObjectsFromArray:sourcesArray];
    }

    if ([[OFPreference preferenceForKey:SMMAutoSelectVirtualDestinationInNewDocumentPreferenceKey] boolValue]) {
        if ((sourcesArray = [[groupedInputSources objectAtIndex:1] objectForKey:@"sources"]))
            [sourcesSet addObjectsFromArray:sourcesArray];
    }

    if ([[OFPreference preferenceForKey:SMMAutoSelectSpyingDestinationsInNewDocumentPreferenceKey] boolValue]) {
        if ((sourcesArray = [[groupedInputSources objectAtIndex:2] objectForKey:@"sources"]))
            [sourcesSet addObjectsFromArray:sourcesArray];
    }
    
    [self setSelectedInputSources:sourcesSet];
}

- (void)historyDidChange:(NSNotification *)notification;
{
    // NOTE This can happen in the MIDI thread (for normal MIDI input) or in the main thread (if the "clear" button is used) or in the spy's listener thread (for spying input).

    BOOL shouldScroll;

    shouldScroll = [[[notification userInfo] objectForKey:SMMessageHistoryWereMessagesAdded] boolValue];
    [self mainThreadPerformSelectorOnce:@selector(mainThreadSynchronizeMessagesWithScroll:) withBool:shouldScroll];
}

- (void)mainThreadSynchronizeMessagesWithScroll:(BOOL)shouldScroll
{
    NSArray *windowControllers;
    unsigned int windowControllerIndex;

    windowControllers = [self windowControllers];
    windowControllerIndex = [windowControllers count];
    while (windowControllerIndex--)
        [[windowControllers objectAtIndex:windowControllerIndex] synchronizeMessagesWithScrollToBottom:shouldScroll];
}

- (void)readingSysEx:(NSNotification *)notification;
{
    // NOTE This can happen in the MIDI thread (for normal MIDI input) or in the spy's listener thread (for spying input).

    sysExBytesRead = [[[notification userInfo] objectForKey:@"length"] unsignedIntValue];
    [self queueSelectorOnce:@selector(mainThreadReadingSysEx)];
        // We want multiple updates to get coalesced, so only queue it once
}

- (void)mainThreadReadingSysEx;
{
    [[self windowControllers] makeObjectsPerformSelector:@selector(updateSysExReadIndicatorWithBytes:) withObject:[NSNumber numberWithUnsignedInt:sysExBytesRead]];
}

- (void)doneReadingSysEx:(NSNotification *)notification;
{
    // NOTE This can happen in the MIDI thread (for normal MIDI input) or in the spy's listener thread (for spying input).
    NSNumber *number;

    number = [[notification userInfo] objectForKey:@"length"];
    sysExBytesRead = [number unsignedIntValue];
    [self queueSelector:@selector(mainThreadDoneReadingSysEx:) withObject:number];
        // We DON'T want this to get coalesced, so always queue it.
        // Pass the number of bytes read down, since sysExBytesRead may be overwritten before mainThreadDoneReadingSysEx gets called.
}

- (void)mainThreadDoneReadingSysEx:(NSNumber *)bytesReadNumber;
{
    [[self windowControllers] makeObjectsPerformSelector:@selector(stopSysExReadIndicatorWithBytes:) withObject:bytesReadNumber];
}

@end
