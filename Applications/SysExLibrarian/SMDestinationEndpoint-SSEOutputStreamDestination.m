//
//  SMDestinationEndpoint-SSEOutputStreamDestination.m
//  SysExLibrarian
//
//  Created by Kurt Revis on Tue Sep 03 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "SMDestinationEndpoint-SSEOutputStreamDestination.h"


@implementation SMDestinationEndpoint (SSEOutputStreamDestination)

- (NSString *)outputStreamDestinationName;
{
    return [self uniqueName];
}

- (NSArray *)outputStreamDestinationExternalDeviceNames;
{
    return [[self connectedExternalDevices] arrayByPerformingSelector:@selector(name)];
}

- (BOOL)outputStreamDestinationNeedsSysExWorkaround;
{
    return [self needsSysExWorkaround];
}

@end
