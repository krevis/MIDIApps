//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMEndpoint.h"

#import <CoreFoundation/CoreFoundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#include <AvailabilityMacros.h>

#import "SMClient.h"
#import "SMExternalDevice.h"


@interface SMEndpoint (Private)

typedef struct EndpointUniqueNamesFlags {
    unsigned int areNamesUnique:1;
    unsigned int haveNamesAlwaysBeenUnique:1;
} EndpointUniqueNamesFlags;

+ (EndpointUniqueNamesFlags *)endpointUniqueNamesFlagsPtr;
+ (ItemCount)endpointCountForEntity:(MIDIEntityRef)entity;
+ (MIDIEndpointRef)endpointAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;

// TODO this is old
//+ (void)reloadEndpoints;

+ (BOOL)doEndpointsHaveUniqueNames;
+ (BOOL)haveEndpointsAlwaysHadUniqueNames;
+ (void)checkForUniqueNames;

- (MIDIDeviceRef)findDevice;
- (MIDIDeviceRef)device;
- (NSString *)deviceName;
- (NSString *)deviceStringForProperty:(CFStringRef)property;

- (SInt32)ownerPID;
- (void)setOwnerPID:(SInt32)value;

- (void)postRemovedNotification;
- (void)postReplacedNotificationWithReplacement:(SMEndpoint *)replacement;

@end


@implementation SMEndpoint

NSString *SMEndpointsAppearedNotification = @"SMEndpointsAppearedNotification";
NSString *SMEndpointDisappearedNotification = @"SMEndpointDisappearedNotification";
NSString *SMEndpointWasReplacedNotification = @"SMEndpointWasReplacedNotification";
NSString *SMEndpointReplacement = @"SMEndpointReplacement";

NSString *SMEndpointPropertyOwnerPID = @"SMEndpointPropertyOwnerPID";


/* TODO
+ (MIDIUniqueID)generateNewUniqueID;
{
    MIDIUniqueID proposed;
    static MIDIUniqueID sequence = 0;

    while (1) {
        // We could get fancy, but just using the current time is likely to work just fine.
        // Add a sequence number in case this method is called more than once within a second.
        proposed = time(NULL);
        proposed += sequence;
        sequence++;

        // Make sure this uniqueID is not in use, just in case
        if ([SMSourceEndpoint sourceEndpointWithUniqueID:proposed] == nil && [SMDestinationEndpoint destinationEndpointWithUniqueID:proposed] == nil)
            break;
    }

    return proposed;
}
*/

- (id)initWithObjectRef:(MIDIObjectRef)anObjectRef ordinal:(unsigned int)anOrdinal
{
    if (!(self = [super initWithObjectRef:anObjectRef ordinal:anOrdinal]))
        return nil;

    // We start out not knowing the endpoint's device (if it has one). We'll look it up on demand.
    deviceRef = NULL;
    endpointFlags.hasLookedForDevice = NO;

    // Nothing has been cached yet 
    endpointFlags.hasCachedManufacturerName = NO;
    endpointFlags.hasCachedModelName = NO;
    endpointFlags.hasCachedDeviceName = NO;
    
    return self;
}

- (void)dealloc;
{
    [self remove];
    
    [cachedManufacturerName release];
    cachedManufacturerName = nil;
    [cachedModelName release];
    cachedModelName = nil;
    [cachedDeviceName release];
    cachedDeviceName = nil;

    [super dealloc];
}

//
// SMMIDIObject overrides
//

- (void)checkIfPropertySetIsAllowed;
{
    if (![self isOwnedByThisProcess]) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Can't set a property on an endpoint we don't own", @"SnoizeMIDI", [self bundle], "exception if someone tries to set a property on an endpoint we don't own")];
    }
}

- (void)invalidateCachedProperties;
{
    [super invalidateCachedProperties];

    endpointFlags.hasLookedForDevice = NO;
    endpointFlags.hasCachedManufacturerName = NO;
    endpointFlags.hasCachedModelName = NO;
    endpointFlags.hasCachedDeviceName = NO;
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
    return ([self device] == NULL);
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
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Endpoint is not virtual, so it can't be owned by this process", @"SnoizeMIDI", [self bundle], "exception if someone calls -setIsOwnedByThisProcess on a non-virtual endpoint")];
    }
    
    [self setOwnerPID:getpid()];
}

- (void)remove;
{
    if (objectRef && [self isOwnedByThisProcess]) {
        MIDIEndpointDispose((MIDIEndpointRef)objectRef);
        objectRef = NULL;
    }
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
                cachedManufacturerName = [self deviceStringForProperty:kMIDIPropertyManufacturer];
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
        modelOrDeviceName = [self deviceName];
    }
    
    if (modelOrDeviceName && [modelOrDeviceName length] > 0)
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

