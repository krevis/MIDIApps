//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMEndpoint.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMExternalDevice.h"


@interface SMEndpoint (Private)

typedef struct EndpointUniqueNamesFlags {
    unsigned int areNamesUnique:1;
    unsigned int haveNamesAlwaysBeenUnique:1;
} EndpointUniqueNamesFlags;

+ (void)earlyMIDISetup;
+ (void)midiClientCreate:(NSNotification *)notification;
+ (void)midiSetupChanged:(NSNotification *)notification;

+ (NSMapTable **)endpointMapTablePtr;
+ (EndpointUniqueNamesFlags *)endpointUniqueNamesFlagsPtr;
+ (ItemCount)endpointCount;
+ (MIDIEndpointRef)endpointAtIndex:(ItemCount)index;
+ (ItemCount)endpointCountForEntity:(MIDIEntityRef)entity;
+ (MIDIEndpointRef)endpointAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;

+ (void)reloadEndpoints;
+ (NSArray *)allEndpoints;
+ (NSArray *)allEndpointsSortedByOrdinal;
+ (SMEndpoint *)endpointMatchingUniqueID:(SInt32)uniqueID;
+ (SMEndpoint *)endpointMatchingName:(NSString *)aName;
+ (SMEndpoint *)endpointForEndpointRef:(MIDIEndpointRef)anEndpointRef;

+ (BOOL)doEndpointsHaveUniqueNames;
+ (BOOL)haveEndpointsAlwaysHadUniqueNames;
+ (void)checkForUniqueNames;

- (void)updateUniqueID;
- (void)invalidateCachedProperties;

- (MIDIDeviceRef)findDevice;
- (MIDIDeviceRef)device;
- (NSString *)deviceName;
- (NSString *)deviceStringForProperty:(CFStringRef)property;

- (SInt32)ownerPID;
- (void)setOwnerPID:(SInt32)value;

- (NSString *)stringForProperty:(CFStringRef)property;
- (void)setString:(NSString *)value forProperty:(CFStringRef)property;

- (SInt32)integerForProperty:(CFStringRef)property;
- (void)setInteger:(SInt32)value forProperty:(CFStringRef)property;

- (void)setOrdinal:(unsigned int)value;
- (unsigned int)ordinal;
static int endpointOrdinalComparator(id endpoint1, id endpoint2, void *context);

- (void)checkIfPropertySetIsAllowed;

- (void)postRemovedNotification;
- (void)postReplacedNotificationWithReplacement:(SMEndpoint *)replacement;

@end


@implementation SMEndpoint

NSString *SMEndpointsAppearedNotification = @"SMEndpointsAppearedNotification";
NSString *SMEndpointDisappearedNotification = @"SMEndpointDisappearedNotification";
NSString *SMEndpointWasReplacedNotification = @"SMEndpointWasReplacedNotification";
NSString *SMEndpointReplacement = @"SMEndpointReplacement";

NSString *SMEndpointPropertyOwnerPID = @"SMEndpointPropertyOwnerPID";


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
    [self updateUniqueID];

    // We start out not knowing the endpoint's device (if it has one). We'll look it up on demand.
    deviceRef = NULL;
    flags.hasLookedForDevice = NO;

    // Nothing has been cached yet 
    flags.hasCachedName = NO;
    flags.hasCachedManufacturerName = NO;
    flags.hasCachedModelName = NO;
    flags.hasCachedDeviceName = NO;

    return self;
}

- (void)dealloc;
{
    if (endpointRef && [self isOwnedByThisProcess])
        MIDIEndpointDispose(endpointRef);
    
    [cachedName release];
    cachedName = nil;
    [cachedManufacturerName release];
    cachedManufacturerName = nil;
    [cachedModelName release];
    cachedModelName = nil;
    [cachedDeviceName release];
    cachedDeviceName = nil;

    [super dealloc];
}

- (MIDIEndpointRef)endpointRef;
{
    return endpointRef;
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
    if (![self isOwnedByThisProcess])
        return;

    MIDIEndpointDispose(endpointRef);
    endpointRef = NULL;
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

    [self checkIfPropertySetIsAllowed];

    status = MIDIObjectSetIntegerProperty(endpointRef, kMIDIPropertyUniqueID, value);
    if (status) {
        // Ignore failure... not sure if this is the right thing to do or not.
    }

    // Refresh our idea of the unique ID since it may or may not have changed
    [self updateUniqueID];
}

