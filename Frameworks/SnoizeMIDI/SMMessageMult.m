//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMMessageMult.h"


@implementation SMMessageMult

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    destinations = [[NSMutableArray alloc] init];
    destinationsLock = [[NSLock alloc] init];

    return self;
}

- (void)dealloc;
{
    [destinations release];
    destinations = nil;
    [destinationsLock release];
    destinationsLock = nil;

    [super dealloc];
}

- (NSArray *)destinations;
{
    return [NSArray arrayWithArray:destinations];
}

- (void)setDestinations:(NSArray *)newDestinations;
{
    if ((NSArray *)destinations == newDestinations)
        return;
    
    [destinationsLock lock];
    
    [destinations release];
    destinations = [newDestinations retain];

    [destinationsLock unlock];
}

- (void)addDestination:(id<SMMessageDestination>)destination;
{
    [destinationsLock lock];
    
    [destinations addObject:destination];

    [destinationsLock unlock];
}

- (void)removeDestination:(id<SMMessageDestination>)destination;
{
    [destinationsLock lock];
    
    [destinations removeObject:destination];

    [destinationsLock unlock];
}

- (void)takeMIDIMessages:(NSArray *)messages;
{
    [destinationsLock lock];
    
    [destinations makeObjectsPerformSelector:@selector(takeMIDIMessages:) withObject:messages];
    
    [destinationsLock unlock];
}

@end
