//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SMMIDIObject.h>

@class SMSourceEndpoint;
@class SMDestinationEndpoint;


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

- (SInt32)singleRealtimeEntityIndex;
    // returns -1 if this property does not exist on the device
- (SMSourceEndpoint *)singleRealtimeSourceEndpoint;
- (SMDestinationEndpoint *)singleRealtimeDestinationEndpoint;
    // return nil if the device supports separate realtime messages for any entity

@end
