//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import "SMExternalDevice.h"
#import "SMClient.h"


@implementation SMExternalDevice

//
// SMMIDIObject requires that we subclass these methods:
//

+ (MIDIObjectType)midiObjectType;
{
    return kMIDIObjectType_ExternalDevice;
}

+ (ItemCount)midiObjectCount;
{
    return MIDIGetNumberOfExternalDevices();
}

+ (MIDIObjectRef)midiObjectAtIndex:(ItemCount)index;
{
    return (MIDIObjectRef)MIDIGetExternalDevice(index);
}

//
// New methods
//

+ (NSArray *)externalDevices;
{
    return [self allObjectsInOrder];
}

+ (SMExternalDevice *)externalDeviceWithUniqueID:(MIDIUniqueID)aUniqueID;
{
    return (SMExternalDevice *)[self objectWithUniqueID:aUniqueID];
}

+ (SMExternalDevice *)externalDeviceWithDeviceRef:(MIDIDeviceRef)aDeviceRef;
{
    return (SMExternalDevice *)[self objectWithObjectRef:(MIDIObjectRef)aDeviceRef];
}

- (MIDIDeviceRef)deviceRef;
{
    return (MIDIDeviceRef)objectRef;
}

- (NSString *)manufacturerName;
{
    return [self stringForProperty:kMIDIPropertyManufacturer];
}

- (NSString *)modelName;
{
    return [self stringForProperty:kMIDIPropertyModel];
}

- (NSString *)pathToImageFile;
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_2
{
    return [self stringForProperty:kMIDIPropertyImage];
}
#else
{
    // NOTE CoreMIDI's symbol kMIDIPropertyImage is new to 10.2, but we can't link against it directly
    // because that will cause us to fail to run on 10.1. So, instead, we try to look up the address of
    // the symbol at runtime and use it if we find it.

    CFStringRef propertyName;

    propertyName = [[SMClient sharedClient] coreMIDIPropertyNameConstantNamed:@"kMIDIPropertyImage"];
    if (propertyName)
        return [self stringForProperty:(CFStringRef)propertyName];
    else
        return nil;
}
#endif

@end
