#import "SMEndpoint.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"


@interface SMEndpoint (Private)

+ (void)_earlyMIDISetup;
+ (void)_midiSetupChanged:(NSNotification *)notification;

+ (NSMapTable **)_endpointMapTablePtr;
+ (ItemCount)_endpointCount;
+ (MIDIEndpointRef)_endpointAtIndex:(ItemCount)index;
+ (ItemCount)_endpointCountForEntity:(MIDIEntityRef)entity;
+ (MIDIEndpointRef)_endpointAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;

+ (void)_reloadMapTable;
+ (NSArray *)_allEndpoints;
+ (SMEndpoint *)_endpointMatchingUniqueID:(SInt32)uniqueID;
+ (SMEndpoint *)_endpointForEndpointRef:(MIDIEndpointRef)anEndpointRef;

+ (BOOL)_doEndpointsHaveUniqueNames;

- (void)_updateUniqueID;
- (MIDIDeviceRef)_findDevice;
- (MIDIDeviceRef)_device;
- (NSString *)_deviceName;

- (SInt32)_ownerPID;
- (void)_setOwnerPID:(SInt32)value;

- (NSString *)_stringForProperty:(CFStringRef)property;
- (void)_setString:(NSString *)value forProperty:(CFStringRef)property;

- (SInt32)_integerForProperty:(CFStringRef)property;
- (void)_setInteger:(SInt32)value forProperty:(CFStringRef)property;

- (void)_checkIfPropertySetIsAllowed;

- (void)_postRemovedNotification;
- (void)_postReplacedNotificationWithReplacement:(SMEndpoint *)replacement;
- (void)_postAddedNotification;

@end


@implementation SMEndpoint

DEFINE_NSSTRING(SMEndpointWasAddedNotification);
DEFINE_NSSTRING(SMEndpointDisappearedNotification);
DEFINE_NSSTRING(SMEndpointWasReplacedNotification);
DEFINE_NSSTRING(SMEndpointReplacement);

DEFINE_NSSTRING(SMEndpointPropertyOwnerPID);


+ (SInt32)generateNewUniqueID;
{
    SInt32 proposed;
    static SInt32 sequence = 0;

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

- (id)initWithEndpointRef:(MIDIEndpointRef)anEndpointRef;
{
    if (!(self = [super init]))
        return nil;

    OBPRECONDITION(anEndpointRef);
    endpointRef = anEndpointRef;

    // Save the endpoint's uniqueID, since it could become inaccessible later (if the endpoint goes away).
    [self _updateUniqueID];

    // We start out not knowing the endpoint's device (if it has one). We'll look it up on demand.
    deviceRef = NULL;
    flags.hasLookedForDevice = NO;

    return self;
}

- (void)dealloc;
{
    [super dealloc];
}

- (MIDIEndpointRef)endpointRef;
{
    return endpointRef;
}

- (BOOL)isVirtual;
{
    // We are virtual if we have no device
    return ([self _device] == NULL);
}

- (BOOL)isOwnedByThisProcess;
{
    return ([self isVirtual] && ([self _ownerPID] == getpid()));
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
    
    [self _setOwnerPID:getpid()];
}

- (SInt32)uniqueID;
{
    return uniqueID;
}

- (void)setUniqueID:(SInt32)value;
{
    OSStatus status;

    if (value == uniqueID)
        return;

    [self _checkIfPropertySetIsAllowed];

    status = MIDIObjectSetIntegerProperty(endpointRef, kMIDIPropertyUniqueID, value);
    if (status) {
        [NSException raise:NSGenericException format:@"Couldn't set endpoint's unique ID: error %ld", status];
    }

    uniqueID = value;
}

- (NSString *)name;
{
    return [self _stringForProperty:kMIDIPropertyName];
}

- (void)setName:(NSString *)value;
{
    if (![value isEqualToString:[self name]])
        [self _setString:value forProperty:kMIDIPropertyName];
}

- (NSString *)manufacturerName;
{
    return [self _stringForProperty:kMIDIPropertyManufacturer];
}

- (void)setManufacturerName:(NSString *)value;
{
    if (![value isEqualToString:[self manufacturerName]])
        [self _setString:value forProperty:kMIDIPropertyManufacturer];
}

- (NSString *)modelName;
{
    return [self _stringForProperty:kMIDIPropertyModel];
}

- (void)setModelName:(NSString *)value;
{
    if (![value isEqualToString:[self modelName]])
        [self _setString:value forProperty:kMIDIPropertyModel];
}

- (NSString *)shortName;
{
    if ([[self class] _doEndpointsHaveUniqueNames])
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
        modelOrDeviceName = [self _deviceName];
    }
    
    if (modelOrDeviceName && [modelOrDeviceName length] > 0)
        return [[modelOrDeviceName stringByAppendingString:@" "] stringByAppendingString:endpointName];
    else
        return endpointName;
}

