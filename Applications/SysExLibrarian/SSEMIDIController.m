#import "SSEMIDIController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SSEMainWindowController.h"
#import "SSEPreferencesWindowController.h"


// Turn this on to NSLog the actual amount of time we pause between messages
#define LOG_PAUSE_DURATION 0


@interface SSEMIDIController (Private)

- (void)_midiSetupDidChange:(NSNotification *)notification;
- (void)_sendPreferenceDidChange:(NSNotification *)notification;
- (void)_receivePreferenceDidChange:(NSNotification *)notification;

- (void)_endpointAppeared:(NSNotification *)notification;
- (void)_outputStreamEndpointDisappeared:(NSNotification *)notification;

- (void)_selectFirstAvailableDestinationWhenPossible;
- (void)_selectFirstAvailableDestination;

- (void)_startListening;
- (void)_readingSysEx:(NSNotification *)notification;
- (void)_mainThreadTakeMIDIMessages:(NSArray *)messagesToTake;

- (void)_sendNextSysExMessage;
- (void)_willStartSendingSysEx:(NSNotification *)notification;
- (void)_doneSendingSysEx:(NSNotification *)notification;

@end


@implementation SSEMIDIController

NSString *SSESelectedDestinationPreferenceKey = @"SSESelectedDestination";
NSString *SSEHasShownSysExWorkaroundWarningPreferenceKey = @"SSEHasShownSysExWorkaroundWarning";
NSString *SSESysExReadTimeOutPreferenceKey = @"SSESysExReadTimeOut";
NSString *SSESysExIntervalBetweenSentMessagesPreferenceKey = @"SSESysExIntervalBetweenSentMessages";

DEFINE_NSSTRING(SSEMIDIControllerReadStatusChangedNotification);
DEFINE_NSSTRING(SSEMIDIControllerReadFinishedNotification);


- (id)init
{
    NSNotificationCenter *center;
    NSArray *sources;
    unsigned int sourceIndex;

    if (!(self = [super init]))
        return nil;

    center = [NSNotificationCenter defaultCenter];

    inputStream = [[SMPortInputStream alloc] init];
    [center addObserver:self selector:@selector(_readingSysEx:) name:SMInputStreamReadingSysExNotification object:inputStream];
    [center addObserver:self selector:@selector(_readingSysEx:) name:SMInputStreamDoneReadingSysExNotification object:inputStream];
    [inputStream setMessageDestination:self];
    sources = [SMSourceEndpoint sourceEndpoints];
    sourceIndex = [sources count];
    while (sourceIndex--)
        [inputStream addEndpoint:[sources objectAtIndex:sourceIndex]];

    outputStream = [[SMPortOrVirtualOutputStream alloc] init];
    [center addObserver:self selector:@selector(_outputStreamEndpointDisappeared:) name:SMPortOrVirtualStreamEndpointDisappearedNotification object:outputStream];
    [center addObserver:self selector:@selector(_willStartSendingSysEx:) name:SMPortOutputStreamWillStartSysExSendNotification object:outputStream];
    [center addObserver:self selector:@selector(_doneSendingSysEx:) name:SMPortOutputStreamFinishedSysExSendNotification object:outputStream];
    [outputStream setIgnoresTimeStamps:YES];
    [outputStream setSendsSysExAsynchronously:YES];
    [outputStream setVirtualDisplayName:NSLocalizedStringFromTableInBundle(@"Act as a source for other programs", @"SysExLibrarian", [self bundle], "title of popup menu item for virtual source")];

    [center addObserver:self selector:@selector(_endpointAppeared:) name:SMEndpointAppearedNotification object:nil];
    
    listenToMIDISetupChanges = YES;

    messages = [[NSMutableArray alloc] init];    
    messageBytesRead = 0;
    totalBytesRead = 0;

    listeningToMessages = NO;
    listenToMultipleMessages = NO;

    sendProgressLock = [[NSLock alloc] init];
    
    [center addObserver:self selector:@selector(_midiSetupDidChange:) name:SMClientSetupChangedNotification object:[SMClient sharedClient]];

    [self _sendPreferenceDidChange:nil];
    [center addObserver:self selector:@selector(_sendPreferenceDidChange:) name:SSESysExSendPreferenceChangedNotification object:nil];

    [self _receivePreferenceDidChange:nil];
    [center addObserver:self selector:@selector(_receivePreferenceDidChange:) name:SSESysExReceivePreferenceChangedNotification object:nil];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [inputStream release];
    inputStream = nil;
    [outputStream release];
    outputStream = nil;
    [messages release];
    messages = nil;
    [sendProgressLock release];
    sendProgressLock = nil;
    [sendNextMessageEvent release];
    sendNextMessageEvent = nil;

    [super dealloc];
}

