//
//  SMPortOrVirtualInputStream.m
//  SnoizeMIDI
//
//  Created by krevis on Fri Dec 07 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMPortOrVirtualInputStream.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMEndpoint.h"
#import "SMPortInputStream.h"
#import "SMVirtualInputStream.h"


@interface SMPortOrVirtualInputStream (Private)

- (SMInputStream *)_stream;

- (NSDictionary *)_descriptionForVirtual;
- (NSDictionary *)_descriptionForEndpoint:(SMEndpoint *)endpoint;

- (void)_selectEndpoint:(SMSourceEndpoint *)endpoint;

- (void)_createPortStream;
- (void)_removePortStream;

- (void)_createVirtualStream;
- (void)_removeVirtualStream;

- (void)_observeSysExNotificationsFromStream:(SMInputStream *)stream;
- (void)_stopObservingSysExNotificationsFromStream:(SMInputStream *)stream;
- (void)_sysExNotification:(NSNotification *)notification;

@end


@implementation SMPortOrVirtualInputStream

DEFINE_NSSTRING(SMPortOrVirtualInputStreamEndpointWasRemoved);


- (id)init;
{
    if (!(self = [super init]))
        return nil;

    virtualEndpointName = @"";
    virtualDisplayName = @"";

    // We will always keep the same unique ID for our virtual destination,
    // even if we create and destroy it multiple times.
    virtualEndpointUniqueID = [SMEndpoint generateNewUniqueID];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [portStream release];
    portStream = nil;
    [virtualStream release];
    virtualStream = nil;
    [virtualEndpointName release];
    virtualEndpointName = nil;
    [virtualDisplayName release];
    virtualDisplayName = nil;

    [super dealloc];
}

- (id<SMMessageDestination>)messageDestination;
{
    return nonretainedMessageDestination;
}

- (void)setMessageDestination:(id<SMMessageDestination>)messageDestination;
{
    nonretainedMessageDestination = messageDestination;    
    [[self _stream] setMessageDestination:messageDestination];
}

- (NSArray *)sourceDescriptions;
{
    NSArray *endpoints;
    unsigned int endpointIndex, endpointCount;
    NSMutableArray *descriptions;

    endpoints = [SMSourceEndpoint sourceEndpoints];
    endpointCount = [endpoints count];
    descriptions = [NSMutableArray arrayWithCapacity:endpointCount + 1];
    
    for (endpointIndex = 0; endpointIndex < endpointCount; endpointIndex++) {
        SMEndpoint *endpoint;
        
        endpoint = [endpoints objectAtIndex:endpointIndex];
        if (![endpoint isOwnedByThisProcess])
            [descriptions addObject:[self _descriptionForEndpoint:endpoint]];
    }

    [descriptions addObject:[self _descriptionForVirtual]];
    
    return descriptions;
}

- (NSDictionary *)sourceDescription;
{
    if (virtualStream)
        return [self _descriptionForVirtual];
    else if (portStream)
        return [self _descriptionForEndpoint:[portStream endpoint]];
    else
        return nil;
}

- (void)setSourceDescription:(NSDictionary *)description;
{
    if (description) {
        [self _selectEndpoint:[description objectForKey:@"endpoint"]];
    } else {
        [self _removePortStream];
        [self _removeVirtualStream];
    }
}

- (NSString *)virtualEndpointName;
{
    return virtualEndpointName;
}

- (void)setVirtualEndpointName:(NSString *)newName;
{
    if (virtualEndpointName == newName || [virtualEndpointName isEqualToString:newName])
        return;
        
    [virtualEndpointName release];
    virtualEndpointName = [newName retain];
    
    [[virtualStream endpoint] setName:virtualEndpointName];
}

- (NSString *)virtualDisplayName;
{
    return virtualDisplayName;
}

- (void)setVirtualDisplayName:(NSString *)newName;
{
    if (virtualDisplayName == newName)
        return;
        
    [virtualDisplayName release];
    virtualDisplayName = [newName retain];
}

