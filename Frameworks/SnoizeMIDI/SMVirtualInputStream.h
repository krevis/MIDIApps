//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <SnoizeMIDI/SMInputStream.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMMessageParser;
@class SMDestinationEndpoint;


@interface SMVirtualInputStream : SMInputStream
{
    SMDestinationEndpoint *endpoint;
    SMMessageParser *parser;
}

- (id)initWithName:(NSString *)name uniqueID:(SInt32)uniqueID;

- (SMDestinationEndpoint *)endpoint;

@end
