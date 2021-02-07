/*
 Copyright (c) 2002-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSEMIDIController.h"

@import SnoizeMIDI;
#import "SysEx_Librarian-Swift.h"
#import "SSEMainWindowController.h"


// Turn this on to NSLog the actual amount of time we pause between messages
#define LOG_PAUSE_DURATION 0
#if LOG_PAUSE_DURATION
@import CoreAudio;
#endif


@interface SSEMIDIController (Private)

- (void)sendPreferenceDidChange:(NSNotification *)notification;
- (void)receivePreferenceDidChange:(NSNotification *)notification;
- (void)listenForProgramChangesPreferenceDidChange:(NSNotification*)n;

- (void)portInputStreamSourceListChanged:(NSNotification *)notification;

- (void)midiSetupChanged:(NSNotification *)notification;
- (void)outputStreamSelectedDestinationDisappeared:(NSNotification *)notification;

- (void)selectFirstAvailableDestinationWhenPossible;
- (void)selectFirstAvailableDestination;

- (void)startListening;
- (void)readingSysEx:(NSNotification *)notification;
- (void)updateSysExReadIndicator;

- (void)sendNextSysExMessage;
- (void)sendNextSysExMessageAfterDelay;
- (void)willStartSendingSysEx:(NSNotification *)notification;
- (void)doneSendingSysEx:(NSNotification *)notification;
- (void)finishedSendingMessagesWithSuccess:(BOOL)success;

- (void)customSysexBufferSizeChanged:(NSNotification *)notification;

@end


@implementation SSEMIDIController {
    MIDIContext *midiContext;
}

NSString *SSESelectedDestinationPreferenceKey = @"SSESelectedDestination";
NSString *SSESysExReadTimeOutPreferenceKey = @"SSESysExReadTimeOut";
NSString *SSESysExIntervalBetweenSentMessagesPreferenceKey = @"SSESysExIntervalBetweenSentMessages";
NSString *SSEListenForProgramChangesPreferenceKey = @"SSEListenForProgramChanges";
NSString *SSEInterruptOnProgramChangePreferenceKey = @"SSEInterruptOnProgramChange";
NSString *SSEProgramChangeBaseIndexPreferenceKey = @"SSEProgramChangeBaseIndex";
NSString *SSECustomSysexBufferSizePreferenceKey = @"SSECustomSysexBufferSize";

NSString *SSEMIDIControllerReadStatusChangedNotification = @"SSEMIDIControllerReadStatusChangedNotification";
NSString *SSEMIDIControllerReadFinishedNotification = @"SSEMIDIControllerReadFinishedNotification";
NSString *SSEMIDIControllerSendWillStartNotification = @"SSEMIDIControllerSendWillStartNotification";
NSString *SSEMIDIControllerSendFinishedNotification = @"SSEMIDIControllerSendFinishedNotification";
NSString *SSEMIDIControllerSendFinishedImmediatelyNotification = @"SSEMIDIControllerSendFinishedImmediatelyNotification";
NSString *SSEProgramChangeBaseIndexPreferenceChangedNotification = @"SSEProgramChangeBaseIndexChangedNotification";
NSString *SSECustomSysexBufferSizePreferenceChangedNotification = @"SSECustomSysexBufferSizePreferenceChangedNotification";


- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController;
{
    NSNotificationCenter *center;
    BOOL didSetDestinationFromDefaults;
    NSDictionary *destinationSettings;
    
    if (!(self = [super init]))
        return nil;

    midiContext = [(AppController *)[NSApp delegate] midiContext];

    nonretainedMainWindowController = mainWindowController;
    
    center = [NSNotificationCenter defaultCenter];

    inputStream = [[PortInputStream alloc] initWithMidiContext:midiContext];
    [center addObserver:self selector:@selector(readingSysEx:) name:NSNotification.inputStreamReadingSysEx object:inputStream];
    [center addObserver:self selector:@selector(readingSysEx:) name:NSNotification.inputStreamDoneReadingSysEx object:inputStream];
    [inputStream setMessageDestination:self];
    // TODO inputStream.selectedInputSources = Set(inputStream.inputSources)
    [inputStream selectAllInputSources];

    outputStream = [[CombinationOutputStream alloc] initWithMidiContext:midiContext];
//    [center addObserver:self selector:@selector(midiSetupChanged:) name:NSNotification.clientSetupChanged object:[SMClient sharedClient]];
        // use the general setup changed notification rather than SSECombinationOutputStreamDestinationListChangedNotification,
        // since it's too low-level and fires too early when setting up a virtual destination
        // TODO Really? Could we be more specific?
    [center addObserver:self selector:@selector(outputStreamSelectedDestinationDisappeared:) name:NSNotification.portOutputStreamEndpointDisappeared object:outputStream];
    [center addObserver:self selector:@selector(willStartSendingSysEx:) name:NSNotification.portOutputStreamSysExSendWillBegin object:outputStream];
    [center addObserver:self selector:@selector(doneSendingSysEx:) name:NSNotification.portOutputStreamSysExSendDidEnd object:outputStream];
    [center addObserver:self selector:@selector(customSysexBufferSizeChanged:) name:SSECustomSysexBufferSizePreferenceChangedNotification object:nil];
    [outputStream setIgnoresTimeStamps:YES];
    [outputStream setSendsSysExAsynchronously:YES];
    [outputStream setCustomSysExBufferSize:[[NSUserDefaults standardUserDefaults] integerForKey:SSECustomSysexBufferSizePreferenceKey]];
    [outputStream setVirtualDisplayName:NSLocalizedStringFromTableInBundle(@"Act as a source for other programs", @"SysExLibrarian", SMBundleForObject(self), "display name of virtual source")];

    [center addObserver:self selector:@selector(portInputStreamSourceListChanged:) name:NSNotification.inputStreamSourceListChanged object:inputStream];

    messages = [[NSMutableArray alloc] init];
    messageBytesRead = 0;
    totalBytesRead = 0;

    listeningToSysexMessages = NO;
    listenToMultipleSysexMessages = NO;

    [self sendPreferenceDidChange:nil];
    [center addObserver:self selector:@selector(sendPreferenceDidChange:) name:NSNotification.sysExSendPreferenceChanged object:nil];

    [self receivePreferenceDidChange:nil];
    [center addObserver:self selector:@selector(receivePreferenceDidChange:) name:NSNotification.sysExReceivePreferenceChanged object:nil];
    
    listeningToProgramChangeMessages = NO;
    
    [self listenForProgramChangesPreferenceDidChange:nil];
    [center addObserver:self selector:@selector(listenForProgramChangesPreferenceDidChange:) name:NSNotification.listenForProgramChangesPreferenceChanged object:nil];

    didSetDestinationFromDefaults = NO;
    destinationSettings = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SSESelectedDestinationPreferenceKey];
    if (destinationSettings) {
        NSString *missingDestinationName;

        missingDestinationName = [outputStream takePersistentSettings:destinationSettings];
        if (!missingDestinationName)
            didSetDestinationFromDefaults = YES;
    }

    if (!didSetDestinationFromDefaults)
        [self selectFirstAvailableDestination];
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [virtualInputStream setMessageDestination:nil];
	[virtualInputStream release];
	virtualInputStream = nil;
    [inputStream setMessageDestination:nil];
    [inputStream release];
    inputStream = nil;
    [outputStream release];
    outputStream = nil;
    [messages release];
    messages = nil;

    [super dealloc];
}

//
// API for SSEMainWindowController
//

- (NSArray *)destinations;
{
    return [outputStream destinations];
}

- (NSArray *)groupedDestinations;
{
    return [outputStream groupedDestinations];
}

- (id <OutputStreamDestination>)selectedDestination;
{
    return [outputStream selectedDestination];
}

- (void)setSelectedDestination:(id <OutputStreamDestination>)destination;
{
    id <OutputStreamDestination> oldDestination;

    oldDestination = [self selectedDestination];
    if (oldDestination == destination || [oldDestination isEqual:destination])
        return;

    [outputStream setSelectedDestination:destination];

    [nonretainedMainWindowController synchronizeDestinations];

    [[NSUserDefaults standardUserDefaults] setObject:[outputStream persistentSettings] forKey:SSESelectedDestinationPreferenceKey];
}

- (NSArray *)messages;
{
    return messages;
}

- (void)setMessages:(NSArray *)value;
{
    // Shouldn't do this while listening for messages or playing messages
    SMAssert(listeningToSysexMessages == NO);
    SMAssert(nonretainedCurrentSendRequest == nil);
    
    if (value != messages) {
        [messages release];
        messages = [value mutableCopy];
    }
    
    bytesToSend = 0;
    NSUInteger messageIndex, messageCount = [messages count];
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++)
        bytesToSend += [[messages objectAtIndex:messageIndex] fullMessageDataLength];
    
    sendingMessageCount = messageCount;
    
    sendingMessageIndex = 0;
    bytesSent = 0;
}

//
// Listening to sysex messages
//

- (void)listenForOneMessage;
{
    listenToMultipleSysexMessages = NO;
    [self startListening];
}

- (void)listenForMultipleMessages;
{
    listenToMultipleSysexMessages = YES;
    [self startListening];
}

- (void)cancelMessageListen;
{
    listeningToSysexMessages = NO;
    [inputStream cancelReceivingSysExMessage];

    [messages removeAllObjects];
    messageBytesRead = 0;
    totalBytesRead = 0;
}

- (void)doneWithMultipleMessageListen;
{
    listeningToSysexMessages = NO;
    [inputStream cancelReceivingSysExMessage];
}

- (void)getMessageCount:(NSUInteger *)messageCountPtr bytesRead:(NSUInteger *)bytesReadPtr totalBytesRead:(NSUInteger *)totalBytesReadPtr;
{
    SMAssert([NSThread isMainThread]);

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
    SMAssert([NSThread isMainThread]);

    if (!messages || [messages count] == 0)
        return;

    if (![outputStream canSendSysExAsynchronously]) {
        // Just dump all the messages out at once
        [outputStream takeMIDIMessages:messages];
        // And we're done
        bytesSent = bytesToSend;
        sendingMessageIndex = [messages count] - 1;
        [[NSNotificationCenter defaultCenter] postNotificationName:SSEMIDIControllerSendFinishedImmediatelyNotification object:self];
        [self setMessages:nil];
        return;
    }

    nonretainedCurrentSendRequest = nil;
    sendingMessageIndex = 0;
    bytesSent = 0;
    sendStatus = SSEMIDIControllerIdle;

    [[NSNotificationCenter defaultCenter] postNotificationName:SSEMIDIControllerSendWillStartNotification object:self];

    [self sendNextSysExMessage];
}

- (void)cancelSendingMessages;
{
    SMAssert([NSThread isMainThread]);
    
    if (sendStatus == SSEMIDIControllerSending) {
        sendStatus = SSEMIDIControllerCancelled;
        [outputStream cancelPendingSysExSendRequests];
        // We will get notified when the current send request is finished
    } else if (sendStatus == SSEMIDIControllerWillDelayBeforeNext) {
        sendStatus = SSEMIDIControllerCancelled;
        // -sendNextSysExMessageAfterDelay is going to happen in the main thread, but hasn't happened yet.
        // We can't stop it from happening, so let it do the cancellation work when it happens.
    } else if (sendStatus == SSEMIDIControllerDelayingBeforeNext) {
        // -sendNextSysExMessageAfterDelay has scheduled the next -sendNextSysExMessage, but it hasn't happened yet.
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(sendNextSysExMessage) object:nil];
        sendStatus = SSEMIDIControllerFinishing;
        [self finishedSendingMessagesWithSuccess:NO];
    }
}

- (void)getMessageCount:(NSUInteger *)messageCountPtr messageIndex:(NSUInteger *)messageIndexPtr bytesToSend:(NSUInteger *)bytesToSendPtr bytesSent:(NSUInteger *)bytesSentPtr;
{
    SMAssert([NSThread isMainThread]);

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
}


//
// MessageDestination protocol
//

- (void)takeMIDIMessages:(NSArray<Message *> *)messagesToTake
{
    NSUInteger messageCount, messageIndex;
        
    messageCount = [messagesToTake count];
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        Message *message = [messagesToTake objectAtIndex:messageIndex];
        
        if (listeningToSysexMessages && [message isKindOfClass:[SystemExclusiveMessage class]]) {
            [messages addObject:message];
            totalBytesRead += messageBytesRead;
            messageBytesRead = 0;
            
            [self updateSysExReadIndicator];
            if (listenToMultipleSysexMessages == NO)  {
                listeningToSysexMessages = NO;
                
                [[NSNotificationCenter defaultCenter] postNotificationName:SSEMIDIControllerReadFinishedNotification object:self];
                break;
            }
        }
        else if (listeningToProgramChangeMessages && 
                 [message originatingEndpoint] == [virtualInputStream endpoint] &&
                 [message isKindOfClass:[VoiceMessage class]] &&
                 [(VoiceMessage*)message status] == 0xC0 /* TODO VoiceMessage.Status.program*/) {
            Byte program = [(VoiceMessage*)message dataByte1];
            [nonretainedMainWindowController playEntryWithProgramNumber:program];
        }
    }
}

