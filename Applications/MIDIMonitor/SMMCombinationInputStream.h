/*
 Copyright (c) 2002-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

@class SMMSpyingInputStream;


@interface SMMCombinationInputStream : NSObject <SMMessageDestination>
{
    id<SMMessageDestination> nonretainedMessageDestination;

    SMPortInputStream *portInputStream;
    SMVirtualInputStream *virtualInputStream;
    SMMSpyingInputStream *spyingInputStream;

    NSArray *groupedInputSources;
}

- (id<SMMessageDestination>)messageDestination;
- (void)setMessageDestination:(id<SMMessageDestination>)messageDestination;

- (NSArray *)groupedInputSources;
    // Returns an array of arrays; each is a list of valid source descriptions for each input stream
- (NSSet *)selectedInputSources;
- (void)setSelectedInputSources:(NSSet *)inputSources;

- (NSDictionary *)persistentSettings;
- (NSArray *)takePersistentSettings:(NSDictionary *)settings;
    // If any endpoints couldn't be found, their names are returned

- (NSString *)virtualEndpointName;
- (void)setVirtualEndpointName:(NSString *)value;

@end

// Notifications
//
// This class will repost these notifications from its streams (with self as object):
//	SMInputStreamReadingSysExNotification
//	SMInputStreamDoneReadingSysExNotification
//	SMInputStreamSelectedInputSourceDisappearedNotification
//
// It will also listen to SMInputStreamSourceListChangedNotification from its streams,
// and coalesce them into a single notification (with the same name) from this object.
