//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import "SMInputStreamSource.h"


@implementation SMSimpleInputStreamSource

- (id)initWithName:(NSString *)aName;
{
    if (!(self = [super init]))
        return nil;

    name = [aName copy];

    return self;
}

- (void)dealloc;
{
    [name release];
    name = nil;

    [super dealloc];
}

- (NSString *)inputStreamSourceName
{
    return name;
}

- (NSNumber *)inputStreamSourceUniqueID;
{
    return nil;
}

@end