@end


@implementation SSEMIDIController (Private)

- (void)sendPreferenceDidChange:(NSNotification *)notification;
{
    pauseTimeBetweenMessages = (double)[[NSUserDefaults standardUserDefaults] integerForKey:SSESysExIntervalBetweenSentMessagesPreferenceKey] / 1000.0;
}

- (void)receivePreferenceDidChange:(NSNotification *)notification;
{
    double sysExReadTimeOut;

    sysExReadTimeOut = (double)[[NSUserDefaults standardUserDefaults] integerForKey:SSESysExReadTimeOutPreferenceKey] / 1000.0;
    [inputStream setSysExTimeOut:sysExReadTimeOut];
}

- (void)listenForProgramChangesPreferenceDidChange:(NSNotification*)n
{
    listeningToProgramChangeMessages = [[NSUserDefaults standardUserDefaults] boolForKey:SSEListenForProgramChangesPreferenceKey];
    
    if (listeningToProgramChangeMessages) {
        if (!virtualInputStream) {
            virtualInputStream = [[VirtualInputStream alloc] initWithMidiContext:midiContext];
            [virtualInputStream setMessageDestination:self];

            // TODO Can't do this from ObjC
            // [virtualInputStream setSelectedInputSources:[virtualInputStream inputSourcesSet]];
            [virtualInputStream selectAllInputSources];
        }
    } else {
        if (virtualInputStream) {
            [virtualInputStream setMessageDestination:nil];
            [virtualInputStream release];
            virtualInputStream = nil;
        }
    }
}

