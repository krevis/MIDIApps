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
    NSString *endpointName;
    SInt32 uniqueID;
    SMSimpleInputStreamSource *inputStreamSource;
    SMMessageParser *parser;
}

- (SInt32)uniqueID;
- (void)setUniqueID:(SInt32)value;

- (NSString *)virtualEndpointName;
- (void)setVirtualEndpointName:(NSString *)value;

- (void)setInputSourceName:(NSString *)value;

@end
