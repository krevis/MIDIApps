//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SMMIDIObject.h>


@interface SMExternalDevice : SMMIDIObject
{
}

+ (NSArray *)externalDevices;
+ (SMExternalDevice *)externalDeviceWithUniqueID:(MIDIUniqueID)aUniqueID;
+ (SMExternalDevice *)externalDeviceWithDeviceRef:(MIDIDeviceRef)aDeviceRef;

- (id)initWithDeviceRef:(MIDIDeviceRef)aDeviceRef;

- (MIDIDeviceRef)deviceRef;

- (NSString *)manufacturerName;
- (NSString *)modelName;
- (NSString *)pathToImageFile;

@end