- (void)awakeFromNib;
{
    // We do this now instead of in -init, because we may need to use our outlet to the windowController.

    BOOL didSetDestinationFromDefaults;
    NSDictionary *destinationSettings;

    didSetDestinationFromDefaults = NO;
    destinationSettings = [[OFPreference preferenceForKey:SSESelectedDestinationPreferenceKey] dictionaryValue];
    if (destinationSettings) {
        NSString *missingDestinationName;

        missingDestinationName = [outputStream takePersistentSettings:destinationSettings];
        if (!missingDestinationName)
            didSetDestinationFromDefaults = YES;
    }

    if (!didSetDestinationFromDefaults)
        [self _selectFirstAvailableDestination];
}

//
// API for SSEMainWindowController
//

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

    listenToMIDISetupChanges = savedListenFlag;

    [windowController synchronizeDestinations];

    [[OFPreference preferenceForKey:SSESelectedDestinationPreferenceKey] setDictionaryValue:[outputStream persistentSettings]];

    if ([(SMEndpoint *)[description objectForKey:@"endpoint"] needsSysExWorkaround]) {
        if ([[OFPreference preferenceForKey:SSEHasShownSysExWorkaroundWarningPreferenceKey] boolValue] == NO) {
            [windowController showSysExWorkaroundWarning];
        }
    }
}

- (NSArray *)messages;
{
    return messages;
}

- (void)setMessages:(NSArray *)value;
{
    // Shouldn't do this while listening for messages or playing messages
    OBASSERT(listeningToMessages == NO);
    OBASSERT(nonretainedCurrentSendRequest == nil);
    
    if (value != messages) {
        [messages release];
        messages = [[NSMutableArray alloc] initWithArray:value];
    }
}

//
// Listening to sysex messages
//

- (void)listenForOneMessage;
{
    listenToMultipleMessages = NO;
    [self _startListening];
}

- (void)listenForMultipleMessages;
{
    listenToMultipleMessages = YES;
    [self _startListening];
}

- (void)cancelMessageListen;
{
    listeningToMessages = NO;
    [inputStream cancelReceivingSysExMessage];

    [messages removeAllObjects];
    messageBytesRead = 0;
    totalBytesRead = 0;
}

- (void)doneWithMultipleMessageListen;
{
    listeningToMessages = NO;
    [inputStream cancelReceivingSysExMessage];
}

- (void)getMessageCount:(unsigned int *)messageCountPtr bytesRead:(unsigned int *)bytesReadPtr totalBytesRead:(unsigned int *)totalBytesReadPtr;
{
    // There is no need to put a lock around these things, assuming that we are in the main thread.
    // messageBytesRead gets changed in a different thread, but it gets changed atomically.
    // messages and totalBytesRead are only modified in the main thread.
    OBASSERT([NSThread inMainThread]);

    if (messageCountPtr)
        *messageCountPtr = [messages count];
    if (bytesReadPtr)
        *bytesReadPtr = messageBytesRead;
    if (totalBytesReadPtr)
        *totalBytesReadPtr = totalBytesRead;
}

//
// Sending sysex messages
//

- (void)sendMessages;
{
    unsigned int messageIndex, messageCount;

    OBASSERT([NSThread inMainThread]);

    if (!messages || (messageCount = [messages count]) == 0)
        return;

    if (![outputStream canSendSysExAsynchronously]) {
        // Just dump all the messages out at once
        [outputStream takeMIDIMessages:messages];
        return;
    }

    nonretainedCurrentSendRequest = nil;
    sendingMessageCount = messageCount;
    sendingMessageIndex = 0;
    bytesToSend = 0;
    bytesSent = 0;
    sendCancelled = NO;

    for (messageIndex = 0; messageIndex < messageCount; messageIndex++)
        bytesToSend += [[messages objectAtIndex:messageIndex] fullMessageDataLength];

    [windowController showSysExSendStatus];
    [self _sendNextSysExMessage];
}

