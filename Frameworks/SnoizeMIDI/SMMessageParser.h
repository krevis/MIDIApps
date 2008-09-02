/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>

@class SMEndpoint;
@class SMSystemExclusiveMessage;


@interface SMMessageParser : NSObject
{
    SMEndpoint *nonretainedOriginatingEndpoint;
    id nonretainedDelegate;

    NSMutableData *readingSysExData;
    MIDITimeStamp startSysExTimeStamp;
    NSTimer *sysExTimeOutTimer;
    NSTimeInterval sysExTimeOut;

    BOOL ignoreInvalidData;
}

- (id)delegate;
- (void)setDelegate:(id)value;

- (SMEndpoint *)originatingEndpoint;
- (void)setOriginatingEndpoint:(SMEndpoint *)value;

- (NSTimeInterval)sysExTimeOut;
- (void)setSysExTimeOut:(NSTimeInterval)value;

- (BOOL)ignoresInvalidData;
- (void)setIgnoresInvalidData:(BOOL)value;

- (void)takePacketList:(const MIDIPacketList *)packetList;

- (BOOL)cancelReceivingSysExMessage;
    // Returns YES if it successfully cancels a sysex message which is being received, and NO otherwise.

@end


@interface NSObject (SMMessageParserDelegate)

- (void)parser:(SMMessageParser *)parser didReadMessages:(NSArray *)messages;
- (void)parser:(SMMessageParser *)parser isReadingSysExWithLength:(unsigned int)length;
- (void)parser:(SMMessageParser *)parser finishedReadingSysExMessage:(SMSystemExclusiveMessage *)message;

@end