- (SInt32)advanceScheduleTime;
{
    return [self _integerForProperty:kMIDIPropertyAdvanceScheduleTimeMuSec];
}

- (void)setAdvanceScheduleTime:(SInt32)newValue;
{
    [self _setInteger:newValue forProperty:kMIDIPropertyAdvanceScheduleTimeMuSec];
}


@end


@implementation SMEndpoint (Private)

+ (void)_earlyMIDISetup;
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_midiSetupChanged:) name:SMClientSetupChangedInternalNotification object:[SMClient sharedClient]];
    [self _midiSetupChanged:nil];
}

+ (void)_midiSetupChanged:(NSNotification *)notification
{
    [self _reloadMapTable];
}

+ (NSMapTable **)_endpointMapTablePtr;
{
    OBRequestConcreteImplementation(self, _cmd);
    return NULL;
}

+ (ItemCount)_endpointCount;
{
    OBRequestConcreteImplementation(self, _cmd);
    return 0;
}

+ (MIDIEndpointRef)_endpointAtIndex:(ItemCount)index;
{
    OBRequestConcreteImplementation(self, _cmd);
    return NULL;
}

+ (ItemCount)_endpointCountForEntity:(MIDIEntityRef)entity;
{
    OBRequestConcreteImplementation(self, _cmd);
    return 0;
}

+ (MIDIEndpointRef)_endpointAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;
{
    OBRequestConcreteImplementation(self, _cmd);
    return NULL;
}