- (NSString *)name;
{
    if (!flags.hasCachedName) {
        [cachedName release];
        cachedName = [[self stringForProperty:kMIDIPropertyName] retain];
        flags.hasCachedName = YES;
    }
    
    return cachedName;
}

- (void)setName:(NSString *)value;
{
    if (![value isEqualToString:[self name]]) {
        [self setString:value forProperty:kMIDIPropertyName];
        flags.hasCachedName = NO;
    }
}

- (NSString *)manufacturerName;
{
    if (!flags.hasCachedManufacturerName) {
        [cachedManufacturerName release];

        cachedManufacturerName = [self stringForProperty:kMIDIPropertyManufacturer];
        // NOTE This fails sometimes on 10.1.3 and earlier (see bug #2865704).
        // So we fall back to asking for the device's manufacturer name if necessary.
        // (This bug is fixed in 10.1.5.)
        if (!cachedManufacturerName)
            cachedManufacturerName = [self deviceStringForProperty:kMIDIPropertyManufacturer];

        [cachedManufacturerName retain];
        flags.hasCachedManufacturerName = YES;        
    }

    return cachedManufacturerName;
}

- (void)setManufacturerName:(NSString *)value;
{
    if (![value isEqualToString:[self manufacturerName]]) {
        [self setString:value forProperty:kMIDIPropertyManufacturer];
        flags.hasCachedManufacturerName = NO;
    }
}

- (NSString *)modelName;
{
    if (!flags.hasCachedModelName) {
        [cachedModelName release];
        cachedModelName = [[self stringForProperty:kMIDIPropertyModel] retain];

        flags.hasCachedModelName = YES;
    }

    return cachedModelName;
}

- (void)setModelName:(NSString *)value;
{
    if (![value isEqualToString:[self modelName]]) {
        [self setString:value forProperty:kMIDIPropertyModel];
        flags.hasCachedModelName = NO;
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

- (id)allProperties;
{
    id propertyList;

    if (noErr != MIDIObjectGetProperties(endpointRef, (CFPropertyListRef *)&propertyList, NO /* not deep */))
        propertyList = nil;

    return [propertyList autorelease];
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
{
    // TODO kMIDIPropertyImage is new to 10.2, so we need to conditionalize this so we can still build and run on 10.1.
    // The value of kMIDIPropertyImage is @"image".
    return [self stringForProperty:kMIDIPropertyImage];
}

- (NSArray *)uniqueIDsOfConnectedThings;
{
    SInt32 oneUniqueID;
    NSData *data;

    // The property for kMIDIPropertyConnectionUniqueID may be an integer or a data object.
    // Try getting it as data first.  (The data is an array of big-endian SInt32s.)
    if (noErr == MIDIObjectGetDataProperty(endpointRef, kMIDIPropertyConnectionUniqueID, (CFDataRef *)&data)) {
        unsigned int dataLength = [data length];
        unsigned int count;
        const SInt32 *p, *end;
        NSMutableArray *array;
        
        // Make sure the data length makes sense
        if (dataLength % sizeof(SInt32) != 0)
            return [NSArray array];

        count = dataLength / sizeof(SInt32);
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
    if (noErr == MIDIObjectGetIntegerProperty(endpointRef, kMIDIPropertyConnectionUniqueID, &oneUniqueID)) {
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
        SInt32 aUniqueID = [[uniqueIDs objectAtIndex:uniqueIDIndex] longValue];
        SMExternalDevice *extDevice;

        extDevice = [SMExternalDevice externalDeviceWithUniqueID:aUniqueID];
        if (extDevice)
            [externalDevices addObject:extDevice];
    }    

    return externalDevices;
}

@end


@implementation SMEndpoint (Private)

+ (void)earlyMIDISetup;
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(midiClientCreate:) name:SMClientCreatedInternalNotification object:nil];
}

+ (void)midiClientCreate:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(midiSetupChanged:) name:SMClientSetupChangedInternalNotification object:[SMClient sharedClient]];
    [self midiSetupChanged:nil];
}

+ (void)midiSetupChanged:(NSNotification *)notification
{
    [self reloadEndpoints];
}