- (BOOL)needsSysExWorkaround;
{
    // Returns YES if the endpoint is provided by the broken MIDIMAN driver, which can't send more than 3 bytes of sysex at once.
    //
    // Unfortunately we don't have a really good way of identifying this broken driver -- there isn't an obvious version number
    // that we can get through CoreMIDI.
    // (We could use the string property kMIDIPropertyDriverOwner, go through the possible MIDI Drivers directories,
    // track down the bundle, and get the CFBundleVersion out of it...)
    // But these drivers also unnecessarily put "MIDIMAN MIDISPORT " at the beginning of each endpoint name, which got
    // fixed in the next release.

    return ([[self manufacturerName] isEqualToString:@"MIDIMAN"] && [[self name] hasPrefix:@"MIDIMAN "]);
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

- (NSArray *)uniqueIDsOfConnectedThings;
{
    MIDIUniqueID oneUniqueID;
    NSData *data;

    // The property for kMIDIPropertyConnectionUniqueID may be an integer or a data object.
    // Try getting it as data first.  (The data is an array of big-endian MIDIUniqueIDs, aka SInt32s.)
    if (noErr == MIDIObjectGetDataProperty(objectRef, kMIDIPropertyConnectionUniqueID, (CFDataRef *)&data)) {
        unsigned int dataLength = [data length];
        unsigned int count;
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
    unsigned int uniqueIDIndex, uniqueIDCount;
    NSMutableArray *externalDevices;

    uniqueIDs = [self uniqueIDsOfConnectedThings];
    uniqueIDCount = [uniqueIDs count];
    externalDevices = [NSMutableArray arrayWithCapacity:uniqueIDCount];
    
    for (uniqueIDIndex = 0; uniqueIDIndex < uniqueIDCount; uniqueIDIndex++) {
        MIDIUniqueID aUniqueID = [[uniqueIDs objectAtIndex:uniqueIDIndex] intValue];
        SMExternalDevice *extDevice;

        extDevice = [SMExternalDevice externalDeviceWithUniqueID:aUniqueID];
        if (extDevice)
            [externalDevices addObject:extDevice];
    }    

    return externalDevices;
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
    return [[self connectedExternalDevices] arrayByPerformingSelector:@selector(name)];
}

@end


@implementation SMEndpoint (Private)

//
// Methods to be implemented in subclasses
//

+ (EndpointUniqueNamesFlags *)endpointUniqueNamesFlagsPtr;
{
    OBRequestConcreteImplementation(self, _cmd);
    return NULL;
}

+ (ItemCount)endpointCountForEntity:(MIDIEntityRef)entity;
{
    OBRequestConcreteImplementation(self, _cmd);
    return 0;
}

+ (MIDIEndpointRef)endpointAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;
{
    OBRequestConcreteImplementation(self, _cmd);
    return NULL;
}

//
// New methods
//

// TODO revisit of course
/*
+ (void)reloadEndpoints;
{
    NSMapTable **mapTablePtr;
    NSMapTable *oldMapTable, *newMapTable;
    ItemCount endpointIndex, endpointCount;
    NSMutableArray *removedEndpoints, *replacedEndpoints, *replacementEndpoints, *addedEndpoints;

    endpointCount = [self endpointCount];

    mapTablePtr = [self endpointMapTablePtr];
    OBASSERT(mapTablePtr != NULL);
    oldMapTable = *mapTablePtr;
    newMapTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSObjectMapValueCallBacks, endpointCount);    

    // We start out assuming all endpoints have been removed, none have been replaced.
    // As we find out otherwise, we remove some endpoints from removedEndpoints,
    // and add some to replacedEndpoints.
    removedEndpoints = [NSMutableArray arrayWithArray:[self allEndpoints]];
    replacedEndpoints = [NSMutableArray array];
    replacementEndpoints = [NSMutableArray array];
    addedEndpoints = [NSMutableArray array];

    // Iterate through the new endpointRefs.
    for (endpointIndex = 0; endpointIndex < endpointCount; endpointIndex++) {
        MIDIEndpointRef anEndpointRef;
        SMEndpoint *endpoint;

        anEndpointRef = [self endpointAtIndex:endpointIndex];
        if (anEndpointRef == NULL)
            continue;
        
        if ((endpoint = [self endpointForEndpointRef:anEndpointRef])) {
            // This endpointRef existed previously.
            [removedEndpoints removeObjectIdenticalTo:endpoint];
            // It's possible that its uniqueID changed, though.
            [endpoint updateUniqueID];
            // And its ordinal may also have changed...
            [endpoint setOrdinal:endpointIndex];
        } else {
            SMEndpoint *replacedEndpoint;

            // This endpointRef did not previously exist, so create a new endpoint for it.
            endpoint = [[[self alloc] initWithEndpointRef:anEndpointRef] autorelease];
            [endpoint setOrdinal:endpointIndex];
            
            // If the new endpoint has the same uniqueID as an old endpoint, remember it.
            if ((replacedEndpoint = [self endpointMatchingUniqueID:[endpoint uniqueID]])) {
                [replacedEndpoints addObject:replacedEndpoint];
                [replacementEndpoints addObject:endpoint];
                [removedEndpoints removeObjectIdenticalTo:replacedEndpoint];
            } else {
                [addedEndpoints addObject:endpoint];
            }
        }

        NSMapInsert(newMapTable, anEndpointRef, endpoint);
    }
    
    if (oldMapTable)
        NSFreeMapTable(oldMapTable);
    *mapTablePtr = newMapTable;

    // Make the new group of endpoints invalidate their cached properties (names and such).
    [[self allEndpoints] makeObjectsPerformSelector:@selector(invalidateCachedProperties)];

    // And check if the names are unique or not
    [self checkForUniqueNames];

    // Now everything is in place for the new regime. Have the endpoints post notifications of their change in status.
    [removedEndpoints makeObjectsPerformSelector:@selector(postRemovedNotification)];

    endpointIndex = [replacedEndpoints count];
    while (endpointIndex--) {
        [[replacedEndpoints objectAtIndex:endpointIndex] postReplacedNotificationWithReplacement:[replacementEndpoints objectAtIndex:endpointIndex]];
    }

    if ([addedEndpoints count] > 0)
        [[NSNotificationCenter defaultCenter] postNotificationName:SMEndpointsAppearedNotification object:addedEndpoints];
}
*/

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
    NSArray *nameArray, *nameSet;
    BOOL areNamesUnique;
    struct EndpointUniqueNamesFlags *flagsPtr;

    endpoints = [self allObjects];
    nameArray = [endpoints arrayByPerformingSelector:@selector(name)];
    nameSet = [NSSet setWithArray:nameArray];

    areNamesUnique = ([nameArray count] == [nameSet count]);

    flagsPtr = [self endpointUniqueNamesFlagsPtr];
    flagsPtr->areNamesUnique = areNamesUnique;
    flagsPtr->haveNamesAlwaysBeenUnique = flagsPtr->haveNamesAlwaysBeenUnique && areNamesUnique;
}

- (MIDIDeviceRef)findDevice;
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_2
{
    OSStatus status;
    MIDIEntityRef entity;
    MIDIDeviceRef device;

    status = MIDIEndpointGetEntity((MIDIEndpointRef)objectRef, &entity);
    if (noErr == status) {
        status = MIDIEntityGetDevice(entity, &device);
        if (noErr == status)
            return device;
    }

    return NULL;
}
#else
{
    static BOOL lookedForFunctions = NO;
    static OSStatus (*midiEndpointGetEntityFuncPtr)(MIDIEndpointRef, MIDIEntityRef *) = NULL;
    static OSStatus (*midiEntityGetDeviceFuncPtr)(MIDIEntityRef, MIDIDeviceRef *) = NULL;

    if (!lookedForFunctions) {
        // Try looking up the functions MIDIEndpointGetEntity() and MIDIEntityGetDevice() at run time.
        // They should be present on 10.2 but not on 10.1.
        midiEndpointGetEntityFuncPtr = [[SMClient sharedClient] coreMIDIFunctionNamed:@"MIDIEndpointGetEntity"];
        midiEntityGetDeviceFuncPtr = [[SMClient sharedClient] coreMIDIFunctionNamed:@"MIDIEntityGetDevice"];
        lookedForFunctions = YES;
    }

    if (midiEntityGetDeviceFuncPtr && midiEndpointGetEntityFuncPtr) {
        OSStatus status;
        MIDIEntityRef entity;
        MIDIDeviceRef device;

        status = midiEndpointGetEntityFuncPtr((MIDIEndpointRef)objectRef, &entity);
        if (noErr == status) {
            status = midiEntityGetDeviceFuncPtr(entity, &device);
            if (noErr == status)
                return device;
        }

        return NULL;

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
                    
                    thisEndpoint = [[self class] endpointAtIndex:endpointIndex forEntity:entity];
                    if (thisEndpoint == (MIDIEndpointRef)objectRef) {
                        // Found it!
                        return device;
                    }
                }
            }
        }
        
        // Nothing was found
        return NULL;
    }    
}
#endif