- (void)portInputStreamSourceListChanged:(NSNotification *)notification;
{
    // TODO Like this
    // inputStream.selectedInputSources = Set(inputStream.inputSources)
    [inputStream selectAllInputSources];
}

- (void)midiSetupChanged:(NSNotification *)notification;
{
    // TODO This may now come in too early; try to be more specific
    [nonretainedMainWindowController synchronizeDestinations];
}

- (void)outputStreamSelectedDestinationDisappeared:(NSNotification *)notification;
{
    if (sendStatus == SSEMIDIControllerSending ||
        sendStatus == SSEMIDIControllerWillDelayBeforeNext ||
        sendStatus == SSEMIDIControllerDelayingBeforeNext) {
        [self cancelSendingMessages];
    }

    [self selectFirstAvailableDestinationWhenPossible];
}

- (void)selectFirstAvailableDestinationWhenPossible;
{
    // NOTE: We may be handling a MIDI change notification right now. We might want to select a virtual source
    // but a virtual stream can't be created in the middle of handling this notification, so do it later.
    // NOTE This applied to 10.1; the situation is probably less goofy under 10.2.

    // TODO Is this really necessary anymore?
//    if ([[SMClient sharedClient] isHandlingSetupChange]) {
//        [self performSelector:_cmd withObject:nil afterDelay:0.1];
//        // NOTE Delay longer than 0 is a tradeoff; it means there's a brief window when no destination will be selected.
//        // A delay of 0 means that we'll get called many times (about 20 in practice) before the setup change is finished.
//    } else {
        [self selectFirstAvailableDestination];
//    }
}

