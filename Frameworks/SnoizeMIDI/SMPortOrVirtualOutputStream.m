//
//  SMPortOrVirtualOutputStream.m
//  SnoizeMIDI
//
//  Created by krevis on Fri Dec 07 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMPortOrVirtualOutputStream.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMEndpoint.h"
#import "SMPortOutputStream.h"
#import "SMVirtualOutputStream.h"


@implementation SMPortOrVirtualOutputStream

//
// SMPortOrVirtualStream subclass methods
//

- (NSArray *)allEndpoints;
{
    return [SMDestinationEndpoint destinationEndpoints];
}

- (SMEndpoint *)endpointWithUniqueID:(int)uniqueID;
{
    return [SMDestinationEndpoint destinationEndpointWithUniqueID:uniqueID];
}

- (id)newPortStream;
{
    SMPortOutputStream *stream;

    stream = [[SMPortOutputStream alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(portStreamEndpointWasRemoved:) name:SMPortOutputStreamEndpointWasRemoved object:stream];

    return [stream autorelease];
}

- (void)willRemovePortStream;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SMPortOutputStreamEndpointWasRemoved object:portStream];
}

- (id)newVirtualStream;
{
    SMVirtualOutputStream *stream;

    stream = [[SMVirtualOutputStream alloc] initWithName:virtualEndpointName uniqueID:virtualEndpointUniqueID];

    return [stream autorelease];
}

- (void)willRemoveVirtualStream;
{
    // Nothing is necessary
}

//
// SMMessageDestination protocol
//

- (void)takeMIDIMessages:(NSArray *)messages;
{
    [[self stream] takeMIDIMessages:messages];
}

@end
