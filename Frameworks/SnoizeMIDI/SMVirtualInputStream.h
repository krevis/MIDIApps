//
//  SMVirtualInputStream.h
//  SnoizeMIDI
//
//  Created by krevis on Wed Nov 28 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <SnoizeMIDI/SMInputStream.h>

@class SMDestinationEndpoint;

@interface SMVirtualInputStream : SMInputStream
{
    SMDestinationEndpoint *endpoint;
}

- (id)initWithName:(NSString *)name uniqueID:(SInt32)uniqueID;

- (SMDestinationEndpoint *)endpoint;

@end
