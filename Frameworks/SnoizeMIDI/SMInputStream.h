/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


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
- (void)retainForIncomingMIDIWithSourceConnectionRefCon:(void *)refCon;
- (void)releaseForIncomingMIDIWithSourceConnectionRefCon:(void *)refCon;

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
