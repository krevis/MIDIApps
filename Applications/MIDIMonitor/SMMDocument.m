#import "SMMDocument.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMMonitorWindowController.h"


@interface SMMDocument (Private)

- (void)_midiSetupDidChange:(NSNotification *)notification;

- (void)_setFilterMask:(SMMessageType)newMask;
- (void)_setChannelMask:(SMChannelMask)newMask;

- (void)_updateVirtualEndpointName;

- (void)_streamEndpointWasRemoved:(NSNotification *)notification;

- (void)_selectFirstAvailableSource;

- (void)_historyDidChange:(NSNotification *)notification;
- (void)_mainThreadSynchronizeMessages;
- (void)_mainThreadScrollToLastMessage;

- (void)_readingSysEx:(NSNotification *)notification;
- (void)_mainThreadReadingSysEx;

- (void)_doneReadingSysEx:(NSNotification *)notification;
- (void)_mainThreadDoneReadingSysEx:(NSNumber *)bytesReadNumber;

@end


@implementation SMMDocument

NSString *SMMAutoSelectFirstSourceInNewDocumentPreferenceKey = @"SMMAutoSelectFirstSource";
NSString *SMMAutoSelectFirstSourceIfSourceDisappearsPreferenceKey = @"SMMAutoSelectFirstSourceIfSourceDisappears";


- (id)init
{
    NSNotificationCenter *center;

    if (!(self = [super init]))
        return nil;

    center = [NSNotificationCenter defaultCenter];

    stream = [[SMPortOrVirtualInputStream alloc] init];
    [center addObserver:self selector:@selector(_streamEndpointWasRemoved:) name:SMPortOrVirtualInputStreamEndpointWasRemoved object:stream];
    [center addObserver:self selector:@selector(_readingSysEx:) name:SMInputStreamReadingSysExNotification object:stream];
    [center addObserver:self selector:@selector(_doneReadingSysEx:) name:SMInputStreamDoneReadingSysExNotification object:stream];
    [stream setVirtualDisplayName:NSLocalizedStringFromTableInBundle(@"Act as a destination for other programs", @"MIDIMonitor", [self bundle], "title of popup menu item for virtual destination")];
    [self _updateVirtualEndpointName];

    messageFilter = [[SMMessageFilter alloc] init];
    [stream setMessageDestination:messageFilter];
    [messageFilter setFilterMask:SMMessageTypeAllMask];
    [messageFilter setChannelMask:SMChannelMaskAll];

    history = [[SMMessageHistory alloc] init];
    [messageFilter setMessageDestination:history];
    [center addObserver:self selector:@selector(_historyDidChange:) name:SMMessageHistoryChangedNotification object:history];

    isFilterShown = NO;
    listenToMIDISetupChanges = YES;
    missingSourceName = nil;
    sysExBytesRead = 0;

    [center addObserver:self selector:@selector(_midiSetupDidChange:) name:SMClientSetupChangedNotification object:[SMClient sharedClient]];

    if ([[OFPreference preferenceForKey:SMMAutoSelectFirstSourceInNewDocumentPreferenceKey] boolValue]) {
        [self _selectFirstAvailableSource];
    }

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
    [missingSourceName release];
    missingSourceName = nil;
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

    if (missingSourceName) {
        [[self windowControllers] makeObjectsPerformSelector:@selector(couldNotFindSourceNamed:) withObject:missingSourceName];
        [missingSourceName release];
        missingSourceName = nil;
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
        [missingSourceName release];
        missingSourceName = [[stream takePersistentSettings:streamSettings] retain];
        [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeSources)];
    } else {
        [self setSourceDescription:nil];
    }
    
    if ((number = [dict objectForKey:@"maxMessageCount"]))
        [self setMaxMessageCount:[number unsignedIntValue]];
    else
        [self setMaxMessageCount:[SMMessageHistory defaultHistorySize]];
        
    if ((number = [dict objectForKey:@"filterMask"]))
        [self _setFilterMask:[number unsignedIntValue]];
    else
        [self _setFilterMask:SMMessageTypeAllMask];

    if ((number = [dict objectForKey:@"channelMask"]))
        [self _setChannelMask:[number unsignedIntValue]];
    else
        [self _setChannelMask:SMChannelMaskAll];

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

    [self _updateVirtualEndpointName];
}


//
// API for SMMMonitorWindowController
//

- (NSArray *)sourceDescriptions;
{
    return [stream sourceDescriptions];
}

- (NSDictionary *)sourceDescription;
{
    return [stream sourceDescription];
}

- (void)setSourceDescription:(NSDictionary *)description;
{
    NSDictionary *oldDescription;
    BOOL savedListenFlag;
    
    oldDescription = [self sourceDescription];
    if (oldDescription == description || [oldDescription isEqual:description])
        return;

    savedListenFlag = listenToMIDISetupChanges;
    listenToMIDISetupChanges = NO;

    [stream setSourceDescription:description];

    [[[self undoManager] prepareWithInvocationTarget:self] setSourceDescription:oldDescription];
    [[self undoManager] setActionName:NSLocalizedStringFromTableInBundle(@"Change Source", @"MIDIMonitor", [self bundle], "change source undo action")];

    listenToMIDISetupChanges = savedListenFlag;
    
    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeSources)];
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

    [self _setFilterMask:newMask];
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
    [self _setChannelMask:SMChannelMaskAll];
}