- (MIDIDeviceRef)device;
{
    if (!endpointFlags.hasLookedForDevice) {
        deviceRef = [self findDevice];
        endpointFlags.hasLookedForDevice = YES;
    }

    return deviceRef;
}

- (NSString *)deviceName;
{
    if (!endpointFlags.hasCachedDeviceName) {
        [cachedDeviceName release];
        cachedDeviceName = [[self deviceStringForProperty:kMIDIPropertyName] retain];

        endpointFlags.hasCachedDeviceName = YES;        
    }
    
    return cachedDeviceName;
}

- (NSString *)deviceStringForProperty:(CFStringRef)property;
{
    MIDIDeviceRef device;
    NSString *string;

    device = [self device];
    if (device && (noErr == MIDIObjectGetStringProperty(device, property, (CFStringRef *)&string)))
        return [string autorelease];
    else
        return nil;
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
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't set owner PID on endpoint: error %ld", @"SnoizeMIDI", [self bundle], "exception with OSStatus if setting endpoint's owner PID fails"), status];
    }
}

// TODO revisit
- (void)postRemovedNotification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMEndpointDisappearedNotification object:self];
}

// TODO revisit
- (void)postReplacedNotificationWithReplacement:(SMEndpoint *)replacement;
{
    NSDictionary *userInfo;
    
    OBASSERT(replacement != NULL);
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:replacement, SMEndpointReplacement, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMEndpointWasReplacedNotification object:self userInfo:userInfo];
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

