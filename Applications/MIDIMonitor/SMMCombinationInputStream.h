/*
 Copyright (c) 2002-2014, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <SnoizeMIDI/SnoizeMIDI.h>

@class SMMSpyingInputStream;


@interface SMMCombinationInputStreamSourceGroup : NSObject

@property (nonatomic, readonly, strong) NSString *name;
@property (nonatomic, readonly, strong) NSArray<id<SMInputStreamSource>> *sources;
@property (nonatomic, readonly, assign) BOOL expandable;

@end


@interface SMMCombinationInputStream : NSObject <SMMessageDestination>

@property (nonatomic, assign) id<SMMessageDestination> messageDestination;

@property (nonatomic, readonly) NSArray<SMMCombinationInputStreamSourceGroup *> *sourceGroups;

@property (nonatomic, copy) NSSet<NSObject<SMInputStreamSource> *> *selectedInputSources;

- (NSDictionary *)persistentSettings;
- (NSArray *)takePersistentSettings:(NSDictionary *)settings;
    // If any endpoints couldn't be found, their names are returned

@property (nonatomic, copy) NSString *virtualEndpointName;

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
