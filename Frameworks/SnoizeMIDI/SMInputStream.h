//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>
#import <SnoizeMIDI/SMInputStreamSource.h>

@class SMEndpoint;
@class SMMessageParser;


@interface SMInputStream : NSObject
{
    id<SMMessageDestination> nonretainedMessageDestination;
    NSTimeInterval sysExTimeOut;
}

- (id<SMMessageDestination>)messageDestination;
- (void)setMessageDestination:(id<SMMessageDestination>)messageDestination;

- (NSTimeInterval)sysExTimeOut;
- (void)setSysExTimeOut:(NSTimeInterval)value;

- (void)cancelReceivingSysExMessage;

- (id)persistentSettings;
- (NSArray *)takePersistentSettings:(id)settings;
    // If any endpoints couldn't be found, their names are returned

// For subclasses only
- (MIDIReadProc)midiReadProc;
- (SMMessageParser *)newParserWithOriginatingEndpoint:(SMEndpoint *)originatingEndpoint;
- (void)postSelectedInputStreamSourceDisappearedNotification:(id<SMInputStreamSource>)source;
- (void)postSourceListChangedNotification;

// For subclasses to implement
- (NSArray *)parsers;
- (SMMessageParser *)parserForSourceConnectionRefCon:(void *)refCon;
- (id<SMInputStreamSource>)streamSourceForParser:(SMMessageParser *)parser;

- (NSArray *)inputSources;
- (NSSet *)selectedInputSources;
- (void)setSelectedInputSources:(NSSet *)sources;

@end

// Notifications
extern NSString *SMInputStreamReadingSysExNotification;
    // contains key @"length" with NSNumber (unsigned int) size of data read so far
    // contains key @"source" with id<SMInputStreamSource> that this sysex data was read from
extern NSString *SMInputStreamDoneReadingSysExNotification;
    // contains key @"length" with NSNumber (unsigned int) indicating size of data read
    // contains key @"source" with id<SMInputStreamSource> that this sysex data was read from
    // contains key @"valid" with NSNumber (BOOL) indicating whether sysex ended properly or not
extern NSString *SMInputStreamSelectedInputSourceDisappearedNotification;
    // contains key @"source" with id<SMInputStreamSource> which disappeared
extern NSString *SMInputStreamSourceListChangedNotification;