- (NSDictionary *)persistentSettings;
{
    if (portStream) {
        SMEndpoint *endpoint;
        
        if ((endpoint = [portStream endpoint])) {
            NSMutableDictionary *dict;
            NSString *name;
        
            dict = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:[endpoint uniqueID]] forKey:@"portEndpointUniqueID"];
            if ((name = [endpoint name])) {
                [dict setObject:name forKey:@"portEndpointName"];
            }
            
            return dict;
        }
    } else if (virtualStream) {
        return [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:virtualEndpointUniqueID] forKey:@"virtualEndpointUniqueID"];
    }

    return nil;
}

- (NSString *)takePersistentSettings:(NSDictionary *)settings;
{
    NSNumber *number;

    if ((number = [settings objectForKey:@"portEndpointUniqueID"])) {
        SMSourceEndpoint *endpoint;
        
        endpoint = [SMSourceEndpoint sourceEndpointWithUniqueID:[number intValue]];
        if (endpoint) {
            [self _selectEndpoint:endpoint];
        } else {
            NSString *endpointName;
        
            endpointName = [settings objectForKey:@"portEndpointName"];
            if (!endpointName) {
                endpointName = NSLocalizedStringFromTableInBundle(@"Unknown", @"MIDIMonitor", [self bundle], "name of missing endpoint if not specified in document");
            }

            return endpointName;
        }
    } else if ((number = [settings objectForKey:@"virtualEndpointUniqueID"])) {
        [self _removeVirtualStream];
        virtualEndpointUniqueID = [number intValue];
        [self _selectEndpoint:nil];
    }

    return nil;
}

@end


@implementation SMPortOrVirtualInputStream (Private)

- (SMInputStream *)_stream;
{
    if (virtualStream)
        return virtualStream;
    else
        return portStream;
}

- (NSDictionary *)_descriptionForVirtual;
{
    return [NSDictionary dictionaryWithObject:virtualDisplayName forKey:@"name"];
}

- (NSDictionary *)_descriptionForEndpoint:(SMEndpoint *)endpoint;
{
    if (endpoint)
        return [NSDictionary dictionaryWithObjectsAndKeys:endpoint, @"endpoint", [endpoint shortName], @"name", nil];
    else
        return nil;
}
 
- (void)_selectEndpoint:(SMSourceEndpoint *)endpoint;
{
    if (endpoint) {
        // Set up the port stream
        if (!portStream)
            [self _createPortStream];
        [portStream setEndpoint:endpoint];
    
        [self _removeVirtualStream];
    } else {
        // Set up the virtual stream
        if (!virtualStream)
            [self _createVirtualStream];
    
        [self _removePortStream];
    }
} 

- (void)_createPortStream;
{
    OBASSERT(portStream == nil);

    portStream = [[SMPortInputStream alloc] init];
    [portStream setMessageDestination:nonretainedMessageDestination];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_portStreamEndpointWasRemoved:) name:SMPortInputStreamEndpointWasRemoved object:portStream];
    [self _observeSysExNotificationsFromStream:portStream];
}

- (void)_removePortStream;
{
    if (portStream) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:SMPortInputStreamEndpointWasRemoved object:portStream];
        [self _stopObservingSysExNotificationsFromStream:portStream];
        [portStream release];
        portStream = nil;
    }
}

- (void)_createVirtualStream;
{
    OBASSERT(virtualStream == nil);

    virtualStream = [[SMVirtualInputStream alloc] initWithName:virtualEndpointName uniqueID:virtualEndpointUniqueID];
    [virtualStream setMessageDestination:nonretainedMessageDestination];
    [self _observeSysExNotificationsFromStream:virtualStream];
}

- (void)_removeVirtualStream;
{
    if (virtualStream) {
        [self _stopObservingSysExNotificationsFromStream:virtualStream];
        [virtualStream release];
        virtualStream = nil;
    }
}

- (void)_portStreamEndpointWasRemoved:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMPortOrVirtualInputStreamEndpointWasRemoved object:self];
}

- (void)_observeSysExNotificationsFromStream:(SMInputStream *)stream;
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_sysExNotification:) name:SMInputStreamReadingSysExNotification object:stream];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_sysExNotification:) name:SMInputStreamDoneReadingSysExNotification object:stream];
}

- (void)_stopObservingSysExNotificationsFromStream:(SMInputStream *)stream;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SMInputStreamReadingSysExNotification object:stream];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SMInputStreamDoneReadingSysExNotification object:stream];
}

- (void)_sysExNotification:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:[notification name] object:self userInfo:[notification userInfo]];
}

@end
