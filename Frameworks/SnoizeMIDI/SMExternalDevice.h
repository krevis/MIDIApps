//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SMMIDIObject.h>


@interface SMExternalDevice : SMMIDIObject
{
}

+ (NSArray *)externalDevices;
+ (SMExternalDevice *)externalDeviceWithUniqueID:(MIDIUniqueID)aUniqueID;
+ (SMExternalDevice *)externalDeviceWithDeviceRef:(MIDIDeviceRef)aDeviceRef;

- (MIDIDeviceRef)deviceRef;

- (NSString *)manufacturerName;
- (NSString *)modelName;
- (NSString *)pathToImageFile;

// Maximum SysEx speed in bytes/second
- (int)maxSysExSpeed;
- (void)setMaxSysExSpeed:(int)value;

@end
