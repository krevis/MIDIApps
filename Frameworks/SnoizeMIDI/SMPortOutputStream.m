#import "SMPortOutputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMEndpoint.h"


@interface SMPortOutputStream (Private)

- (void)_endpointWasRemoved:(NSNotification *)notification;
- (void)_endpointWasReplaced:(NSNotification *)notification;

@end


@implementation SMPortOutputStream

DEFINE_NSSTRING(SMPortOutputStreamEndpointWasRemoved);


- (id)init;
{
    OSStatus status;

    if (!(self = [super init]))
        return nil;

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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SMPortOutputStreamEndpointWasRemoved object:self];
}

- (void)_endpointWasReplaced:(NSNotification *)notification;
{
    SMDestinationEndpoint *newEndpoint;

    OBASSERT([notification object] == endpoint);

    newEndpoint = [[notification userInfo] objectForKey:SMEndpointReplacement];
    [self setEndpoint:newEndpoint];
}

@end
