//
//  SMPortOrVirtualOutputStream.h
//  SnoizeMIDI
//
//  Created by krevis on Fri Dec 07 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@class NSArray, NSDictionary, NSString;
@class SMVirtualOutputStream, SMPortOutputStream;

@interface SMPortOrVirtualOutputStream : OFObject <SMMessageDestination>
{
    SMVirtualOutputStream *virtualStream;
    SMPortOutputStream *portStream;
    SInt32 virtualEndpointUniqueID;
    NSString *virtualEndpointName;
    NSString *virtualDisplayName;
        
    id<SMMessageDestination> nonretainedMessageDestination;
}

- (NSArray *)destinationDescriptions;
- (NSDictionary *)destinationDescription;
- (void)setDestinationDescription:(NSDictionary *)destinationDescription;

- (NSString *)virtualEndpointName;
- (void)setVirtualEndpointName:(NSString *)newName;

- (NSString *)virtualDisplayName;
- (void)setVirtualDisplayName:(NSString *)newName;

- (NSDictionary *)persistentSettings;
- (NSString *)takePersistentSettings:(NSDictionary *)settings;
    // If the endpoint couldn't be found, its name is returned

@end

// Notifications
extern NSString *SMPortOrVirtualOutputStreamEndpointWasRemoved;
