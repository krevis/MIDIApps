#import "SSEMainController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SSEMainWindowController.h"


@interface SSEMainController (Private)

- (void)_midiSetupDidChange:(NSNotification *)notification;

- (void)_inputStreamEndpointWasRemoved:(NSNotification *)notification;
- (void)_outputStreamEndpointWasRemoved:(NSNotification *)notification;

- (void)_selectFirstAvailableSource;
- (void)_selectFirstAvailableDestination;

- (void)_readingSysEx:(NSNotification *)notification;
- (void)_mainThreadReadingSysEx;

- (void)_doneReadingSysEx:(NSNotification *)notification;
- (void)_mainThreadDoneReadingSysEx:(NSNumber *)bytesReadNumber;

@end


@implementation SSEMainController

- (id)init
{
    NSNotificationCenter *center;

    if (!(self = [super init]))
        return nil;

    center = [NSNotificationCenter defaultCenter];

    inputStream = [[SMPortOrVirtualInputStream alloc] init];
    [center addObserver:self selector:@selector(_inputStreamEndpointWasRemoved:) name:SMPortOrVirtualStreamEndpointWasRemoved object:inputStream];
    [center addObserver:self selector:@selector(_readingSysEx:) name:SMInputStreamReadingSysExNotification object:inputStream];
    [center addObserver:self selector:@selector(_doneReadingSysEx:) name:SMInputStreamDoneReadingSysExNotification object:inputStream];
    [inputStream setVirtualDisplayName:NSLocalizedStringFromTableInBundle(@"Act as a destination for other programs", @"SysExLibrarian", [self bundle], "title of popup menu item for virtual destination")];
    [inputStream setVirtualEndpointName:@"SysEx Librarian"];	// TODO get this from somewhere
    [inputStream setMessageDestination:self];

    outputStream = [[SMPortOrVirtualOutputStream alloc] init];
    [outputStream setIgnoresTimeStamps:YES];
//    [outputStream setSendsSysExAsynchronously:YES];	// TODO frob this  ... sending synchronously seems faster
    [center addObserver:self selector:@selector(_outputStreamEndpointWasRemoved:) name:SMPortOrVirtualStreamEndpointWasRemoved object:outputStream];
    [outputStream setVirtualDisplayName:NSLocalizedStringFromTableInBundle(@"Act as a source for other programs", @"SysExLibrarian", [self bundle], "title of popup menu item for virtual source")];
    [outputStream setVirtualEndpointName:@"SysEx Librarian"];	// TODO get this from somewhere
    
    listenToMIDISetupChanges = YES;
    sysExBytesRead = 0;
    waitingForSysExMessage = NO;

    [center addObserver:self selector:@selector(_midiSetupDidChange:) name:SMClientSetupChangedNotification object:[SMClient sharedClient]];

    // TODO should get selected source and dest from preferences
    [self _selectFirstAvailableSource];
    [self _selectFirstAvailableDestination];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [inputStream release];
    inputStream = nil;
    [outputStream release];
    outputStream = nil;

    [super dealloc];
}

//
// API for SSEMainWindowController
//

- (NSArray *)sourceDescriptions;
{
    return [inputStream endpointDescriptions];
}

- (NSDictionary *)sourceDescription;
{
    return [inputStream endpointDescription];
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

    [inputStream setEndpointDescription:description];
    // TODO we don't have an undo manager yet
//    [[[self undoManager] prepareWithInvocationTarget:self] setSourceDescription:oldDescription];
//    [[self undoManager] setActionName:NSLocalizedStringFromTableInBundle(@"Change Source", @"SysExLibrarian", [self bundle], "change source undo action")];

    listenToMIDISetupChanges = savedListenFlag;

    [windowController synchronizeSources];
}

- (NSArray *)destinationDescriptions;
{
    return [outputStream endpointDescriptions];
}

- (NSDictionary *)destinationDescription;
{
    return [outputStream endpointDescription];
}

