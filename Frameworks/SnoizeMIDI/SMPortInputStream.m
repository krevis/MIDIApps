//
//  SMPortInputStream.m
//  SnoizeMIDI
//
//  Created by krevis on Wed Nov 28 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMPortInputStream.h"

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMEndpoint.h"


@interface SMPortInputStream (Private)

- (void)_setEndpoint:(SMSourceEndpoint *)newEndpoint;

- (void)_endpointWasRemoved:(NSNotification *)notification;
- (void)_endpointWasReplaced:(NSNotification *)notification;

@end


@implementation SMPortInputStream

DEFINE_NSSTRING(SMPortInputStreamEndpointWasRemoved);


- (id)init;
{
    OSStatus status;

    if (!(self = [super init]))
        return nil;

    status = MIDIInputPortCreate([[SMClient sharedClient] midiClient], (CFStringRef)@"Input port", [self midiReadProc], self, &inputPort);
    if (status != noErr)
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't create a MIDI input port (error %ld)", @"SnoizeMIDI", [self bundle], "exception with OSStatus if MIDIInputPortCreate() fails"), status];

    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    MIDIPortDispose(inputPort);
    inputPort = NULL;

    [self _setEndpoint:nil];

    [super dealloc];
}

- (SMSourceEndpoint *)endpoint;
{
    return endpoint;
}

- (void)setEndpoint:(SMSourceEndpoint *)newEndpoint;
{
    OSStatus status;

    if (newEndpoint == endpoint)
        return;

    if (endpoint) {
        status = MIDIPortDisconnectSource(inputPort, [endpoint endpointRef]);
        if (status != noErr) {
            // This can happen in normal circumstances (if the sourceEndpoint has disappeared on us)
            // so don't log a message and try to go on.
        }
    }

    [self _setEndpoint:newEndpoint];
    if (endpoint) {
        status = MIDIPortConnectSource(inputPort, [endpoint endpointRef], NULL);
        if (status != noErr) {
            NSLog(@"Error from MIDIPortConnectSource: %d", status);
            [self _setEndpoint:nil];
        }
    }
}

@end


@implementation SMPortInputStream (Private)

- (void)_setEndpoint:(SMSourceEndpoint *)newEndpoint
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

- (void)_endpointWasRemoved:(NSNotification *)notification;
{
    OBASSERT([notification object] == endpoint);

    [self _setEndpoint:nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SMPortInputStreamEndpointWasRemoved object:self];
}

- (void)_endpointWasReplaced:(NSNotification *)notification;
{
    SMSourceEndpoint *newEndpoint;

    OBASSERT([notification object] == endpoint);

    newEndpoint = [[notification userInfo] objectForKey:SMEndpointReplacement];
    [self setEndpoint:newEndpoint];
}

@end