+ (void)_reloadMapTable;
{
    NSMapTable **mapTablePtr;
    NSMapTable *oldMapTable, *newMapTable;
    ItemCount endpointIndex, endpointCount;
    NSMutableArray *removedEndpoints, *replacedEndpoints, *replacementEndpoints, *addedEndpoints;

    endpointCount = [self _endpointCount];

    mapTablePtr = [self _endpointMapTablePtr];
    OBASSERT(mapTablePtr != NULL);
    oldMapTable = *mapTablePtr;
    newMapTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSObjectMapValueCallBacks, endpointCount);    

    // We start out assuming all endpoints have been removed, none have been replaced.
    // As we find out otherwise, we remove some endpoints from removedEndpoints,
    // and add some to replacedEndpoints.
    removedEndpoints = [NSMutableArray arrayWithArray:[self _allEndpoints]];
    replacedEndpoints = [NSMutableArray array];
    replacementEndpoints = [NSMutableArray array];
    addedEndpoints = [NSMutableArray array];

    // Iterate through the new endpointRefs.
    for (endpointIndex = 0; endpointIndex < endpointCount; endpointIndex++) {
        MIDIEndpointRef anEndpointRef;
        SMEndpoint *endpoint;

        anEndpointRef = [self _endpointAtIndex:endpointIndex];
        if (anEndpointRef == NULL)
            continue;
        
        if ((endpoint = [self _endpointForEndpointRef:anEndpointRef])) {
            // This endpointRef existed previously.
            [removedEndpoints removeObjectIdenticalTo:endpoint];
            // It's possible that its uniqueID changed, though.
            [endpoint _updateUniqueID];
        } else {
            SMEndpoint *replacedEndpoint;

            // This endpointRef did not previously exist, so create a new endpoint for it.
            endpoint = [[[self alloc] initWithEndpointRef:anEndpointRef] autorelease];
            
            // If the new endpoint has the same uniqueID as an old endpoint, remember it.
            if ((replacedEndpoint = [self _endpointMatchingUniqueID:[endpoint uniqueID]])) {
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

    // Now everything is in place for the new regime. Have the endpoints post notifications of their change in status.
    [removedEndpoints makeObjectsPerformSelector:@selector(_postRemovedNotification)];

    endpointIndex = [replacedEndpoints count];
    while (endpointIndex--) {
        [[replacedEndpoints objectAtIndex:endpointIndex] _postReplacedNotificationWithReplacement:[replacementEndpoints objectAtIndex:endpointIndex]];
    }
    
    [addedEndpoints makeObjectsPerformSelector:@selector(_postAddedNotification)];
}

+ (NSArray *)_allEndpoints;
{
    // TODO Should we sort the endpoints? (by name? unique ID?)

    NSMapTable **mapTablePtr;

    mapTablePtr = [self _endpointMapTablePtr];
    OBASSERT(mapTablePtr);

    if (*mapTablePtr)
        return NSAllMapTableValues(*mapTablePtr);
    else
        return nil;
}

+ (SMEndpoint *)_endpointMatchingUniqueID:(SInt32)aUniqueID;
{
    NSArray *allEndpoints;
    unsigned int endpointIndex;
    
    allEndpoints = [self _allEndpoints];
    endpointIndex = [allEndpoints count];
    while (endpointIndex--) {
        SMEndpoint *endpoint;
        
        endpoint = [allEndpoints objectAtIndex:endpointIndex];
        if ([endpoint uniqueID] == aUniqueID)
            return endpoint;
    }

    return nil;
}

+ (SMEndpoint *)_endpointForEndpointRef:(MIDIEndpointRef)anEndpointRef;
{
    NSMapTable **mapTablePtr;

    mapTablePtr = [self _endpointMapTablePtr];
    OBASSERT(mapTablePtr);

    if (*mapTablePtr)
        return NSMapGet(*mapTablePtr, anEndpointRef);
    else
        return nil;        
}

+ (BOOL)_doEndpointsHaveUniqueNames;
{
    NSArray *endpoints;
    NSArray *nameArray, *nameSet;
    
    endpoints = [self _allEndpoints];
    nameArray = [endpoints arrayByPerformingSelector:@selector(name)];
    nameSet = [NSSet setWithArray:nameArray];

    return ([nameArray count] == [nameSet count]);
}

- (void)_updateUniqueID;
{
    if (noErr != MIDIObjectGetIntegerProperty(endpointRef, kMIDIPropertyUniqueID, &uniqueID))
        uniqueID = 0;
}

- (MIDIDeviceRef)_findDevice;
{
    // Walk the device/entity/endpoint tree, looking for the device which has our endpointRef.
    // CoreMIDI should provide an easier way to get at this.
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
            endpointCount = [[self class] _endpointCountForEntity:entity];
            for (endpointIndex = 0; endpointIndex < endpointCount; endpointIndex++) {
                MIDIEndpointRef thisEndpoint;
                
                thisEndpoint = [[self class] _endpointAtIndex:endpointIndex forEntity:entity];
                if (thisEndpoint == endpointRef) {
                    // Found it!
                    return device;
                }
            }
        }
    }
    
    // Nothing was found
    return NULL;
}

- (MIDIDeviceRef)_device;
{
    if (!flags.hasLookedForDevice) {
        deviceRef = [self _findDevice];
        flags.hasLookedForDevice = YES;
    }

    return deviceRef;
}

- (NSString *)_deviceName;
{
    MIDIDeviceRef device;
    NSString *deviceName;
    
    device = [self _device];
    if (device && (noErr == MIDIObjectGetStringProperty(device, kMIDIPropertyName, (CFStringRef *)&deviceName)))
        return [deviceName autorelease];
    else
        return nil;
}

- (SInt32)_ownerPID;
{
    OSStatus status;
    SInt32 ownerPID;

    status = MIDIObjectGetIntegerProperty(endpointRef, (CFStringRef)SMEndpointPropertyOwnerPID, &ownerPID);
    if (status)
        return 0;
    else
        return ownerPID;
}

- (void)_setOwnerPID:(SInt32)value;
{
    OSStatus status;
    
    status = MIDIObjectSetIntegerProperty(endpointRef, (CFStringRef)SMEndpointPropertyOwnerPID, value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't set owner PID on endpoint: error %ld", @"SnoizeMIDI", [self bundle], "exception with OSStatus if setting endpoint's owner PID fails"), status];
    }
}

- (NSString *)_stringForProperty:(CFStringRef)property;
{
    NSString *string;
    
    if (noErr == MIDIObjectGetStringProperty(endpointRef, property, (CFStringRef *)&string))
        return [string autorelease];
    else
        return nil;
}

