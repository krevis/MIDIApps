//
//  SMMessageMult.h
//  SnoizeMIDI
//
//  Created by krevis on Thu Dec 06 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@class NSArray, NSLock, NSMutableArray;

@interface SMMessageMult : OFObject <SMMessageDestination>
{
    NSMutableArray *destinations;
    NSLock *destinationsLock;
}

- (NSArray *)destinations;
- (void)setDestinations:(NSArray *)newDestinations;
- (void)addDestination:(id<SMMessageDestination>)destination;
- (void)removeDestination:(id<SMMessageDestination>)destination;

@end
