//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMPortOrVirtualInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMEndpoint.h"
#import "SMPortInputStream.h"
#import "SMVirtualInputStream.h"


@interface SMPortOrVirtualInputStream (Private)

- (void)_observeSysExNotificationsFromStream:(SMInputStream *)stream;
- (void)_stopObservingSysExNotificationsFromStream:(SMInputStream *)stream;

- (void)_repostNotification:(NSNotification *)notification;

@end


@implementation SMPortOrVirtualInputStream

- (id<SMMessageDestination>)messageDestination;
{
    return nonretainedMessageDestination;
}

- (void)setMessageDestination:(id<SMMessageDestination>)messageDestination;
{
    nonretainedMessageDestination = messageDestination;    
    [[self stream] setMessageDestination:messageDestination];
}

- (BOOL)cancelReceivingSysExMessage;
{
    return [[self stream] cancelReceivingSysExMessage];
}

//
// SMPortOrVirtualStream subclass methods
//

- (NSArray *)allEndpoints;
{
    return [SMSourceEndpoint sourceEndpoints];
}

- (SMEndpoint *)endpointWithUniqueID:(int)uniqueID;
{
    return [SMSourceEndpoint sourceEndpointWithUniqueID:uniqueID];
}

- (id)newPortStream;
{
    SMPortInputStream *stream;
    
    stream = [[SMPortInputStream alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(portStreamEndpointDisappeared:) name:SMPortInputStreamEndpointDisappeared object:stream];
    [stream setMessageDestination:nonretainedMessageDestination];
    [self _observeSysExNotificationsFromStream:stream];

    return [stream autorelease];
}

- (void)willRemovePortStream;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SMPortInputStreamEndpointDisappeared object:portStream];        
    [self _stopObservingSysExNotificationsFromStream:portStream];
}

- (id)newVirtualStream;
{
    SMVirtualInputStream *stream;

    stream = [[SMVirtualInputStream alloc] initWithName:virtualEndpointName uniqueID:virtualEndpointUniqueID];
    [stream setMessageDestination:nonretainedMessageDestination];
    [self _observeSysExNotificationsFromStream:stream];

    return [stream autorelease];
}

- (void)willRemoveVirtualStream;
{
    [self _stopObservingSysExNotificationsFromStream:virtualStream];
}

@end


@implementation SMPortOrVirtualInputStream (Private)

- (void)_observeSysExNotificationsFromStream:(SMInputStream *)stream;
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_repostNotification:) name:SMInputStreamReadingSysExNotification object:stream];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_repostNotification:) name:SMInputStreamDoneReadingSysExNotification object:stream];
}

- (void)_stopObservingSysExNotificationsFromStream:(SMInputStream *)stream;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SMInputStreamReadingSysExNotification object:stream];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SMInputStreamDoneReadingSysExNotification object:stream];
}

- (void)_repostNotification:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:[notification name] object:self userInfo:[notification userInfo]];
}

@end