+ (MIDIEndpointRef)endpointAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;
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
    SMClient *client;
    OSStatus status;
    MIDIEndpointRef newEndpointRef;
    BOOL wasPostingExternalNotification;
    SMSourceEndpoint *endpoint;

    client = [SMClient sharedClient];

    // We are going to be making a lot of changes, so turn off external notifications
    // for a while (until we're done).  Internal notifications are still necessary and aren't very slow.
    wasPostingExternalNotification = [client postsExternalSetupChangeNotification];
    [client setPostsExternalSetupChangeNotification:NO];

    status = MIDISourceCreate([client midiClient], (CFStringRef)newName, &newEndpointRef);
    if (status)
        return nil;

    // We want to get at the SMSourceEndpoint immediately.
    // CoreMIDI will send us a notification that something was added, and then we will create an SMSourceEndpoint.
    // However, those notifications are posted in the run loop's main mode, and we don't want to wait for it to be run.
    // So we need to manually add the new endpoint, now.
    [self immediatelyAddObjectWithObjectRef:newEndpointRef];
    
    // And try to get the new endpoint
    endpoint = [SMSourceEndpoint sourceEndpointWithEndpointRef:newEndpointRef];
    if (!endpoint) {
        NSLog(@"%@ couldn't find its virtual endpoint after it was created", NSStringFromClass(self));
        return nil;
    }

    [endpoint setIsOwnedByThisProcess];
    [endpoint setUniqueID:newUniqueID];
    [endpoint setManufacturerName:@"Snoize"];

    // Do this before the last modification, so one setup change notification will still happen
    [client setPostsExternalSetupChangeNotification:wasPostingExternalNotification];

    [endpoint setModelName:[client name]];

    return endpoint;
}

@end


@implementation SMDestinationEndpoint

static EndpointUniqueNamesFlags destinationEndpointUniqueNamesFlags = { YES, YES };

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

+ (MIDIEndpointRef)endpointAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetDestination(entity, index);
}

//
// New methods
//

+ (NSArray *)destinationEndpoints;
{
    return [self allObjectsInOrder];
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
    SMClient *client;
    OSStatus status;
    MIDIEndpointRef newEndpointRef;
    BOOL wasPostingExternalNotification;
    SMDestinationEndpoint *endpoint;

    client = [SMClient sharedClient];

    // We are going to be making a lot of changes, so turn off external notifications
    // for a while (until we're done).  Internal notifications are still necessary and aren't very slow.
    wasPostingExternalNotification = [client postsExternalSetupChangeNotification];
    [client setPostsExternalSetupChangeNotification:NO];

    status = MIDIDestinationCreate([client midiClient], (CFStringRef)endpointName, readProc, readProcRefCon, &newEndpointRef);
    if (status)
        return nil;

    // We want to get at the SMSourceEndpoint immediately.
    // CoreMIDI will send us a notification that something was added, and then we will create an SMSourceEndpoint.
    // However, those notifications are posted in the run loop's main mode, and we don't want to wait for it to be run.
    // So we need to manually add the new endpoint, now.
    [self immediatelyAddObjectWithObjectRef:newEndpointRef];

    endpoint = [SMDestinationEndpoint destinationEndpointWithEndpointRef:newEndpointRef];
    if (!endpoint) {
        NSLog(@"%@ couldn't find its virtual endpoint after it was created", NSStringFromClass(self));
        return nil;
    }
    
    [endpoint setIsOwnedByThisProcess];
    [endpoint setUniqueID:newUniqueID];
    [endpoint setManufacturerName:@"Snoize"];

    // Do this before the last modification, so one setup change notification will still happen
    [client setPostsExternalSetupChangeNotification:wasPostingExternalNotification];

    [endpoint setModelName:[client name]];

    return endpoint;
}

@end
