/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMDevice.h"
#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMMIDIObject-Private.h"


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
        // This device just went offline or online. We need to refresh its endpoints.
        // (If it went online, we didn't previously have its endpoints in our list.)

        // NOTE This is really an overly blunt approach, but what the hell.
        [SMSourceEndpoint refreshAllObjects];
        [SMDestinationEndpoint refreshAllObjects];        
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
{
    return [self stringForProperty:kMIDIPropertyImage];
}

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
