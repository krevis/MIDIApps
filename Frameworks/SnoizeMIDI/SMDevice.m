//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import "SMDevice.h"
#import "SMClient.h"
#import "SMEndpoint.h"


@interface SMDevice (Private)

- (SMEndpoint *)singleRealtimeEndpointOfClass:(Class)endpointSubclass;

@end


@implementation SMDevice

//
// SMMIDIObject requires that we subclass these methods:
//

+ (MIDIObjectType)midiObjectType;
{
    return kMIDIObjectType_Device;
}

+ (ItemCount)midiObjectCount;
{
    return MIDIGetNumberOfDevices();
}

+ (MIDIObjectRef)midiObjectAtIndex:(ItemCount)index;
{
    return (MIDIObjectRef)MIDIGetDevice(index);
}

//
// Other SMMIDIObject overrides
//

- (void)propertyDidChange:(NSString *)propertyName;
{
    if ([propertyName isEqualToString:(NSString *)kMIDIPropertyOffline]) {
        // TODO When this device goes online or offline, its endpoints do too.
        // So we need this device to know what its entities and endpoints are so it can do what it needs to do with them.
        // (although going online won't help...)
        // Or we can just reload all endpoints and suck it up.
        
    }

    [super propertyDidChange:propertyName];
}

//
// New methods
//

+ (NSArray *)devices;
{
    return [self allObjectsInOrder];
}

+ (SMDevice *)deviceWithUniqueID:(MIDIUniqueID)aUniqueID;
{
    return (SMDevice *)[self objectWithUniqueID:aUniqueID];
}

+ (SMDevice *)deviceWithDeviceRef:(MIDIDeviceRef)aDeviceRef;
{
    return (SMDevice *)[self objectWithObjectRef:(MIDIObjectRef)aDeviceRef];
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

- (SInt32)singleRealtimeEntityIndex;
{
    OSStatus status;
    SInt32 value;

    status = MIDIObjectGetIntegerProperty(objectRef, kMIDIPropertySingleRealtimeEntity, &value);
    if (status == noErr)
        return value;
    else
        return -1;    
}

- (SMSourceEndpoint *)singleRealtimeSourceEndpoint;
{
    return (SMSourceEndpoint *)[self singleRealtimeEndpointOfClass:[SMSourceEndpoint class]];
}

- (SMDestinationEndpoint *)singleRealtimeDestinationEndpoint
{
    return (SMDestinationEndpoint *)[self singleRealtimeEndpointOfClass:[SMDestinationEndpoint class]];
}

@end


@implementation SMDevice (Private)

- (SMEndpoint *)singleRealtimeEndpointOfClass:(Class)endpointSubclass
{
    SInt32 entityIndex;
    SMEndpoint *endpoint = nil;

    entityIndex = [self singleRealtimeEntityIndex];
    if (entityIndex >= 0) {
        MIDIEntityRef entityRef;

        entityRef = MIDIDeviceGetEntity(objectRef, entityIndex);
        if (entityRef) {
            // Find the first endpoint in this entity.
            // (There is probably only one... I'm not sure what it would mean if there were more than one.)
            MIDIEndpointRef endpointRef;

            endpointRef = [endpointSubclass endpointRefAtIndex:0 forEntity:entityRef];
            if (endpointRef)
                endpoint = (SMEndpoint *)[endpointSubclass objectWithObjectRef:endpointRef];
        }
    }

    return endpoint;
}

@end