- (void)selectFirstAvailableDestination;
{
    NSArray *destinations;

    destinations = [outputStream destinations];
    if ([destinations count] > 0)
        [self setSelectedDestination:[destinations objectAtIndex:0]];
}


//
// Listening to sysex messages
//

- (void)startListening;
{
    SMAssert(listeningToSysexMessages == NO);
    
    [inputStream cancelReceivingSysExMessage];
        // In case a sysex message is currently being received

    [self setMessages:[NSMutableArray array]];
    messageBytesRead = 0;
    totalBytesRead = 0;

    listeningToSysexMessages = YES;
}

- (void)readingSysEx:(NSNotification *)notification;
{
    messageBytesRead = [[[notification userInfo] objectForKey:@"length"] unsignedIntValue];

    // We want multiple updates to get coalesced, so only do this once
    if (!scheduledUpdateSysExReadIndicator) {
        [self performSelectorOnMainThread:@selector(updateSysExReadIndicator) withObject:nil waitUntilDone:NO];
        scheduledUpdateSysExReadIndicator = YES;
    }
}

- (void)updateSysExReadIndicator;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SSEMIDIControllerReadStatusChangedNotification object:self];
    scheduledUpdateSysExReadIndicator = NO;
}


//
// Sending sysex messages
//

#if LOG_PAUSE_DURATION
static MIDITimeStamp pauseStartTimeStamp = 0;
#endif

