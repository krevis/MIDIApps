//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMPortOrVirtualStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMPortInputStream.h"		// For declaration of -endpoint -- could be output stream too, doesn't matter


@interface SMPortOrVirtualStream (Private)

- (void)_createPortStream;
- (void)_removePortStream;
- (void)_createVirtualStream;
- (void)_removeVirtualStream;

- (NSDictionary *)_descriptionForVirtual;
- (NSDictionary *)_descriptionForEndpoint:(SMEndpoint *)endpoint;

- (SMEndpoint *)_endpointWithName:(NSString *)name;

- (void)_selectEndpoint:(SMEndpoint *)endpoint;

@end


@implementation SMPortOrVirtualStream

DEFINE_NSSTRING(SMPortOrVirtualStreamEndpointDisappearedNotification);


- (id)init;
{
    if (!(self = [super init]))
        return nil;

    virtualEndpointName = [[[SMClient sharedClient] name] copy];
    virtualDisplayName = [virtualEndpointName copy];

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

- (NSArray *)endpointDescriptions;
{
    NSArray *endpoints;
    unsigned int endpointIndex, endpointCount;
    NSMutableArray *descriptions;

    endpoints = [self allEndpoints];
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

- (NSDictionary *)endpointDescription;
{
    if (virtualStream)
        return [self _descriptionForVirtual];
    else if (portStream)
        return [self _descriptionForEndpoint:[portStream endpoint]];
    else
        return nil;
}

- (void)setEndpointDescription:(NSDictionary *)description;
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
        return [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:[[virtualStream endpoint] uniqueID]] forKey:@"virtualEndpointUniqueID"];
    }

    return nil;
}

- (NSString *)takePersistentSettings:(NSDictionary *)settings;
{
    NSNumber *number;

    if ((number = [settings objectForKey:@"portEndpointUniqueID"])) {
        SMEndpoint *endpoint;

        endpoint = [self endpointWithUniqueID:[number intValue]];
        if (endpoint) {
            [self _selectEndpoint:endpoint];
        } else {
            NSString *endpointName;
        
            endpointName = [settings objectForKey:@"portEndpointName"];
            if (endpointName) {
                // Maybe an endpoint with this name still exists, but with a different unique ID.
                endpoint = [self _endpointWithName:endpointName];
                if (endpoint)
                    [self _selectEndpoint:endpoint];
                else
                    return endpointName;
            } else {
                return NSLocalizedStringFromTableInBundle(@"Unknown", @"MIDIMonitor", [self bundle], "name of missing endpoint if not specified in document");
            }
        }
    } else if ((number = [settings objectForKey:@"virtualEndpointUniqueID"])) {
        [self _removeVirtualStream];
        virtualEndpointUniqueID = [number intValue];
        [self _selectEndpoint:nil];
    }

    return nil;
}

- (id)stream;
{
    if (virtualStream)
        return virtualStream;
    else
        return portStream;
}

//
// To be implemented in subclasses
//

- (NSArray *)allEndpoints;
{
    // Implement in subclasses
    // e.g. [SMSourceEndpoint sourceEndpoints]
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (SMEndpoint *)endpointWithUniqueID:(int)uniqueID;
{
    // Implement in subclasses
    // e.g. [SMSourceEndpoint sourceEndpointWithUniqueID:uniqueID];
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)newPortStream;
{
    // Implement in subclasses
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void)willRemovePortStream;
{
    // Do nothing -- subclasses may override if necessary    
}

- (id)newVirtualStream;
{
    // Implement in subclasses
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void)willRemoveVirtualStream;
{
    // Do nothing -- subclasses may override if necessary    
}

//
// To be used by subclasses only
//

- (void)portStreamEndpointDisappeared:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMPortOrVirtualStreamEndpointDisappearedNotification object:self];
}

@end


@implementation SMPortOrVirtualStream (Private)

- (void)_createPortStream;
{
    OBASSERT(portStream == nil);

    portStream = [[self newPortStream] retain];
}

- (void)_removePortStream;
{
    if (portStream) {
        [self willRemovePortStream];

        [portStream release];
        portStream = nil;
    }
}

- (void)_createVirtualStream;
{
    OBASSERT(virtualStream == nil);

    virtualStream = [[self newVirtualStream] retain];
}

- (void)_removeVirtualStream;
{
    if (virtualStream) {
        [self willRemoveVirtualStream];

        [virtualStream release];
        virtualStream = nil;
    }
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

- (SMEndpoint *)_endpointWithName:(NSString *)name;
{
    NSArray *allEndpoints;
    unsigned int endpointIndex;

    allEndpoints = [self allEndpoints];
    endpointIndex = [allEndpoints count];
    while (endpointIndex--) {
        SMEndpoint *endpoint;

        endpoint = [allEndpoints objectAtIndex:endpointIndex];
        if ([[endpoint name] isEqualToString:name])
            return endpoint;
    }

    return nil;
}
 
- (void)_selectEndpoint:(SMEndpoint *)endpoint;
{
    if (endpoint) {
        // Set up the port stream
        if (!portStream)
            [self _createPortStream];
        [portStream setEndpoint:(id)endpoint];
    
        [self _removeVirtualStream];
    } else {
        // Set up the virtual stream
        if (!virtualStream)
            [self _createVirtualStream];
    
        [self _removePortStream];
    }
} 

@end
