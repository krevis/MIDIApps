//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@class SMEndpoint;
@class SMMessageParser;


@interface SMInputStream : OFObject
{
    id<SMMessageDestination> nonretainedMessageDestination;
    NSTimeInterval sysExTimeOut;
}

- (id<SMMessageDestination>)messageDestination;
- (void)setMessageDestination:(id<SMMessageDestination>)messageDestination;

- (NSTimeInterval)sysExTimeOut;
- (void)setSysExTimeOut:(NSTimeInterval)value;

- (BOOL)cancelReceivingSysExMessage;
    // Returns YES if it can successfully cancel a sysex message which is being received, and NO otherwise.

// For subclasses only
- (MIDIReadProc)midiReadProc;
- (SMMessageParser *)newParserWithOriginatingEndpoint:(SMEndpoint *)originatingEndpoint;

// For subclasses to implement
- (NSArray *)parsers;
- (SMMessageParser *)parserForSourceConnectionRefCon:(void *)refCon;

- (NSArray *)inputSources;
- (NSArray *)selectedInputSources;
- (void)setSelectedInputSources:(NSArray *)sources;

@end

// Notifications
extern NSString *SMInputStreamReadingSysExNotification;
    // contains key @"length" with NSNumber (unsigned int) size of data read so far
extern NSString *SMInputStreamDoneReadingSysExNotification;
    // contains key @"length" with NSNumber (unsigned int) indicating size of data read
    // contains key @"valid" with NSNumber (BOOL) indicating whether sysex ended properly or not
