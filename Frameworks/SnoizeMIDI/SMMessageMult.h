//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>


@interface SMMessageMult : NSObject <SMMessageDestination>
{
    NSMutableArray *destinations;
    NSLock *destinationsLock;
}

- (NSArray *)destinations;
- (void)setDestinations:(NSArray *)newDestinations;
- (void)addDestination:(id<SMMessageDestination>)destination;
- (void)removeDestination:(id<SMMessageDestination>)destination;

@end