- (void)setDestinationDescription:(NSDictionary *)description;
{
    NSDictionary *oldDescription;
    BOOL savedListenFlag;

    oldDescription = [self destinationDescription];
    if (oldDescription == description || [oldDescription isEqual:description])
        return;

    savedListenFlag = listenToMIDISetupChanges;
    listenToMIDISetupChanges = NO;

    [outputStream setEndpointDescription:description];
    // TODO we don't have an undo manager yet
    //    [[[self undoManager] prepareWithInvocationTarget:self] setSourceDescription:oldDescription];
    //    [[self undoManager] setActionName:NSLocalizedStringFromTableInBundle(@"Change Source", @"SysExLibrarian", [self bundle], "change source undo action")];

    listenToMIDISetupChanges = savedListenFlag;

    [windowController synchronizeDestinations];
}

- (void)waitForOneSysExMessage;
{
    waitingForSysExMessage = YES;
}

- (void)cancelSysExMessageWait;
{
    waitingForSysExMessage = NO;
}

- (void)playSysExMessage;
{
    if (sysExMessage)
        [outputStream takeMIDIMessages:[NSArray arrayWithObject:sysExMessage]];
}

//
// SMMessageDestination protocol
//

- (void)takeMIDIMessages:(NSArray *)messages;
{
    unsigned int messageCount, messageIndex;

    if (!waitingForSysExMessage)
        return;

    messageCount = [messages count];
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMMessage *message;

        message = [messages objectAtIndex:messageIndex];
        if ([message isKindOfClass:[SMSystemExclusiveMessage class]]) {
            waitingForSysExMessage = NO;
            [sysExMessage release];
            sysExMessage = [message retain];
            // TODO need to send a notification or something... do it in the main thread

//            NSLog(@"received sysex: %lu bytes, checksum %@", [(SMSystemExclusiveMessage *)message fullMessageDataLength], [[[(SMSystemExclusiveMessage *)message fullMessageData] md5Signature] unadornedLowercaseHexString]);
            break;
        }
    }    
}

@end


@implementation SSEMainController (Private)

- (void)_midiSetupDidChange:(NSNotification *)notification;
{
    if (listenToMIDISetupChanges) {
        [windowController synchronizeSources];
        [windowController synchronizeDestinations];
    }
}

- (void)_inputStreamEndpointWasRemoved:(NSNotification *)notification;
{
    // TODO should print a message?
    [self _selectFirstAvailableSource];
}

- (void)_outputStreamEndpointWasRemoved:(NSNotification *)notification;
{
    // TODO should print a message?
    [self _selectFirstAvailableDestination];
}

- (void)_selectFirstAvailableSource;
{
    NSArray *descriptions;

    descriptions = [inputStream endpointDescriptions];
    if ([descriptions count] > 0)
        [inputStream setEndpointDescription:[descriptions objectAtIndex:0]];
}

- (void)_selectFirstAvailableDestination;
{
    NSArray *descriptions;

    descriptions = [outputStream endpointDescriptions];
    if ([descriptions count] > 0)
        [outputStream setEndpointDescription:[descriptions objectAtIndex:0]];
}

- (void)_readingSysEx:(NSNotification *)notification;
{
    // NOTE This is happening in the MIDI thread

    sysExBytesRead = [[[notification userInfo] objectForKey:@"length"] unsignedIntValue];
    [self queueSelectorOnce:@selector(_mainThreadReadingSysEx)];
        // We want multiple updates to get coalesced, so only queue it once
}

- (void)_mainThreadReadingSysEx;
{
    [windowController updateSysExReadIndicatorWithBytes:sysExBytesRead];
}

- (void)_doneReadingSysEx:(NSNotification *)notification;
{
    // NOTE This is happening in the MIDI thread
    NSNumber *number;

    number = [[notification userInfo] objectForKey:@"length"];
    sysExBytesRead = [number unsignedIntValue];
    [self queueSelector:@selector(_mainThreadDoneReadingSysEx:) withObject:number];
        // We DON'T want this to get coalesced, so always queue it.
        // Pass the number of bytes read down, since sysExBytesRead may be overwritten before _mainThreadDoneReadingSysEx gets called.
}

- (void)_mainThreadDoneReadingSysEx:(NSNumber *)bytesReadNumber;
{
    [windowController stopSysExReadIndicatorWithBytes:[bytesReadNumber unsignedIntValue]];
}

@end
