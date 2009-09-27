/*
 Copyright (c) 2001-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSEOutputStreamDestination.h"


@interface SSECombinationOutputStream : NSObject <SMMessageDestination>
{
    SMVirtualOutputStream *virtualStream;
    SMPortOutputStream *portStream;

    SSESimpleOutputStreamDestination *virtualStreamDestination;
    SInt32 virtualEndpointUniqueID;
    NSString *virtualEndpointName;

    struct {
        unsigned int ignoresTimeStamps:1;
        unsigned int sendsSysExAsynchronously:1;
    } flags;
}

+ (NSArray *)destinationEndpoints;

- (NSArray *)destinations;
- (NSArray *)groupedDestinations;
    // Returns an array of arrays. Each of the 2nd level arrays contains destinations that are of the same kind.
    // (That is, the first array has destinations for the port stream, the second array has destinations for the virtual stream, etc.)

- (id <SSEOutputStreamDestination>)selectedDestination;
- (void)setSelectedDestination:(id <SSEOutputStreamDestination>)aDestination;

- (void)setVirtualDisplayName:(NSString *)newName;

- (NSDictionary *)persistentSettings;
- (NSString *)takePersistentSettings:(NSDictionary *)settings;
    // If the endpoint indicated by the persistent settings couldn't be found, its name is returned

- (id)stream;
    // Returns the actual stream in use (either virtualStream or portStream)

    // Methods which are passed on to the relevant stream:

- (BOOL)ignoresTimeStamps;
- (void)setIgnoresTimeStamps:(BOOL)value;
    // If YES, then ignore the timestamps in the messages we receive, and send immediately instead

- (BOOL)sendsSysExAsynchronously;
- (void)setSendsSysExAsynchronously:(BOOL)value;
    // If YES, then use MIDISendSysex() to send sysex messages. Otherwise, use plain old MIDI packets.
    // (This can only work on port streams, not virtual ones.)
- (BOOL)canSendSysExAsynchronously;

- (void)cancelPendingSysExSendRequests;
- (SMSysExSendRequest *)currentSysExSendRequest;

@end

// Notifications
extern NSString *SSECombinationOutputStreamSelectedDestinationDisappearedNotification;
extern NSString *SSECombinationOutputStreamDestinationListChangedNotification;

// This class also reposts the following notifications from its SMPortOutputStream, with 'self' as the object:
//	SMPortOutputStreamWillStartSysExSendNotification
// 	SMPortOutputStreamFinishedSysExSendNotification