+ (NSMapTable **)endpointMapTablePtr;
{
    OBRequestConcreteImplementation(self, _cmd);
    return NULL;
}

+ (EndpointUniqueNamesFlags *)endpointUniqueNamesFlagsPtr;
{
    OBRequestConcreteImplementation(self, _cmd);
    return NULL;
}

+ (ItemCount)endpointCount;
{
    OBRequestConcreteImplementation(self, _cmd);
    return 0;
}

+ (MIDIEndpointRef)endpointAtIndex:(ItemCount)index;
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

+ (NSArray *)allEndpoints;
{
    NSMapTable **mapTablePtr;

    mapTablePtr = [self endpointMapTablePtr];
    OBASSERT(mapTablePtr);

    if (*mapTablePtr)
        return NSAllMapTableValues(*mapTablePtr);
    else
        return nil;
}

+ (NSArray *)allEndpointsSortedByOrdinal;
{
    return [[self allEndpoints] sortedArrayUsingFunction:endpointOrdinalComparator context:NULL];
}

+ (SMEndpoint *)endpointMatchingUniqueID:(SInt32)aUniqueID;
{
    NSArray *allEndpoints;
    unsigned int endpointIndex;

    allEndpoints = [self allEndpoints];
    endpointIndex = [allEndpoints count];
    while (endpointIndex--) {
        SMEndpoint *endpoint;

        endpoint = [allEndpoints objectAtIndex:endpointIndex];
        if ([endpoint uniqueID] == aUniqueID)
            return endpoint;
    }

    return nil;
}

+ (SMEndpoint *)endpointMatchingName:(NSString *)aName;
{
    NSArray *allEndpoints;
    unsigned int endpointIndex;

    if (!aName)
        return nil;

    allEndpoints = [self allEndpoints];
    endpointIndex = [allEndpoints count];
    while (endpointIndex--) {
        SMEndpoint *endpoint;

        endpoint = [allEndpoints objectAtIndex:endpointIndex];
        if ([[endpoint name] isEqualToString:aName])
            return endpoint;
    }

    return nil;
}

+ (SMEndpoint *)endpointForEndpointRef:(MIDIEndpointRef)anEndpointRef;
{
    NSMapTable **mapTablePtr;

    mapTablePtr = [self endpointMapTablePtr];
    OBASSERT(mapTablePtr);

    if (*mapTablePtr)
        return NSMapGet(*mapTablePtr, anEndpointRef);
    else
        return nil;        
}

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

    endpoints = [self allEndpoints];
    nameArray = [endpoints arrayByPerformingSelector:@selector(name)];
    nameSet = [NSSet setWithArray:nameArray];

    areNamesUnique = ([nameArray count] == [nameSet count]);

    flagsPtr = [self endpointUniqueNamesFlagsPtr];
    flagsPtr->areNamesUnique = areNamesUnique;
    flagsPtr->haveNamesAlwaysBeenUnique = flagsPtr->haveNamesAlwaysBeenUnique && areNamesUnique;
}

- (void)updateUniqueID;
{
    if (noErr != MIDIObjectGetIntegerProperty(endpointRef, kMIDIPropertyUniqueID, &uniqueID))
        uniqueID = 0;
}

- (void)invalidateCachedProperties;
{
    flags.hasLookedForDevice = NO;
    flags.hasCachedName = NO;
    flags.hasCachedManufacturerName = NO;
    flags.hasCachedModelName = NO;
    flags.hasCachedDeviceName = NO;
}

