#import "SMPortOrVirtualOutputStream.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMEndpoint.h"
#import "SMPortOutputStream.h"
#import "SMVirtualOutputStream.h"


@implementation SMPortOrVirtualOutputStream

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    flags.ignoresTimeStamps = NO;

    return self;
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
    [stream setIgnoresTimeStamps:flags.ignoresTimeStamps];
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
    [stream setIgnoresTimeStamps:flags.ignoresTimeStamps];

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
