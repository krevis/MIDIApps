//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import "NSArray-SMExtensions.h"


@implementation NSArray (SMExtensions)

- (NSArray *)SnoizeMIDI_arrayByMakingObjectsPerformSelector:(SEL)selector
{
    NSMutableArray *results;
    NSEnumerator *enumerator;
    id object;

    results = [NSMutableArray arrayWithCapacity:[self count]];
    enumerator = [self objectEnumerator];
    while ((object = [enumerator nextObject])) {
        id result = [object performSelector:selector];
        if (result)
            [results addObject:result];
    }

    return results;
}

@end
