//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


@interface SMExternalDevice : OFObject
{
    MIDIDeviceRef deviceRef;
    SInt32 uniqueID;
    unsigned int ordinal;
}

+ (NSArray *)externalDevices;
+ (SMExternalDevice *)externalDeviceWithUniqueID:(SInt32)aUniqueID;
+ (SMExternalDevice *)externalDeviceWithDeviceRef:(MIDIDeviceRef)aDeviceRef;

- (id)initWithDeviceRef:(MIDIDeviceRef)aDeviceRef;

- (MIDIDeviceRef)deviceRef;

- (SInt32)uniqueID;
- (NSString *)name;
- (NSString *)manufacturerName;
- (NSString *)modelName;
- (NSDictionary *)allProperties;
- (NSString *)pathToImageFile;

@end
