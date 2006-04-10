//
//  SSEOutputStreamDestination.h
//  SysExLibrarian
//
//  Created by Kurt Revis on Tue Sep 03 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol SSEOutputStreamDestination <NSObject>

- (NSString *)outputStreamDestinationName;
- (NSArray *)outputStreamDestinationExternalDeviceNames;

@end


@interface SSESimpleOutputStreamDestination : NSObject <SSEOutputStreamDestination>
{
    NSString *name;
}

- (id)initWithName:(NSString *)aName;
- (void)setName:(NSString *)value;

- (NSString *)outputStreamDestinationName;
- (NSArray *)outputStreamDestinationExternalDeviceNames;
    // returns an empty array

@end
