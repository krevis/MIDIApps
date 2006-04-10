//
//  SSEOutputStreamDestination.m
//  SysExLibrarian
//
//  Created by Kurt Revis on Tue Sep 03 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "SSEOutputStreamDestination.h"


@implementation SSESimpleOutputStreamDestination

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

- (void)setName:(NSString *)value;
{
    if (name != value) {
        [name release];
        name = [value copy];
    }
}

- (NSString *)outputStreamDestinationName;
{
    return name;
}

- (NSArray *)outputStreamDestinationExternalDeviceNames;
{
    return [NSArray array];
}

@end