- (MIDIDeviceRef)findDevice;
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
            endpointCount = [[self class] endpointCountForEntity:entity];
            for (endpointIndex = 0; endpointIndex < endpointCount; endpointIndex++) {
                MIDIEndpointRef thisEndpoint;
                
                thisEndpoint = [[self class] endpointAtIndex:endpointIndex forEntity:entity];
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

- (MIDIDeviceRef)device;
{
    if (!flags.hasLookedForDevice) {
        deviceRef = [self findDevice];
        flags.hasLookedForDevice = YES;
    }

    return deviceRef;
}

- (NSString *)deviceName;
{
    if (!flags.hasCachedDeviceName) {
        [cachedDeviceName release];
        cachedDeviceName = [[self deviceStringForProperty:kMIDIPropertyName] retain];

        flags.hasCachedDeviceName = YES;        
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
    OSStatus status;
    SInt32 ownerPID;

    status = MIDIObjectGetIntegerProperty(endpointRef, (CFStringRef)SMEndpointPropertyOwnerPID, &ownerPID);
    if (status)
        return 0;
    else
        return ownerPID;
}

- (void)setOwnerPID:(SInt32)value;
{
    OSStatus status;
    
    status = MIDIObjectSetIntegerProperty(endpointRef, (CFStringRef)SMEndpointPropertyOwnerPID, value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't set owner PID on endpoint: error %ld", @"SnoizeMIDI", [self bundle], "exception with OSStatus if setting endpoint's owner PID fails"), status];
    }
}

- (NSString *)stringForProperty:(CFStringRef)property;
{
    NSString *string;
    
    if (noErr == MIDIObjectGetStringProperty(endpointRef, property, (CFStringRef *)&string))
        return [string autorelease];
    else
        return nil;
}

- (void)setString:(NSString *)value forProperty:(CFStringRef)property;
{
    OSStatus status;
    
    [self checkIfPropertySetIsAllowed];

    status = MIDIObjectSetStringProperty(endpointRef, property, (CFStringRef)value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't set endpoint's property %@ (error %ld)", @"SnoizeMIDI", [self bundle], "exception with property and OSStatus if setting endpoint's property fails"), property, status];
    }
}

- (SInt32)integerForProperty:(CFStringRef)property;
{
    OSStatus status;
    SInt32 value;
    
    status = MIDIObjectGetIntegerProperty(endpointRef, property, &value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't get endpoint's property %@ (error %ld)", @"SnoizeMIDI", [self bundle], "exception with property and OSStatus if getting endpoint's property fails"), property, status];
    }
    
    return value;    
}

- (void)setInteger:(SInt32)value forProperty:(CFStringRef)property;
{
    OSStatus status;

    [self checkIfPropertySetIsAllowed];
    
    status = MIDIObjectSetIntegerProperty(endpointRef, property, value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't set endpoint's property %@ (error %ld)", @"SnoizeMIDI", [self bundle], "exception with property and OSStatus if setting endpoint's property fails"), property, status];
    }
}

- (void)setOrdinal:(unsigned int)value;
{
    ordinal = value;
}

- (unsigned int)ordinal;
{
    return ordinal;
}

static int endpointOrdinalComparator(id object1, id object2, void *context)
{
    unsigned int ordinal1, ordinal2;

    ordinal1 = [object1 ordinal];
    ordinal2 = [object2 ordinal];
        
    if (ordinal1 > ordinal2)
        return NSOrderedDescending;
    else if (ordinal1 == ordinal2)
        return NSOrderedSame;
    else
        return NSOrderedAscending;
}

- (void)checkIfPropertySetIsAllowed;
{
    if (![self isOwnedByThisProcess]) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Can't set a property on an endpoint we don't own", @"SnoizeMIDI", [self bundle], "exception if someone tries to set a property on an endpoint we don't own")];
    }
}

- (void)postRemovedNotification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMEndpointDisappearedNotification object:self];
}

- (void)postReplacedNotificationWithReplacement:(SMEndpoint *)replacement;
{
    NSDictionary *userInfo;
    
    OBASSERT(replacement != NULL);
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:replacement, SMEndpointReplacement, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMEndpointWasReplacedNotification object:self userInfo:userInfo];
}

@end


@implementation SMSourceEndpoint

static NSMapTable *sourceEndpointRefToSMEndpointMapTable = NULL;
static EndpointUniqueNamesFlags sourceEndpointUniqueNamesFlags = { YES, YES };

+ (void)didLoad
{
    [self earlyMIDISetup];
}

+ (NSMapTable **)endpointMapTablePtr;
{
    return &sourceEndpointRefToSMEndpointMapTable;
}

+ (EndpointUniqueNamesFlags *)endpointUniqueNamesFlagsPtr;
{
    return &sourceEndpointUniqueNamesFlags;
}

+ (ItemCount)endpointCount;
{
    return MIDIGetNumberOfSources();
}

+ (MIDIEndpointRef)endpointAtIndex:(ItemCount)index;
{
    return MIDIGetSource(index);
}

+ (ItemCount)endpointCountForEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetNumberOfSources(entity);
}

+ (MIDIEndpointRef)endpointAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetSource(entity, index);
}