- (void)showOnlyOneChannel:(unsigned int)channel;
{
    [self _setChannelMask:(1 << (channel - 1))];
}

- (BOOL)isFilterShown;
{
    return isFilterShown;
}

- (void)setIsFilterShown:(BOOL)newValue;
{
    if (newValue == isFilterShown)
        return;

    [[[self undoManager] prepareWithInvocationTarget:self] setIsFilterShown:isFilterShown];
    [[self undoManager] setActionName:(newValue ? 
        NSLocalizedStringFromTableInBundle(@"Show Filter", @"MIDIMonitor", [self bundle], "show filter undo action") :
        NSLocalizedStringFromTableInBundle(@"Hide Filter", @"MIDIMonitor", [self bundle], "hide filter undo action"))];

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

    [self updateChangeCount:NSChangeDone];
    
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

- (void)_midiSetupDidChange:(NSNotification *)notification;
{
    if (listenToMIDISetupChanges)
        [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeSources)];

    // NOTE: It is unfortunate that we have to do this, since it is possible that only
    // destination endpoints changed. It takes a significant amount of time to regenerate the
    // sources popup menu.
}

- (void)_setFilterMask:(SMMessageType)newMask;
{
    SMMessageType oldMask;
    
    oldMask = [messageFilter filterMask];
    if (newMask == oldMask)
        return;

    [[[self undoManager] prepareWithInvocationTarget:self] _setFilterMask:oldMask];
    [[self undoManager] setActionName:NSLocalizedStringFromTableInBundle(@"Change Filter", @"MIDIMonitor", [self bundle], change filter undo action)];

    [messageFilter setFilterMask:newMask];    
    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeFilterControls)];
}

- (void)_setChannelMask:(SMChannelMask)newMask;
{
    SMChannelMask oldMask;

    oldMask = [messageFilter channelMask];
    if (newMask == oldMask)
        return;

    [[[self undoManager] prepareWithInvocationTarget:self] _setChannelMask:oldMask];
    [[self undoManager] setActionName:NSLocalizedStringFromTableInBundle(@"Change Channel", @"MIDIMonitor", [self bundle], change filter channel undo action)];

    [messageFilter setChannelMask:newMask];    
    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeFilterControls)];
}

- (void)_updateVirtualEndpointName;
{
    NSString *applicationName, *endpointName;
    
    applicationName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleNameKey];
    endpointName = [NSString stringWithFormat:@"%@ (%@)", applicationName, [self displayName]];
    [stream setVirtualEndpointName:endpointName];
}

- (void)_streamEndpointWasRemoved:(NSNotification *)notification;
{
    if ([[OFPreference preferenceForKey:SMMAutoSelectFirstSourceIfSourceDisappearsPreferenceKey] boolValue]) {
        [self _selectFirstAvailableSource];
    }
}

- (void)_selectFirstAvailableSource;
{
    NSArray *descriptions;
    
    descriptions = [stream sourceDescriptions];
    if ([descriptions count] > 0)
        [stream setSourceDescription:[descriptions objectAtIndex:0]];
}

- (void)_historyDidChange:(NSNotification *)notification;
{
    // NOTE This is happening in the MIDI thread

    [self queueSelectorOnce:@selector(_mainThreadSynchronizeMessages)];

    if ([[[notification userInfo] objectForKey:SMMessageHistoryWereMessagesAdded] boolValue])
        [self queueSelectorOnce:@selector(_mainThreadScrollToLastMessage)];
}

- (void)_mainThreadSynchronizeMessages;
{    
    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeMessages)];
}

- (void)_mainThreadScrollToLastMessage;
{
    [[self windowControllers] makeObjectsPerformSelector:@selector(scrollToLastMessage)];
}

- (void)_readingSysEx:(NSNotification *)notification;
{
    // NOTE This is happening in the MIDI thread

    sysExBytesRead = [[[notification userInfo] objectForKey:@"length"] unsignedIntValue];
    [self queueSelectorOnce:@selector(_mainThreadReadingSysEx)];
        // We don't mind if this gets coalesced
}

- (void)_mainThreadReadingSysEx;
{
    [[self windowControllers] makeObjectsPerformSelector:@selector(updateSysExReadIndicatorWithBytes:) withObject:[NSNumber numberWithUnsignedInt:sysExBytesRead]];
}

- (void)_doneReadingSysEx:(NSNotification *)notification;
{
    // NOTE This is happening in the MIDI thread
    NSNumber *number;

    number = [[notification userInfo] objectForKey:@"length"];
    sysExBytesRead = [number unsignedIntValue];
    [self queueSelector:@selector(_mainThreadDoneReadingSysEx:) withObject:number];
        // We DO mind if this gets coalesced, so always queue it
}

- (void)_mainThreadDoneReadingSysEx:(NSNumber *)bytesReadNumber;
{
    [[self windowControllers] makeObjectsPerformSelector:@selector(stopSysExReadIndicatorWithBytes:) withObject:bytesReadNumber];
}

@end