- (void)cancelSendingMessages;
{
    OBASSERT([NSThread inMainThread]);

    if (sendNextMessageEvent && [[OFScheduler mainScheduler] abortEvent:sendNextMessageEvent]) {
        [windowController hideSysExSendStatusWithSuccess:NO];
    } else {
        sendCancelled = YES;
        [outputStream cancelPendingSysExSendRequests];
        // We will get notified when the current send request is finished
    }
}

- (void)getMessageCount:(unsigned int *)messageCountPtr messageIndex:(unsigned int *)messageIndexPtr bytesToSend:(unsigned int *)bytesToSendPtr bytesSent:(unsigned int *)bytesSentPtr;
{
    OBASSERT([NSThread inMainThread]);

    [sendProgressLock lock];
    
    if (messageCountPtr)
        *messageCountPtr = sendingMessageCount;
    if (messageIndexPtr)
        *messageIndexPtr = sendingMessageIndex;
    if (bytesToSendPtr)
        *bytesToSendPtr = bytesToSend;
    if (bytesSentPtr) {
        *bytesSentPtr = bytesSent;
        if (nonretainedCurrentSendRequest)
            *bytesSentPtr += [nonretainedCurrentSendRequest bytesSent];
    }

    [sendProgressLock unlock];
}


//
// SMMessageDestination protocol
//

- (void)takeMIDIMessages:(NSArray *)messagesToTake;
{
    [self queueSelector:@selector(_mainThreadTakeMIDIMessages:) withObject:messagesToTake];
}

@end


@implementation SSEMIDIController (Private)

- (void)_midiSetupDidChange:(NSNotification *)notification;
{
    if (listenToMIDISetupChanges) {
        [windowController synchronizeDestinations];
    }
}

- (void)_sendPreferenceDidChange:(NSNotification *)notification;
{
    pauseTimeBetweenMessages = (double)[[OFPreference preferenceForKey:SSESysExIntervalBetweenSentMessagesPreferenceKey] integerValue] / 1000.0;
}

- (void)_receivePreferenceDidChange:(NSNotification *)notification;
{
    double sysExReadTimeOut;

    sysExReadTimeOut = (double)[[OFPreference preferenceForKey:SSESysExReadTimeOutPreferenceKey] integerValue] / 1000.0;
    [inputStream setSysExTimeOut:sysExReadTimeOut];
}

- (void)_endpointAppeared:(NSNotification *)notification;
{
    SMEndpoint *endpoint;

    endpoint = [notification object];
    if ([endpoint isKindOfClass:[SMSourceEndpoint class]])
        [inputStream addEndpoint:(SMSourceEndpoint *)endpoint];
}

- (void)_outputStreamEndpointDisappeared:(NSNotification *)notification;
{
    if (nonretainedCurrentSendRequest || sendNextMessageEvent)
        [self cancelSendingMessages];

    [self _selectFirstAvailableDestinationWhenPossible];
}

- (void)_selectFirstAvailableDestinationWhenPossible;
{
    // NOTE: We may be handling a MIDI change notification right now. We might want to select a virtual source
    // but an SMVirtualInputStream can't be created in the middle of handling this notification, so do it later.

    if ([[SMClient sharedClient] isHandlingSetupChange]) {
        [self performSelector:_cmd withObject:nil afterDelay:0.1];
        // NOTE Delay longer than 0 is a tradeoff; it means there's a brief window when no destination will be selected.
        // A delay of 0 means that we'll get called many times (about 20 in practice) before the setup change is finished.
    } else {
        [self _selectFirstAvailableDestination];
    }
}

- (void)_selectFirstAvailableDestination;
{
    NSArray *descriptions;

    descriptions = [outputStream endpointDescriptions];
    if ([descriptions count] > 0)
        [self setDestinationDescription:[descriptions objectAtIndex:0]];
}


