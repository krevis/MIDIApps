/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


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
{
    return [self stringForProperty:kMIDIPropertyImage];
}

- (void)setMaxSysExSpeed:(int)value
{
    [super setMaxSysExSpeed: value];
    
    // Also set the speed on this device's source endpoints (which we get to via its entities).
    // This is how MIDISendSysex() determines what speed to use, surprisingly.
    
    MIDIDeviceRef deviceRef = [self deviceRef];
    ItemCount entityCount = MIDIDeviceGetNumberOfEntities(deviceRef);
    ItemCount entityIndex;
    for (entityIndex = 0; entityIndex < entityCount; entityIndex++)
    {
        MIDIEntityRef entityRef = MIDIDeviceGetEntity(deviceRef, entityIndex);
        if (entityRef)
        {
            ItemCount sourceCount = MIDIEntityGetNumberOfSources(entityRef);
            ItemCount sourceIndex;
            for (sourceIndex = 0; sourceIndex < sourceCount; sourceIndex++)
            {
                MIDIEndpointRef sourceEndpoint = MIDIEntityGetSource(entityRef, sourceIndex);
                if (sourceEndpoint)
                {
                    MIDIObjectSetIntegerProperty(sourceEndpoint, kMIDIPropertyMaxSysExSpeed, value);
                    // ignore errors, nothing we can do anyway
                }
            }
        }
    }    
}

@end
