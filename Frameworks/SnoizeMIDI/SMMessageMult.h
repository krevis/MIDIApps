#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>


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
