//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <SnoizeMIDI/SMInputStream.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMSimpleInputStreamSource;
@class SMMessageParser;
@class SMDestinationEndpoint;


@interface SMVirtualInputStream : SMInputStream
{
    SMDestinationEndpoint *endpoint;
    NSString *name;
    SInt32 uniqueID;
    SMSimpleInputStreamSource *inputStreamSource;
    SMMessageParser *parser;
}

- (SMDestinationEndpoint *)endpoint;

- (BOOL)isActive;
- (void)setIsActive:(BOOL)value;

- (SInt32)uniqueID;
- (void)setUniqueID:(SInt32)value;

// TODO Need a way to set the virtual endpoint's name
// TODO and the name shown in the input stream source?

@end
