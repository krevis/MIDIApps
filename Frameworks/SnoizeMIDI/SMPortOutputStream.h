/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <SnoizeMIDI/SMOutputStream.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>

@class SMDestinationEndpoint;
@class SMSysExSendRequest;


@interface SMPortOutputStream : SMOutputStream
{
    struct {
        unsigned int sendsSysExAsynchronously:1;
    } portFlags;

    MIDIPortRef outputPort;
    NSMutableSet *endpoints;
    NSMutableArray *sysExSendRequests;
}

- (NSSet *)endpoints;
- (void)setEndpoints:(NSSet *)newEndpoints;

- (BOOL)sendsSysExAsynchronously;
- (void)setSendsSysExAsynchronously:(BOOL)value;
    // If YES, then use MIDISendSysex() to send sysex messages with timestamps now or in the past.
    // (We can't use MIDISendSysex() to schedule delivery in the future.)
    // Otherwise, use plain old MIDI packets.

- (void)cancelPendingSysExSendRequests;
- (NSArray *)pendingSysExSendRequests;

@end

// Notifications

extern NSString *SMPortOutputStreamEndpointDisappearedNotification;
    // Sent if the stream's destination endpoint goes away

extern NSString *SMPortOutputStreamWillStartSysExSendNotification;
    // user info has key @"sendRequest", object SMSysExSendRequest
extern NSString *SMPortOutputStreamFinishedSysExSendNotification;
    // user info has key @"sendRequest", object SMSysExSendRequest