+ (NSArray *)sourceEndpoints;
{
    return [self allEndpointsSortedByOrdinal];
}

+ (SMSourceEndpoint *)sourceEndpointWithUniqueID:(SInt32)aUniqueID;
{
    return (SMSourceEndpoint *)[self endpointMatchingUniqueID:aUniqueID];
}

+ (SMSourceEndpoint *)sourceEndpointWithName:(NSString *)aName;
{
    return (SMSourceEndpoint *)[self endpointMatchingName:aName];
}

+ (SMSourceEndpoint *)sourceEndpointWithEndpointRef:(MIDIEndpointRef)anEndpointRef;
{
    return (SMSourceEndpoint *)[self endpointForEndpointRef:anEndpointRef];
}

+ (SMSourceEndpoint *)createVirtualSourceEndpointWithName:(NSString *)newName uniqueID:(SInt32)newUniqueID;
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

    [self reloadEndpoints];

    // And try to get the new endpoint
    endpoint = [SMSourceEndpoint sourceEndpointWithEndpointRef:newEndpointRef];
    if (!endpoint) 
        return nil;

    [endpoint setIsOwnedByThisProcess];
    [endpoint setUniqueID:newUniqueID];
    [endpoint setManufacturerName:@"Snoize"];

    // Do this before the last modification, so one setup change notification will still happen
    [client setPostsExternalSetupChangeNotification:wasPostingExternalNotification];

    [endpoint setModelName:[client name]];

    return endpoint;
}


- (NSString *)inputStreamSourceName;
{
    return [self uniqueName];
}

- (NSNumber *)inputStreamSourceUniqueID;
{
    return [NSNumber numberWithInt:[self uniqueID]];
}

@end


@implementation SMDestinationEndpoint

static NSMapTable *destinationEndpointRefToSMEndpointMapTable = NULL;
static EndpointUniqueNamesFlags destinationEndpointUniqueNamesFlags = { YES, YES };

+ (void)didLoad
{
    [self earlyMIDISetup];
}

+ (NSMapTable **)endpointMapTablePtr;
{
    return &destinationEndpointRefToSMEndpointMapTable;
}

+ (EndpointUniqueNamesFlags *)endpointUniqueNamesFlagsPtr;
{
    return &destinationEndpointUniqueNamesFlags;
}

+ (ItemCount)endpointCount;
{
    return MIDIGetNumberOfDestinations();
}

+ (MIDIEndpointRef)endpointAtIndex:(ItemCount)index;
{
    return MIDIGetDestination(index);
}

+ (ItemCount)endpointCountForEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetNumberOfDestinations(entity);
}

+ (MIDIEndpointRef)endpointAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;
{
    return MIDIEntityGetDestination(entity, index);
}


+ (NSArray *)destinationEndpoints;
{
    return [self allEndpointsSortedByOrdinal];
}

+ (SMDestinationEndpoint *)destinationEndpointWithUniqueID:(SInt32)aUniqueID;
{
    return (SMDestinationEndpoint *)[self endpointMatchingUniqueID:aUniqueID];
}

+ (SMDestinationEndpoint *)destinationEndpointWithName:(NSString *)aName;
{
    return (SMDestinationEndpoint *)[self endpointMatchingName:aName];
}

+ (SMDestinationEndpoint *)destinationEndpointWithEndpointRef:(MIDIEndpointRef)anEndpointRef;
{
    return (SMDestinationEndpoint *)[self endpointForEndpointRef:anEndpointRef];
}

+ (SMDestinationEndpoint *)createVirtualDestinationEndpointWithName:(NSString *)endpointName readProc:(MIDIReadProc)readProc readProcRefCon:(void *)readProcRefCon uniqueID:(SInt32)newUniqueID
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

    [self reloadEndpoints];

    endpoint = [SMDestinationEndpoint destinationEndpointWithEndpointRef:newEndpointRef];
    if (!endpoint)
        return nil;

    [endpoint setIsOwnedByThisProcess];
    [endpoint setUniqueID:newUniqueID];
    [endpoint setManufacturerName:@"Snoize"];

    // Do this before the last modification, so one setup change notification will still happen
    [client setPostsExternalSetupChangeNotification:wasPostingExternalNotification];

    [endpoint setModelName:[client name]];

    return endpoint;
}

@end
