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
    MIDIUniqueID uniqueID;
    SMSimpleInputStreamSource *inputStreamSource;
    SMMessageParser *parser;
}

- (MIDIUniqueID)uniqueID;
- (void)setUniqueID:(MIDIUniqueID)value;

- (NSString *)virtualEndpointName;
- (void)setVirtualEndpointName:(NSString *)value;

- (void)setInputSourceName:(NSString *)value;

@end