- (void)sendNextSysExMessage;
{
    SMAssert([NSThread isMainThread]);

#if LOG_PAUSE_DURATION
    if (pauseStartTimeStamp > 0) {
        UInt64 realPauseDuration;

        realPauseDuration = AudioGetCurrentHostTime() - pauseStartTimeStamp;
        NSLog(@"pause took %f ms", (double)AudioConvertHostTimeToNanos(realPauseDuration) / 1.0e6);
    }
#endif
    
    sendStatus = SSEMIDIControllerSending;
    
    [outputStream takeMIDIMessages:[NSArray arrayWithObject:[messages objectAtIndex:sendingMessageIndex]]];
}

- (void)sendNextSysExMessageAfterDelay
{
    SMAssert([NSThread isMainThread]);

    if (sendStatus == SSEMIDIControllerWillDelayBeforeNext) {
        // wait for pauseTimeBetweenMessages, then sendNextSysExMessage
        sendStatus = SSEMIDIControllerDelayingBeforeNext;
        [self performSelector:@selector(sendNextSysExMessage) withObject:nil afterDelay:pauseTimeBetweenMessages];        
    } else if (sendStatus == SSEMIDIControllerCancelled) {
        // The user cancelled before we got here, so finish the cancellation now
        sendStatus = SSEMIDIControllerFinishing;
        [self finishedSendingMessagesWithSuccess:NO];
    }
}

- (void)willStartSendingSysEx:(NSNotification *)notification;
{    
    SMAssert(nonretainedCurrentSendRequest == nil);
    nonretainedCurrentSendRequest = [[notification userInfo] objectForKey:@"sendRequest"];
}

- (void)doneSendingSysEx:(NSNotification *)notification;
{
    // NOTE: The request may or may not have finished successfully.

    SMAssert([NSThread isMainThread]);

    SysExSendRequest *sendRequest;

    sendRequest = [[notification userInfo] objectForKey:@"sendRequest"];
    SMAssert(sendRequest == nonretainedCurrentSendRequest);

    bytesSent += [sendRequest bytesSent];
    sendingMessageIndex++;
    nonretainedCurrentSendRequest = nil;
    
#if LOG_PAUSE_DURATION
    pauseStartTimeStamp = 0;
#endif
    
    if (sendStatus == SSEMIDIControllerCancelled) {
        sendStatus = SSEMIDIControllerFinishing;
        [self finishedSendingMessagesWithSuccess:NO];
    } else if (sendingMessageIndex < sendingMessageCount && [sendRequest wereAllBytesSent]) {
#if LOG_PAUSE_DURATION
        pauseStartTimeStamp = AudioGetCurrentHostTime();
#endif
        sendStatus = SSEMIDIControllerWillDelayBeforeNext;
        [self sendNextSysExMessageAfterDelay];
    } else {
        sendStatus = SSEMIDIControllerFinishing;
        [self finishedSendingMessagesWithSuccess:[sendRequest wereAllBytesSent]];
    }
}

- (void)finishedSendingMessagesWithSuccess:(BOOL)success;
{
    SMAssert([NSThread isMainThread]);

    [[NSNotificationCenter defaultCenter] postNotificationName:SSEMIDIControllerSendFinishedNotification object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:success] forKey:@"success"]];

    // Now we are done with the messages and can get rid of them
    [self setMessages:nil];
    
    sendStatus = SSEMIDIControllerIdle;
}

- (void)customSysexBufferSizeChanged:(NSNotification *)notification
{
    [outputStream setCustomSysExBufferSize:[[NSUserDefaults standardUserDefaults] integerForKey:SSECustomSysexBufferSizePreferenceKey]];
}

@end