//
// Listening to sysex messages
//

- (void)_startListening;
{
    OBASSERT(listeningToMessages == NO);
    
    [inputStream cancelReceivingSysExMessage];
        // In case a sysex message is currently being received

    [messages removeAllObjects];
    messageBytesRead = 0;
    totalBytesRead = 0;

    listeningToMessages = YES;
}

- (void)_readingSysEx:(NSNotification *)notification;
{
    // NOTE This is happening in the MIDI thread

    messageBytesRead = [[[notification userInfo] objectForKey:@"length"] unsignedIntValue];
    [self queueSelectorOnce:@selector(_updateSysExReadIndicator)];
        // We want multiple updates to get coalesced, so only queue it once
}

- (void)_updateSysExReadIndicator;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SSEMIDIControllerReadStatusChangedNotification object:self];
}

- (void)_mainThreadTakeMIDIMessages:(NSArray *)messagesToTake;
{
    unsigned int messageCount, messageIndex;

    if (!listeningToMessages)
        return;

    messageCount = [messagesToTake count];
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMMessage *message;

        message = [messagesToTake objectAtIndex:messageIndex];
        if ([message isKindOfClass:[SMSystemExclusiveMessage class]]) {
            [messages addObject:message];
            totalBytesRead += messageBytesRead;
            messageBytesRead = 0;

            [self _updateSysExReadIndicator];
            if (listenToMultipleMessages == NO)  {
                listeningToMessages = NO;

                [[NSNotificationCenter defaultCenter] postNotificationName:SSEMIDIControllerReadFinishedNotification object:self];
                break;
            }
        }
    }
}


//
// Sending sysex messages
//

#if LOG_PAUSE_DURATION
static MIDITimeStamp pauseStartTimeStamp = 0;
#endif

- (void)_sendNextSysExMessage;
{
#if LOG_PAUSE_DURATION
    if (pauseStartTimeStamp > 0) {
        UInt64 realPauseDuration;

        realPauseDuration = SMGetCurrentHostTime() - pauseStartTimeStamp;
        NSLog(@"pause took %f ms", (double)SMConvertHostTimeToNanos(realPauseDuration) / 1.0e6);
    }
#endif
    
    [sendNextMessageEvent release];
    sendNextMessageEvent = nil;

    [outputStream takeMIDIMessages:[NSArray arrayWithObject:[messages objectAtIndex:sendingMessageIndex]]];
}

- (void)_willStartSendingSysEx:(NSNotification *)notification;
{    
    OBASSERT(nonretainedCurrentSendRequest == nil);
    nonretainedCurrentSendRequest = [[notification userInfo] objectForKey:@"sendRequest"];
}

- (void)_doneSendingSysEx:(NSNotification *)notification;
{
    // NOTE This is happening in the MIDI thread, probably.
    // The request may or may not have finished successfully.
    SMSysExSendRequest *sendRequest;

    sendRequest = [[notification userInfo] objectForKey:@"sendRequest"];
    OBASSERT(sendRequest == nonretainedCurrentSendRequest);

    [sendProgressLock lock];

    bytesSent += [sendRequest bytesSent];
    sendingMessageIndex++;
    nonretainedCurrentSendRequest = nil;
    
    [sendProgressLock unlock];

#if LOG_PAUSE_DURATION
    pauseStartTimeStamp = 0;
#endif
    
    if (sendCancelled) {
        [windowController mainThreadPerformSelector:@selector(hideSysExSendStatusWithSuccess:) withBool:NO];
    } else if (sendingMessageIndex < sendingMessageCount && [sendRequest wereAllBytesSent]) {
#if LOG_PAUSE_DURATION
        pauseStartTimeStamp = SMGetCurrentHostTime();
#endif
        sendNextMessageEvent = [[[OFScheduler mainScheduler] scheduleSelector:@selector(_sendNextSysExMessage) onObject:self afterTime:pauseTimeBetweenMessages] retain];
    } else {
        [windowController mainThreadPerformSelector:@selector(hideSysExSendStatusWithSuccess:) withBool:[sendRequest wereAllBytesSent]];
    }
}

@end
