//
//  SMPortOrVirtualInputStream.h
//  SnoizeMIDI
//
//  Created by krevis on Fri Dec 07 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@class NSArray, NSDictionary, NSString;
@class SMVirtualInputStream, SMPortInputStream;

@interface SMPortOrVirtualInputStream : OFObject
{
    SMVirtualInputStream *virtualStream;
    SMPortInputStream *portStream;
    SInt32 virtualEndpointUniqueID;
    NSString *virtualEndpointName;
    NSString *virtualDisplayName;
        
    id<SMMessageDestination> nonretainedMessageDestination;
}

- (id<SMMessageDestination>)messageDestination;
- (void)setMessageDestination:(id<SMMessageDestination>)messageDestination;

- (NSArray *)sourceDescriptions;
- (NSDictionary *)sourceDescription;
- (void)setSourceDescription:(NSDictionary *)sourceDescription;

- (NSString *)virtualEndpointName;
- (void)setVirtualEndpointName:(NSString *)newName;

- (NSString *)virtualDisplayName;
- (void)setVirtualDisplayName:(NSString *)newName;

- (NSDictionary *)persistentSettings;
- (NSString *)takePersistentSettings:(NSDictionary *)settings;
    // If the endpoint couldn't be found, its name is returned

@end

// Notifications
extern NSString *SMPortOrVirtualInputStreamEndpointWasRemoved;
// This class will also repost SMInputStreamReadingSysExNotification and SMInputStreamDoneReadingSysExNotification, if it receives them from its own streams.
