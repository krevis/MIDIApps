//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SMMIDIObject.h>


@interface SMDevice : SMMIDIObject
{
}

+ (NSArray *)devices;
+ (SMDevice *)deviceWithUniqueID:(MIDIUniqueID)aUniqueID;
+ (SMDevice *)deviceWithDeviceRef:(MIDIDeviceRef)aDeviceRef;

- (MIDIDeviceRef)deviceRef;

- (NSString *)manufacturerName;
- (NSString *)modelName;
- (NSString *)pathToImageFile;

@end
