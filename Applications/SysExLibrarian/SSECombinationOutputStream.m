//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SSECombinationOutputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import "SMDestinationEndpoint-SSEOutputStreamDestination.h"


@interface SSECombinationOutputStream (Private)

- (void)selectEndpoint:(SMDestinationEndpoint *)endpoint;

- (void)createPortStream;
- (void)removePortStream;
- (void)createVirtualStream;
- (void)removeVirtualStream;

- (void)repostNotification:(NSNotification *)notification;
- (void)portStreamEndpointDisappeared:(NSNotification *)notification;

@end


@implementation SSECombinationOutputStream

NSString *SSECombinationOutputStreamEndpointDisappearedNotification = @"SSECombinationOutputStreamEndpointDisappearedNotification";


- (id)init;
{
    if (!(self = [super init]))
        return nil;

    virtualEndpointName = [[[SMClient sharedClient] name] copy];
    virtualStreamDestination = [[SSESimpleOutputStreamDestination alloc] initWithName:virtualEndpointName];

    // We will always keep the same unique ID for our virtual destination,
    // even if we create and destroy it multiple times.
    virtualEndpointUniqueID = [SMEndpoint generateNewUniqueID];

    flags.ignoresTimeStamps = NO;
    flags.sendsSysExAsynchronously = NO;

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
    [virtualStreamDestination release];
    virtualStreamDestination = nil;

    [super dealloc];
}

- (NSArray *)destinations;
{
    return [[SMDestinationEndpoint destinationEndpoints] arrayByAddingObject:virtualStreamDestination];
    // TODO may want to pull out destination endpoints that are owned by this process
    // TODO may want to return these things, grouped (array of arrays)
}

- (id <SSEOutputStreamDestination>)selectedDestination;
{
    if (virtualStream)
        return virtualStreamDestination;
    else if (portStream)
        return [portStream endpoint];
    else
        return nil;
}

- (void)setSelectedDestination:(id <SSEOutputStreamDestination>)aDestination;
{
    if (aDestination) {
        if ([aDestination isKindOfClass:[SMDestinationEndpoint class]])
            [self selectEndpoint:(SMDestinationEndpoint *)aDestination];
        else
            [self selectEndpoint:nil];	// Use the virtual stream
    } else {
        // Deselect everything
        [self removePortStream];
        [self removeVirtualStream];
    }
}


- (void)setVirtualEndpointName:(NSString *)newName;
{
    if (virtualEndpointName == newName || [virtualEndpointName isEqualToString:newName])
        return;
        
    [virtualEndpointName release];
    virtualEndpointName = [newName retain];
    
    [[virtualStream endpoint] setName:virtualEndpointName];
}

- (void)setVirtualDisplayName:(NSString *)newName;
{
    [virtualStreamDestination setName:newName];
}

- (NSDictionary *)persistentSettings;
{
    if (portStream) {
        SMDestinationEndpoint *endpoint;
        
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
        SMDestinationEndpoint *endpoint;

        endpoint = [SMDestinationEndpoint destinationEndpointWithUniqueID:[number intValue]];
        if (endpoint) {
            [self selectEndpoint:endpoint];
        } else {
            NSString *endpointName;
        
            endpointName = [settings objectForKey:@"portEndpointName"];
            if (endpointName) {
                // Maybe an endpoint with this name still exists, but with a different unique ID.
                endpoint = [SMDestinationEndpoint destinationEndpointWithName:endpointName];
                if (endpoint)
                    [self selectEndpoint:endpoint];
                else
                    return endpointName;
            } else {
                return NSLocalizedStringFromTableInBundle(@"Unknown", @"SnoizeMIDI", [self bundle], "name of missing endpoint if not specified in document");
            }
        }
    } else if ((number = [settings objectForKey:@"virtualEndpointUniqueID"])) {
        [self removeVirtualStream];
        virtualEndpointUniqueID = [number intValue];
        [self selectEndpoint:nil];  // Use the virtual stream
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

- (BOOL)ignoresTimeStamps;
{
    return flags.ignoresTimeStamps;
}

- (void)setIgnoresTimeStamps:(BOOL)value;
{
    flags.ignoresTimeStamps = value;
    [[self stream] setIgnoresTimeStamps:value];
}

- (BOOL)sendsSysExAsynchronously;
{
    return flags.sendsSysExAsynchronously;
}

- (void)setSendsSysExAsynchronously:(BOOL)value;
{
    flags.sendsSysExAsynchronously = value;
    if ([[self stream] respondsToSelector:@selector(setSendsSysExAsynchronously:)])
        [[self stream] setSendsSysExAsynchronously:value];
}

- (BOOL)canSendSysExAsynchronously;
{
    return ([self stream] == portStream);
}

- (void)cancelPendingSysExSendRequests;
{
    if ([[self stream] respondsToSelector:@selector(cancelPendingSysExSendRequests)])
        [[self stream] cancelPendingSysExSendRequests];
}

- (SMSysExSendRequest *)currentSysExSendRequest;
{
    if ([[self stream] respondsToSelector:@selector(currentSysExSendRequest)])
        return [[self stream] currentSysExSendRequest];
    else
        return nil;
}

//
// SMMessageDestination protocol
//

- (void)takeMIDIMessages:(NSArray *)messages;
{
    [[self stream] takeMIDIMessages:messages];
}

@end


@implementation SSECombinationOutputStream (Private)

- (void)selectEndpoint:(SMDestinationEndpoint *)endpoint;
{
    if (endpoint) {
        // Set up the port stream
        if (!portStream)
            [self createPortStream];
        [portStream setEndpoint:endpoint];

        [self removeVirtualStream];
    } else {
        // Set up the virtual stream
        if (!virtualStream)
            [self createVirtualStream];

        [self removePortStream];
    }
}

- (void)createPortStream;
{
    OBASSERT(portStream == nil);

    NS_DURING {
        portStream = [[SMPortOutputStream alloc] init];
        [portStream setIgnoresTimeStamps:flags.ignoresTimeStamps];
        [portStream setSendsSysExAsynchronously:flags.sendsSysExAsynchronously];
    } NS_HANDLER {
        [portStream release];
        portStream = nil;
    } NS_ENDHANDLER;

    if (portStream) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(portStreamEndpointDisappeared:) name:SMPortOutputStreamEndpointDisappearedNotification object:portStream];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(repostNotification:) name:SMPortOutputStreamWillStartSysExSendNotification object:portStream];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(repostNotification:) name:SMPortOutputStreamFinishedSysExSendNotification object:portStream];
    }
}

- (void)removePortStream;
{
    if (portStream) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:portStream];

        [portStream release];
        portStream = nil;
    }
}

- (void)createVirtualStream;
{
    OBASSERT(virtualStream == nil);

    virtualStream = [[SMVirtualOutputStream alloc] initWithName:virtualEndpointName uniqueID:virtualEndpointUniqueID];
    [virtualStream setIgnoresTimeStamps:flags.ignoresTimeStamps];
}

- (void)removeVirtualStream;
{
    [virtualStream release];
    virtualStream = nil;
}

- (void)repostNotification:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:[notification name] object:self userInfo:[notification userInfo]];
}

- (void)portStreamEndpointDisappeared:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SSECombinationOutputStreamEndpointDisappearedNotification object:self];
}
 
@end
