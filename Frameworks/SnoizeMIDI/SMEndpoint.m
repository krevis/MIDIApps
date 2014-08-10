/*
 Copyright (c) 2001-2009, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMEndpoint.h"

#import <CoreFoundation/CoreFoundation.h>
#include <AvailabilityMacros.h>
#include <unistd.h>

#import "SMClient.h"
#import "SMDevice.h"
#import "SMExternalDevice.h"
#import "SMMIDIObject-Private.h"
#import "SMUtilities.h"
#import "NSArray-SMExtensions.h"


@interface SMEndpoint (Private)

typedef struct EndpointUniqueNamesFlags {
    unsigned int areNamesUnique:1;
    unsigned int haveNamesAlwaysBeenUnique:1;
} EndpointUniqueNamesFlags;

+ (EndpointUniqueNamesFlags *)endpointUniqueNamesFlagsPtr;

+ (BOOL)doEndpointsHaveUniqueNames;
+ (BOOL)haveEndpointsAlwaysHadUniqueNames;
+ (void)checkForUniqueNames;

- (MIDIDeviceRef)findDevice;
- (MIDIDeviceRef)deviceRef;

- (SInt32)ownerPID;
- (void)setOwnerPID:(SInt32)value;

- (MIDIDeviceRef)getDeviceRefFromConnectedUniqueID:(MIDIUniqueID)connectedUniqueID;

@end


@implementation SMEndpoint

NSString *SMEndpointPropertyOwnerPID = @"SMEndpointPropertyOwnerPID";


+ (ItemCount)endpointCountForEntity:(MIDIEntityRef)entity;
{
    SMRequestConcreteImplementation(self, _cmd);
    return 0;
}

+ (MIDIEndpointRef)endpointRefAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;
{
    SMRequestConcreteImplementation(self, _cmd);
    return (MIDIEndpointRef)0;
}


- (id)initWithObjectRef:(MIDIObjectRef)anObjectRef ordinal:(NSUInteger)anOrdinal
{
    if (!(self = [super initWithObjectRef:anObjectRef ordinal:anOrdinal]))
        return nil;

    // We start out not knowing the endpoint's device (if it has one). We'll look it up on demand.
    deviceRef = (MIDIDeviceRef)0;
    endpointFlags.hasLookedForDevice = NO;

    // Nothing has been cached yet 
    endpointFlags.hasCachedManufacturerName = NO;
    endpointFlags.hasCachedModelName = NO;
    
    return self;
}

- (void)dealloc;
{
    [self remove];
    
    [cachedManufacturerName release];
    cachedManufacturerName = nil;
    [cachedModelName release];
    cachedModelName = nil;

    [super dealloc];
}

//
// SMMIDIObject overrides
//

- (void)checkIfPropertySetIsAllowed;
{
    if (![self isOwnedByThisProcess]) {
        NSString* reason = NSLocalizedStringFromTableInBundle(@"Can't set a property on an endpoint we don't own", @"SnoizeMIDI", SMBundleForObject(self), "exception if someone tries to set a property on an endpoint we don't own");
        [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
    }
}

- (void)invalidateCachedProperties;
{
    [super invalidateCachedProperties];

    endpointFlags.hasLookedForDevice = NO;
    endpointFlags.hasCachedManufacturerName = NO;
    endpointFlags.hasCachedModelName = NO;
}

- (void)propertyDidChange:(NSString *)propertyName;
{
    if ([propertyName isEqualToString:(NSString *)kMIDIPropertyManufacturer])
        endpointFlags.hasCachedManufacturerName = NO;
    else if ([propertyName isEqualToString:(NSString *)kMIDIPropertyModel])
        endpointFlags.hasCachedModelName = NO;
    else if ([propertyName isEqualToString:(NSString *)kMIDIPropertyModel])
        endpointFlags.hasCachedModelName = NO;

    [super propertyDidChange:propertyName];
}


//
// New methods
//

- (MIDIEndpointRef)endpointRef;
{
    return (MIDIEndpointRef)objectRef;
}

- (BOOL)isVirtual;
{
    // We are virtual if we have no device
    return ([self deviceRef] == (MIDIDeviceRef)0);
}

- (BOOL)isOwnedByThisProcess;
{
    return ([self isVirtual] && ([self ownerPID] == getpid()));
}

- (void)setIsOwnedByThisProcess;
{
    // We have sort of a chicken-egg problem here. When setting values of properties, we want
    // to make sure that the endpoint is owned by this process. However, there's no way to
    // tell if the endpoint is owned by this process until it gets a property set on it.
    // So we'll say that this method should be called first, before any other setters are called.
    
    if (![self isVirtual]) {
        NSString* reason = NSLocalizedStringFromTableInBundle(@"Endpoint is not virtual, so it can't be owned by this process", @"SnoizeMIDI", SMBundleForObject(self), "exception if someone calls -setIsOwnedByThisProcess on a non-virtual endpoint");
        [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
    }
    
    [self setOwnerPID:getpid()];
}

- (void)remove;
{
    if (objectRef && [self isOwnedByThisProcess]) {        
        MIDIEndpointDispose((MIDIEndpointRef)objectRef);

        // This object still hangs around in the endpoint lists until CoreMIDI gets around to posting a notification.
        // We should remove it immediately.
        [[self class] immediatelyRemoveObject:self];

        // Now we can forget the objectRef (not earlier!)
        objectRef = (MIDIObjectRef)0;
    }
}

- (NSString *)name;
{
    NSString* name = [super name];
    
    // Some misguided driver authors don't provide names for their endpoints.
    // (Seems especially common when the device has only one port.)
    // If there is no name provided, try some fallbacks.
    if (!name || [name length] == 0) {
        name = [[self device] name];

        if (!name || [name length] == 0) {
            name = [self modelName];
            
            if (!name || [name length] == 0) {
                name = [self manufacturerName];
                
                if (!name || [name length] == 0) {
                    name = @"<Unnamed Port>";
                }
            }
        }
    }
    
    return name;
}

- (NSString *)manufacturerName;
{
    if (!endpointFlags.hasCachedManufacturerName) {
        [cachedManufacturerName release];

        cachedManufacturerName = [self stringForProperty:kMIDIPropertyManufacturer];

        // NOTE This fails sometimes on 10.1.3 and earlier (see bug #2865704),
        // so we fall back to asking for the device's manufacturer name if necessary.
        // (This bug is fixed in 10.1.5, with CoreMIDI framework version 15.5.)
        if ([[SMClient sharedClient] coreMIDIFrameworkVersion] < 0x15508000) {
            if (!cachedManufacturerName)
                cachedManufacturerName = [[self device] manufacturerName];
        }

        [cachedManufacturerName retain];
        endpointFlags.hasCachedManufacturerName = YES;        
    }

    return cachedManufacturerName;
}

- (void)setManufacturerName:(NSString *)value;
{
    if (![value isEqualToString:[self manufacturerName]]) {
        [self setString:value forProperty:kMIDIPropertyManufacturer];
        endpointFlags.hasCachedManufacturerName = NO;
    }
}

- (NSString *)modelName;
{
    if (!endpointFlags.hasCachedModelName) {
        [cachedModelName release];
        cachedModelName = [[self stringForProperty:kMIDIPropertyModel] retain];

        endpointFlags.hasCachedModelName = YES;
    }

    return cachedModelName;
}

- (void)setModelName:(NSString *)value;
{
    if (![value isEqualToString:[self modelName]]) {
        [self setString:value forProperty:kMIDIPropertyModel];
        endpointFlags.hasCachedModelName = NO;
    }
}

- (NSString *)uniqueName;
{
    if ([[self class] doEndpointsHaveUniqueNames])
        return [self name];
    else
        return [self longName];
}

- (NSString *)alwaysUniqueName;
{
    if ([[self class] haveEndpointsAlwaysHadUniqueNames])
        return [self name];
    else
        return [self longName];    
}

- (NSString *)longName;
{
    NSString *endpointName, *modelOrDeviceName;

    endpointName = [self name];

    if ([self isVirtual]) {
        modelOrDeviceName = [self modelName];
    } else {
        modelOrDeviceName = [[self device] name];
    }
    
    if (modelOrDeviceName && [modelOrDeviceName length] > 0 && ![endpointName isEqualToString:modelOrDeviceName])
        return [[modelOrDeviceName stringByAppendingString:@" "] stringByAppendingString:endpointName];
    else
        return endpointName;
}

- (SInt32)advanceScheduleTime;
{
    return [self integerForProperty:kMIDIPropertyAdvanceScheduleTimeMuSec];
}

- (void)setAdvanceScheduleTime:(SInt32)newValue;
{
    [self setInteger:newValue forProperty:kMIDIPropertyAdvanceScheduleTimeMuSec];
}

- (NSString *)pathToImageFile;
{
    return [self stringForProperty:kMIDIPropertyImage];
}

- (NSArray *)uniqueIDsOfConnectedThings;
{
    MIDIUniqueID oneUniqueID;
    NSData *data;

    // The property for kMIDIPropertyConnectionUniqueID may be an integer or a data object.
    // Try getting it as data first.  (The data is an array of big-endian MIDIUniqueIDs, aka SInt32s.)
    if (noErr == MIDIObjectGetDataProperty(objectRef, kMIDIPropertyConnectionUniqueID, (CFDataRef *)&data)) {
        NSUInteger dataLength = [data length];
        NSUInteger count;
        const MIDIUniqueID *p, *end;
        NSMutableArray *array;
        
        // Make sure the data length makes sense
        if (dataLength % sizeof(SInt32) != 0)
            return [NSArray array];

        count = dataLength / sizeof(MIDIUniqueID);
        array = [NSMutableArray arrayWithCapacity:count];
        p = [data bytes];
        for (end = p + count ; p < end; p++) {
            oneUniqueID = ntohl(*p);
            if (oneUniqueID != 0)
                [array addObject:[NSNumber numberWithLong:oneUniqueID]];
        }

        return array;
    }
    
    // Now try getting the property as an integer. (It is only valid if nonzero.)
    if (noErr == MIDIObjectGetIntegerProperty(objectRef, kMIDIPropertyConnectionUniqueID, &oneUniqueID)) {
        if (oneUniqueID != 0)
            return [NSArray arrayWithObject:[NSNumber numberWithLong:oneUniqueID]];
    }

    // Give up
    return [NSArray array];
}

- (NSArray *)connectedExternalDevices;
{
    NSArray *uniqueIDs;
    NSUInteger uniqueIDIndex, uniqueIDCount;
    NSMutableArray *externalDevices;

    uniqueIDs = [self uniqueIDsOfConnectedThings];
    uniqueIDCount = [uniqueIDs count];
    externalDevices = [NSMutableArray arrayWithCapacity:uniqueIDCount];
    
    for (uniqueIDIndex = 0; uniqueIDIndex < uniqueIDCount; uniqueIDIndex++) {
        MIDIUniqueID aUniqueID = [[uniqueIDs objectAtIndex:uniqueIDIndex] intValue];
        MIDIDeviceRef aDeviceRef = [self getDeviceRefFromConnectedUniqueID:aUniqueID];
        if (aDeviceRef) {
            SMExternalDevice *extDevice = [SMExternalDevice externalDeviceWithDeviceRef:aDeviceRef];
            if (extDevice)
                [externalDevices addObject:extDevice];
        }
    }    

    return externalDevices;
}

- (SMDevice *)device;
{
    return [SMDevice deviceWithDeviceRef:[self deviceRef]];
}

//
// SMInputStreamSource protocol
//

- (NSString *)inputStreamSourceName;
{
    return [self uniqueName];
}

- (NSNumber *)inputStreamSourceUniqueID;
{
    return [NSNumber numberWithInt:[self uniqueID]];
}

- (NSArray *)inputStreamSourceExternalDeviceNames;
{
    return [[self connectedExternalDevices] SnoizeMIDI_arrayByMakingObjectsPerformSelector:@selector(name)];
}

//
// Overrides of SMMIDIObject private methods
//

+ (void)initialMIDISetup
{
    [super initialMIDISetup];
    [self checkForUniqueNames];
}

+ (void)refreshAllObjects
{
    [super refreshAllObjects];
    [self checkForUniqueNames];
}

+ (SMMIDIObject *)immediatelyAddObjectWithObjectRef:(MIDIObjectRef)anObjectRef;
{
    SMMIDIObject *object;

    object = [super immediatelyAddObjectWithObjectRef:anObjectRef];
    [self checkForUniqueNames];
    return object;
}

@end


@implementation SMEndpoint (Private)

//
// Methods to be implemented in subclasses
//

+ (EndpointUniqueNamesFlags *)endpointUniqueNamesFlagsPtr;
{
    SMRequestConcreteImplementation(self, _cmd);
    return NULL;
}

//
// New methods
//

+ (BOOL)doEndpointsHaveUniqueNames;
{
    return [self endpointUniqueNamesFlagsPtr]->areNamesUnique;
}

+ (BOOL)haveEndpointsAlwaysHadUniqueNames;
{
    return [self endpointUniqueNamesFlagsPtr]->haveNamesAlwaysBeenUnique;
}

+ (void)checkForUniqueNames;
{
    NSArray *endpoints;
    NSArray *nameArray;
    NSSet *nameSet;
    BOOL areNamesUnique;
    struct EndpointUniqueNamesFlags *flagsPtr;

    endpoints = [self allObjects];
    nameArray = [endpoints SnoizeMIDI_arrayByMakingObjectsPerformSelector:@selector(name)];
    nameSet = [NSSet setWithArray:nameArray];

    areNamesUnique = ([nameArray count] == [nameSet count]);

    flagsPtr = [self endpointUniqueNamesFlagsPtr];
    flagsPtr->areNamesUnique = areNamesUnique;
    flagsPtr->haveNamesAlwaysBeenUnique = flagsPtr->haveNamesAlwaysBeenUnique && areNamesUnique;
}

- (MIDIDeviceRef)findDevice;
{
    if ([[SMClient sharedClient] coreMIDICanGetDeviceFromEntity]) {
        OSStatus status;
        MIDIEntityRef entity;
        MIDIDeviceRef device;

        status = MIDIEndpointGetEntity((MIDIEndpointRef)objectRef, &entity);
        if (noErr == status) {
            status = MIDIEntityGetDevice(entity, &device);
            if (noErr == status)
                return device;
        }
    } else {
        // This must be 10.1. Do it the hard way.
        // Walk the device/entity/endpoint tree, looking for the device which has our endpointRef.
        // Note that if this endpoint is virtual, no device will be found.

        ItemCount deviceCount, deviceIndex;

        deviceCount = MIDIGetNumberOfDevices();
        for (deviceIndex = 0; deviceIndex < deviceCount; deviceIndex++) {
            MIDIDeviceRef device;
            ItemCount entityCount, entityIndex;

            device = MIDIGetDevice(deviceIndex);
            entityCount = MIDIDeviceGetNumberOfEntities(device);

            for (entityIndex = 0; entityIndex < entityCount; entityIndex++) {
                MIDIEntityRef entity;
                ItemCount endpointCount, endpointIndex;

                entity = MIDIDeviceGetEntity(device, entityIndex);
                endpointCount = [[self class] endpointCountForEntity:entity];
                for (endpointIndex = 0; endpointIndex < endpointCount; endpointIndex++) {
                    MIDIEndpointRef thisEndpoint;

                    thisEndpoint = [[self class] endpointRefAtIndex:endpointIndex forEntity:entity];
                    if (thisEndpoint == (MIDIEndpointRef)objectRef) {
                        // Found it!
                        return device;
                    }
                }
            }
        }
    }

    // Nothing was found
    return (MIDIDeviceRef)0;
}

- (MIDIDeviceRef)deviceRef;
{
    if (!endpointFlags.hasLookedForDevice) {
        deviceRef = [self findDevice];
        endpointFlags.hasLookedForDevice = YES;
    }

    return deviceRef;
}

- (SInt32)ownerPID;
{
    SInt32 value;
    
    NS_DURING {
        value = [self integerForProperty:(CFStringRef)SMEndpointPropertyOwnerPID];
    } NS_HANDLER {
        value = 0;
    } NS_ENDHANDLER;

    return value;
}

- (void)setOwnerPID:(SInt32)value;
{
    OSStatus status;
    
    status = MIDIObjectSetIntegerProperty(objectRef, (CFStringRef)SMEndpointPropertyOwnerPID, value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't set owner PID on endpoint: error %d", @"SnoizeMIDI", SMBundleForObject(self), "exception with OSStatus if setting endpoint's owner PID fails"), (int)status];
    }
}

- (MIDIDeviceRef)getDeviceRefFromConnectedUniqueID:(MIDIUniqueID)connectedUniqueID
{
    MIDIDeviceRef returnDeviceRef = (MIDIDeviceRef)0;

    if ([[SMClient sharedClient] coreMIDICanFindObjectByUniqueID]) {
        // 10.2 and later
        MIDIObjectRef connectedObjectRef;
        MIDIObjectType connectedObjectType;
        OSStatus err;
        BOOL done = NO;
        
        err = MIDIObjectFindByUniqueID(connectedUniqueID, &connectedObjectRef, &connectedObjectType);
        connectedObjectType &= ~kMIDIObjectType_ExternalMask;
        
        while (err == noErr && !done)
        {
            switch (connectedObjectType) {
                case kMIDIObjectType_Device:
                    // we've got the device already
                    returnDeviceRef = (MIDIDeviceRef)connectedObjectRef;
                    done = YES;
                    break;
                
                case kMIDIObjectType_Entity:
                    // get the entity's device
                    connectedObjectType = kMIDIObjectType_Device;
                    err = MIDIEntityGetDevice((MIDIEntityRef)connectedObjectRef, (MIDIDeviceRef*)&connectedObjectRef);
                    break;
                    
                case kMIDIObjectType_Destination:
                case kMIDIObjectType_Source:
                    // Get the endpoint's entity
                    connectedObjectType = kMIDIObjectType_Entity;
                    err = MIDIEndpointGetEntity((MIDIEndpointRef)connectedObjectRef, (MIDIEntityRef*)&connectedObjectRef);                
                    break;
                    
                default:
                    // give up
                    done = YES;
                    break;
            }        
        }
    } else {
        // 10.1 fallback.  Assume the unique ID is for an external device.
        returnDeviceRef = [[SMExternalDevice externalDeviceWithUniqueID: connectedUniqueID] deviceRef];
    }
    
    return returnDeviceRef;
}

@end


@implementation SMSourceEndpoint

static EndpointUniqueNamesFlags sourceEndpointUniqueNamesFlags = { YES, YES };

//
// SMMIDIObject required overrides
//

+ (MIDIObjectType)midiObjectType;
{
    return kMIDIObjectType_Source;
}

+ (ItemCount)midiObjectCount;
{
    return MIDIGetNumberOfSources();
}

+ (MIDIObjectRef)midiObjectAtIndex:(ItemCount)index;
{
    return MIDIGetSource(index);
}

//
// SMEndpoint required overrides
//

+ (EndpointUniqueNamesFlags *)endpointUniqueNamesFlagsPtr;
{
    return &sourceEndpointUniqueNamesFlags;
}

+ (ItemCount)endpointCountForEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetNumberOfSources(entity);
}

+ (MIDIEndpointRef)endpointRefAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetSource(entity, index);
}

//
// New methods
//

+ (NSArray *)sourceEndpoints;
{
    return [self allObjectsInOrder];
}

+ (SMSourceEndpoint *)sourceEndpointWithUniqueID:(MIDIUniqueID)aUniqueID;
{
    return (SMSourceEndpoint *)[self objectWithUniqueID:aUniqueID];
}

+ (SMSourceEndpoint *)sourceEndpointWithName:(NSString *)aName;
{
    return (SMSourceEndpoint *)[self objectWithName:aName];
}

+ (SMSourceEndpoint *)sourceEndpointWithEndpointRef:(MIDIEndpointRef)anEndpointRef;
{
    return (SMSourceEndpoint *)[self objectWithObjectRef:(MIDIObjectRef)anEndpointRef];
}

+ (SMSourceEndpoint *)createVirtualSourceEndpointWithName:(NSString *)newName uniqueID:(MIDIUniqueID)newUniqueID;
{
    SMClient *client = [SMClient sharedClient];
    OSStatus status;
    MIDIEndpointRef newEndpointRef;
    BOOL wasPostingExternalNotification;
    SMSourceEndpoint *endpoint;
    
    // We are going to be making a lot of changes, so turn off external notifications
    // for a while (until we're done).  Internal notifications are still necessary and aren't very slow.
    wasPostingExternalNotification = [client postsExternalSetupChangeNotification];
    [client setPostsExternalSetupChangeNotification:NO];

    status = MIDISourceCreate([client midiClient], (CFStringRef)newName, &newEndpointRef);
    if (status)
        return nil;

    // We want to get at the SMEndpoint immediately.
    // CoreMIDI will send us a notification that something was added, and then we will create an SMSourceEndpoint.
    // However, the notification from CoreMIDI is posted in the run loop's main mode, and we don't want to wait for it to be run.
    // So we need to manually add the new endpoint, now.
    endpoint = (SMSourceEndpoint *)[self immediatelyAddObjectWithObjectRef:newEndpointRef];
    if (!endpoint) {
        NSLog(@"%@ couldn't find its virtual endpoint after it was created", NSStringFromClass(self));
        return nil;
    }

    [endpoint setIsOwnedByThisProcess];

    if (newUniqueID != 0)
        [endpoint setUniqueID:newUniqueID];
    if ([endpoint uniqueID] == 0) {
        // CoreMIDI didn't assign a unique ID to this endpoint, so we should generate one ourself
        BOOL success = NO;

        while (!success)
            success = [endpoint setUniqueID:[SMMIDIObject generateNewUniqueID]];
    }
    
    [endpoint setManufacturerName:@"Snoize"];

    // Do this before the last modification, so one setup change notification will still happen
    [client setPostsExternalSetupChangeNotification:wasPostingExternalNotification];

    [endpoint setModelName:[client name]];

    return endpoint;
}

@end


@implementation SMDestinationEndpoint

static EndpointUniqueNamesFlags destinationEndpointUniqueNamesFlags = { YES, YES };
static SMDestinationEndpoint* sSysExSpeedWorkaroundWorkaroundEndpoint = nil;
static BOOL sCreatingSysExSpeedWorkaroundEndpoint = NO;

//
// SMMIDIObject required overrides
//

+ (MIDIObjectType)midiObjectType;
{
    return kMIDIObjectType_Destination;
}

+ (ItemCount)midiObjectCount;
{
    return MIDIGetNumberOfDestinations();
}

+ (MIDIObjectRef)midiObjectAtIndex:(ItemCount)index;
{
    return MIDIGetDestination(index);
}

//
// SMEndpoint required overrides
//

+ (EndpointUniqueNamesFlags *)endpointUniqueNamesFlagsPtr;
{
    return &destinationEndpointUniqueNamesFlags;
}

+ (ItemCount)endpointCountForEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetNumberOfDestinations(entity);
}

+ (MIDIEndpointRef)endpointRefAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetDestination(entity, index);
}

//
// New methods
//

+ (NSArray *)destinationEndpoints;
{
    NSArray* destinationEndpoints = [self allObjectsInOrder];
    
    if (sSysExSpeedWorkaroundWorkaroundEndpoint)
    {
        destinationEndpoints = [NSMutableArray arrayWithArray: destinationEndpoints];
        [(NSMutableArray*)destinationEndpoints removeObjectIdenticalTo: sSysExSpeedWorkaroundWorkaroundEndpoint];
    }

    return destinationEndpoints;
}

+ (SMDestinationEndpoint *)destinationEndpointWithUniqueID:(MIDIUniqueID)aUniqueID;
{
    return (SMDestinationEndpoint *)[self objectWithUniqueID:aUniqueID];
}

+ (SMDestinationEndpoint *)destinationEndpointWithName:(NSString *)aName;
{
    return (SMDestinationEndpoint *)[self objectWithName:aName];
}

+ (SMDestinationEndpoint *)destinationEndpointWithEndpointRef:(MIDIEndpointRef)anEndpointRef;
{
    return (SMDestinationEndpoint *)[self objectWithObjectRef:(MIDIObjectRef)anEndpointRef];
}

+ (SMDestinationEndpoint *)createVirtualDestinationEndpointWithName:(NSString *)endpointName readProc:(MIDIReadProc)readProc readProcRefCon:(void *)readProcRefCon uniqueID:(MIDIUniqueID)newUniqueID
{
    SMClient *client = [SMClient sharedClient];
    OSStatus status;
    MIDIEndpointRef newEndpointRef;
    BOOL wasPostingExternalNotification;
    SMDestinationEndpoint *endpoint;

    // We are going to be making a lot of changes, so turn off external notifications
    // for a while (until we're done).  Internal notifications are still necessary and aren't very slow.
    wasPostingExternalNotification = [client postsExternalSetupChangeNotification];
    [client setPostsExternalSetupChangeNotification:NO];

    status = MIDIDestinationCreate([client midiClient], (CFStringRef)endpointName, readProc, readProcRefCon, &newEndpointRef);
    if (status)
        return nil;

    // We want to get at the new SMEndpoint immediately.
    // CoreMIDI will send us a notification that something was added, and then we will create an SMSourceEndpoint.
    // However, the notification from CoreMIDI is posted in the run loop's main mode, and we don't want to wait for it to be run.
    // So we need to manually add the new endpoint, now.
    endpoint = (SMDestinationEndpoint *)[self immediatelyAddObjectWithObjectRef:newEndpointRef];    
    if (!endpoint) {
        NSLog(@"%@ couldn't find its virtual endpoint after it was created", NSStringFromClass(self));
        return nil;
    }
    
    [endpoint setIsOwnedByThisProcess];

    if (newUniqueID != 0) 
        [endpoint setUniqueID:newUniqueID];
    if ([endpoint uniqueID] == 0) {
        // CoreMIDI didn't assign a unique ID to this endpoint, so we should generate one ourself
        BOOL success = NO;

        while (!success) 
            success = [endpoint setUniqueID:[SMMIDIObject generateNewUniqueID]];
    }

    [endpoint setManufacturerName:@"Snoize"];

    // Do this before the last modification, so one setup change notification will still happen
    [client setPostsExternalSetupChangeNotification:wasPostingExternalNotification];

    [endpoint setModelName:[client name]];

    return endpoint;
}

+ (void)flushOutputForAllDestinationEndpoints;
{
    MIDIFlushOutput((MIDIEndpointRef)0);
}

- (void)flushOutput;
{
    MIDIFlushOutput((MIDIEndpointRef)objectRef);
}

//
// Sysex speed workaround
//
// The CoreMIDI client caches the last device that was given to MIDISendSysex(), along with its max sysex speed.
// So when we change the speed, it doesn't notice and continues to use the old speed.
// To fix this, we send a tiny sysex message to a different device.  Unfortunately we can't just use a NULL endpoint,
// it has to be a real live endpoint.    
//

static void IgnoreMIDIReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon)
{
    // Ignore the input
}

+ (SMDestinationEndpoint*) sysExSpeedWorkaroundDestinationEndpoint
{
    if (!sSysExSpeedWorkaroundWorkaroundEndpoint) {
        // We're going to make a few changes (making an endpoint, setting our workaroundVirtualDestination ivar,
        // then making the endpoint private), so turn off external notifications until we're done.
        BOOL wasPostingExternalNotification = [[SMClient sharedClient] postsExternalSetupChangeNotification];
        [[SMClient sharedClient] setPostsExternalSetupChangeNotification:NO];

        // Also set a flag so we don't post object list notifications until this object has been fully set up
        // (and, most importantly, that we have assigned to sSysExSpeedWorkaroundWorkaroundEndpoint so 
        // -destinationEndpoints can do the filtering properly).
        sCreatingSysExSpeedWorkaroundEndpoint = YES;
        
        sSysExSpeedWorkaroundWorkaroundEndpoint = [SMDestinationEndpoint createVirtualDestinationEndpointWithName: @"Workaround" 
                                                                                                         readProc: IgnoreMIDIReadProc
                                                                                                   readProcRefCon: NULL
                                                                                                         uniqueID: 0];
        [sSysExSpeedWorkaroundWorkaroundEndpoint retain];
        
        [sSysExSpeedWorkaroundWorkaroundEndpoint setInteger:1 forProperty:kMIDIPropertyPrivate];

        sCreatingSysExSpeedWorkaroundEndpoint = NO;
        // post internal notifications that we squelched earlier
        if (sSysExSpeedWorkaroundWorkaroundEndpoint) {
            [self postObjectListChangedNotification];
            [self postObjectsAddedNotificationWithObjects:[NSArray arrayWithObject: sSysExSpeedWorkaroundWorkaroundEndpoint]];
        }
                
        [[SMClient sharedClient] setPostsExternalSetupChangeNotification:wasPostingExternalNotification];
        if(wasPostingExternalNotification)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:SMClientSetupChangedNotification object:[SMClient sharedClient]];
        }
    }
    
    return sSysExSpeedWorkaroundWorkaroundEndpoint;
}    

+ (void)postObjectListChangedNotification;
{
    if (!sCreatingSysExSpeedWorkaroundEndpoint) {
        [super postObjectListChangedNotification];
    }
}

+ (void)postObjectsAddedNotificationWithObjects:(NSArray*)objects
{
    if (!sCreatingSysExSpeedWorkaroundEndpoint) {
        [super postObjectsAddedNotificationWithObjects:objects];
    }
}

@end
