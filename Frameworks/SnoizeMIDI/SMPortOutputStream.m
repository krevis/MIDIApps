#import "SMPortOutputStream.h"

#import <CoreAudio/CoreAudio.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMMessage.h"
#import "SMSystemExclusiveMessage.h"
#import "SMSysExSendRequest.h"


@interface SMPortOutputStream (Private)

- (void)_endpointWasRemoved:(NSNotification *)notification;
- (void)_endpointWasReplaced:(NSNotification *)notification;

- (void)_splitMessages:(NSArray *)messages intoCurrentSysex:(NSArray **)sysExMessagesPtr andNormal:(NSArray **)normalMessagesPtr;

- (void)_sendSysExMessagesAsynchronously:(NSArray *)sysExMessages;
- (void)_sysExSendRequestFinished:(NSNotification *)notification;

@end


@implementation SMPortOutputStream

DEFINE_NSSTRING(SMPortOutputStreamEndpointWasRemovedNotification);
DEFINE_NSSTRING(SMPortOutputStreamWillStartSysExSendNotification);
DEFINE_NSSTRING(SMPortOutputStreamFinishedSysExSendNotification);


- (id)init;
{
    OSStatus status;

    if (!(self = [super init]))
        return nil;

    portFlags.sendsSysExAsynchronously = NO;

    sysExSendRequests = [[NSMutableArray alloc] init];

    status = MIDIOutputPortCreate([[SMClient sharedClient] midiClient], (CFStringRef)@"Output port",  &outputPort);
    if (status != noErr) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't create a MIDI output port (error %ld)", @"SnoizeMIDI", [self bundle], "exception with OSStatus if MIDIOutputPortCreate() fails"), status];
    }

    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    MIDIPortDispose(outputPort);
    outputPort = NULL;

    [self setEndpoint:nil];

    [sysExSendRequests release];
    sysExSendRequests = nil;    
    
    [super dealloc];
}

- (SMDestinationEndpoint *)endpoint;
{
    return endpoint;
}

- (void)setEndpoint:(SMDestinationEndpoint *)newEndpoint;
{
    NSNotificationCenter *center;

    if (endpoint == newEndpoint)
        return;

    center = [NSNotificationCenter defaultCenter];

    if (endpoint) {
        [center removeObserver:self name:SMEndpointWasRemovedNotification object:endpoint];
        [center removeObserver:self name:SMEndpointWasReplacedNotification object:endpoint];
    }
    
    [endpoint release];
    endpoint = [newEndpoint retain];
    
    if (endpoint) {
        [center addObserver:self selector:@selector(_endpointWasRemoved:) name:SMEndpointWasRemovedNotification object:endpoint];
        [center addObserver:self selector:@selector(_endpointWasReplaced:) name:SMEndpointWasReplacedNotification object:endpoint];
    }
}

- (BOOL)sendsSysExAsynchronously;
{
    return portFlags.sendsSysExAsynchronously;
}

- (void)setSendsSysExAsynchronously:(BOOL)value;
{
    portFlags.sendsSysExAsynchronously = value;
}

- (void)cancelPendingSysExSendRequests;
{
    [sysExSendRequests makeObjectsPerformSelector:@selector(cancel)];
}

//
// SMOutputStream overrides
//

- (void)takeMIDIMessages:(NSArray *)messages;
{
    if ([self sendsSysExAsynchronously]) {
        NSArray *sysExMessages, *normalMessages;

        // Find the messages which are sysex and which have timestamps which are <= now,
        // and send them using MIDISendSysex(). Other messages get sent normally.

        [self _splitMessages:messages intoCurrentSysex:&sysExMessages andNormal:&normalMessages];

        [self _sendSysExMessagesAsynchronously:sysExMessages];
        [super takeMIDIMessages:normalMessages];
    } else {
        [super takeMIDIMessages:messages];
    }
}

//
// SMOutputStream subclass-implementation methods
//

- (void)sendMIDIPacketList:(MIDIPacketList *)packetList;
{
    MIDIEndpointRef endpointRef;
    OSStatus status;

    if (!(endpointRef = [endpoint endpointRef]))
        return;

    status = MIDISend(outputPort, endpointRef, packetList);
    if (status) {
        NSLog(@"MIDISend(%p, %p, %p) returned error: %ld", outputPort, endpointRef, packetList, status);
    }
}

@end


@implementation SMPortOutputStream (Private)

- (void)_endpointWasRemoved:(NSNotification *)notification;
{
    OBASSERT([notification object] == endpoint);

    [self setEndpoint:nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SMPortOutputStreamEndpointWasRemovedNotification object:self];
}

- (void)_endpointWasReplaced:(NSNotification *)notification;
{
    SMDestinationEndpoint *newEndpoint;

    OBASSERT([notification object] == endpoint);

    newEndpoint = [[notification userInfo] objectForKey:SMEndpointReplacement];
    [self setEndpoint:newEndpoint];
}

- (void)_splitMessages:(NSArray *)messages intoCurrentSysex:(NSArray **)sysExMessagesPtr andNormal:(NSArray **)normalMessagesPtr;
{
    unsigned int messageIndex, messageCount;
    NSMutableArray *sysExMessages = nil;
    NSMutableArray *normalMessages = nil;
    MIDITimeStamp now;

    now = AudioGetCurrentHostTime();

    messageCount = [messages count];
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMMessage *message;
        NSMutableArray **theArray;

        message = [messages objectAtIndex:messageIndex];
        if ([message isKindOfClass:[SMSystemExclusiveMessage class]] && [message timeStamp] <= now)
            theArray = &sysExMessages;
        else
            theArray = &normalMessages;

        if (*theArray == nil)
            *theArray = [NSMutableArray array];
        [*theArray addObject:message];
    }

    if (sysExMessagesPtr)
        *sysExMessagesPtr = sysExMessages;
    if (normalMessagesPtr)
        *normalMessagesPtr = normalMessages;
}

- (void)_sendSysExMessagesAsynchronously:(NSArray *)messages;
{
    MIDIEndpointRef endpointRef;
    unsigned int messageCount, messageIndex;

    if (!(endpointRef = [[self endpoint] endpointRef]))
        return;

    messageCount = [messages count];
    for (messageIndex = 0; messageIndex < messageCount; messageIndex++) {
        SMSystemExclusiveMessage *message;
        SMSysExSendRequest *sendRequest;

        message = [messages objectAtIndex:messageIndex];
        sendRequest = [SMSysExSendRequest sysExSendRequestWithMessage:message endpoint:[self endpoint]];
        [sysExSendRequests addObject:sendRequest];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_sysExSendRequestFinished:) name:SMSysExSendRequestFinishedNotification object:sendRequest];

        [[NSNotificationCenter defaultCenter] postNotificationName:SMPortOutputStreamWillStartSysExSendNotification object:self userInfo:[NSDictionary dictionaryWithObject:sendRequest forKey:@"sendRequest"]];

        [sendRequest send];
    }
}

- (void)_sysExSendRequestFinished:(NSNotification *)notification;
{
    SMSysExSendRequest *sendRequest;

    sendRequest = [notification object];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:sendRequest];

    [[NSNotificationCenter defaultCenter] postNotificationName:SMPortOutputStreamFinishedSysExSendNotification object:self userInfo:[NSDictionary dictionaryWithObject:sendRequest forKey:@"sendRequest"]];
    
    [sysExSendRequests removeObjectIdenticalTo:sendRequest];
}

@end