- (void)_setString:(NSString *)value forProperty:(CFStringRef)property;
{
    OSStatus status;
    
    [self _checkIfPropertySetIsAllowed];

    status = MIDIObjectSetStringProperty(endpointRef, property, (CFStringRef)value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't set endpoint's property %@ (error %ld)", @"SnoizeMIDI", [self bundle], "exception with property and OSStatus if setting endpoint's property fails"), property, status];
    }
}

- (SInt32)_integerForProperty:(CFStringRef)property;
{
    OSStatus status;
    SInt32 value;
    
    status = MIDIObjectGetIntegerProperty(endpointRef, property, &value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't get endpoint's property %@ (error %ld)", @"SnoizeMIDI", [self bundle], "exception with property and OSStatus if getting endpoint's property fails"), property, status];
    }
    
    return value;    
}

- (void)_setInteger:(SInt32)value forProperty:(CFStringRef)property;
{
    OSStatus status;

    [self _checkIfPropertySetIsAllowed];
    
    status = MIDIObjectSetIntegerProperty(endpointRef, property, value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't set endpoint's property %@ (error %ld)", @"SnoizeMIDI", [self bundle], "exception with property and OSStatus if setting endpoint's property fails"), property, status];
    }
}

- (void)_checkIfPropertySetIsAllowed;
{
    if (![self isOwnedByThisProcess]) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Can't set a property on an endpoint we don't own", @"SnoizeMIDI", [self bundle], "exception if someone tries to set a property on an endpoint we don't own")];
    }
}

- (void)_postRemovedNotification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMEndpointDisappearedNotification object:self];
}

- (void)_postReplacedNotificationWithReplacement:(SMEndpoint *)replacement;
{
    NSDictionary *userInfo;
    
    OBASSERT(replacement != NULL);
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:replacement, SMEndpointReplacement, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMEndpointWasReplacedNotification object:self userInfo:userInfo];
}

- (void)_postAddedNotification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMEndpointWasAddedNotification object:self];
}

@end


@implementation SMSourceEndpoint

static NSMapTable *sourceEndpointRefToSMEndpointMapTable = NULL;

+ (void)didLoad
{
    [self _earlyMIDISetup];
}

+ (NSMapTable **)_endpointMapTablePtr;
{
    return &sourceEndpointRefToSMEndpointMapTable;
}

+ (ItemCount)_endpointCount;
{
    return MIDIGetNumberOfSources();
}

+ (MIDIEndpointRef)_endpointAtIndex:(ItemCount)index;
{
    return MIDIGetSource(index);
}

+ (ItemCount)_endpointCountForEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetNumberOfSources(entity);
}

+ (MIDIEndpointRef)_endpointAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetSource(entity, index);
}


+ (NSArray *)sourceEndpoints;
{
    return [self _allEndpoints];
}

+ (SMSourceEndpoint *)sourceEndpointWithUniqueID:(SInt32)aUniqueID;
{
    return (SMSourceEndpoint *)[self _endpointMatchingUniqueID:aUniqueID];
}

+ (SMSourceEndpoint *)sourceEndpointWithEndpointRef:(MIDIEndpointRef)anEndpointRef;
{
    return (SMSourceEndpoint *)[self _endpointForEndpointRef:anEndpointRef];
}

@end


@implementation SMDestinationEndpoint

static NSMapTable *destinationEndpointRefToSMEndpointMapTable = NULL;

+ (void)didLoad
{
    [self _earlyMIDISetup];
}

+ (NSMapTable **)_endpointMapTablePtr;
{
    return &destinationEndpointRefToSMEndpointMapTable;
}

+ (ItemCount)_endpointCount;
{
    return MIDIGetNumberOfDestinations();
}

+ (MIDIEndpointRef)_endpointAtIndex:(ItemCount)index;
{
    return MIDIGetDestination(index);
}

+ (ItemCount)_endpointCountForEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetNumberOfDestinations(entity);
}

+ (MIDIEndpointRef)_endpointAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetDestination(entity, index);
}


+ (NSArray *)destinationEndpoints;
{
    return [self _allEndpoints];
}

+ (SMDestinationEndpoint *)destinationEndpointWithUniqueID:(SInt32)aUniqueID;
{
    return (SMDestinationEndpoint *)[self _endpointMatchingUniqueID:aUniqueID];
}

+ (SMDestinationEndpoint *)destinationEndpointWithEndpointRef:(MIDIEndpointRef)anEndpointRef;
{
    return (SMDestinationEndpoint *)[self _endpointForEndpointRef:anEndpointRef];
}

@end
