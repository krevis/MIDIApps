//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import "SMExternalDevice.h"
#import "SMClient.h"


@interface SMExternalDevice (Private)

+ (void)midiClientCreated:(NSNotification *)notification;
+ (void)midiSetupChanged:(NSNotification *)notification;

+ (NSArray *)allExternalDevices;
+ (void)reloadExternalDevices;

- (void)updateUniqueID;

- (NSString *)stringForProperty:(CFStringRef)property;

- (void)setOrdinal:(unsigned int)value;
- (unsigned int)ordinal;
static int externalDeviceOrdinalComparator(id object1, id object2, void *context);

@end


@implementation SMExternalDevice

static NSMapTable *staticExternalDevicesMapTable = nil;
    // Map table from MIDIDeviceRef to SMExternalDevice*

+ (void)didLoad
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(midiClientCreated:) name:SMClientCreatedInternalNotification object:nil];
}

+ (NSArray *)externalDevices;
{
    return [[self allExternalDevices] sortedArrayUsingFunction:externalDeviceOrdinalComparator context:NULL];
}

+ (SMExternalDevice *)externalDeviceWithUniqueID:(SInt32)aUniqueID;
{
    NSArray *allExtDevices;
    unsigned int extDeviceIndex;

    allExtDevices = [self allExternalDevices];
    extDeviceIndex = [allExtDevices count];
    while (extDeviceIndex--) {
        SMExternalDevice *extDevice;

        extDevice = [allExtDevices objectAtIndex:extDeviceIndex];
        if ([extDevice uniqueID] == aUniqueID)
            return extDevice;
    }

    return nil;
}

+ (SMExternalDevice *)externalDeviceWithDeviceRef:(MIDIDeviceRef)aDeviceRef;
{
    if (staticExternalDevicesMapTable)
        return NSMapGet(staticExternalDevicesMapTable, aDeviceRef);
    else
        return nil;
}

- (id)initWithDeviceRef:(MIDIDeviceRef)aDeviceRef;
{
    if (!(self = [super init]))
        return nil;

    if (!aDeviceRef) {
        [self release];
        return nil;
    }

    deviceRef = aDeviceRef;

    // Save the uniqueID, since it could become inaccessible later (if the ext. device goes away).
    [self updateUniqueID];
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (MIDIDeviceRef)deviceRef;
{
    return deviceRef;
}

- (SInt32)uniqueID;
{
    return uniqueID;
}

- (NSString *)name;
{
    return [self stringForProperty:kMIDIPropertyName];
}

- (NSString *)manufacturerName;
{
    return [self stringForProperty:kMIDIPropertyManufacturer];
}

- (NSString *)modelName;
{
    return [self stringForProperty:kMIDIPropertyModel];
}

- (NSDictionary *)allProperties;
{
    id propertyList;

    if (noErr != MIDIObjectGetProperties(deviceRef, (CFPropertyListRef *)&propertyList, NO /* not deep */))
        propertyList = nil;

    return [propertyList autorelease];    
}

- (NSString *)pathToImageFile;
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

@end


@implementation SMExternalDevice (Private)

+ (void)midiClientCreated:(NSNotification *)notification;
{
    // TODO look at listening to more specific MIDI setup changes instead of this general one
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(midiSetupChanged:) name:SMClientSetupChangedInternalNotification object:[SMClient sharedClient]];
    [self midiSetupChanged:nil];
}

+ (void)midiSetupChanged:(NSNotification *)notification;
{
    [self reloadExternalDevices];
}

+ (NSArray *)allExternalDevices;
{
    if (staticExternalDevicesMapTable)
        return NSAllMapTableValues(staticExternalDevicesMapTable);
    else
        return [NSArray array];
}

+ (void)reloadExternalDevices
{
    NSMapTable *oldMapTable, *newMapTable;
    ItemCount extDeviceCount, extDeviceIndex;
    NSMutableArray *removedDevices, *replacedDevices, *replacementDevices, *addedDevices;

    extDeviceCount = MIDIGetNumberOfExternalDevices();

    oldMapTable = staticExternalDevicesMapTable;
    newMapTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSObjectMapValueCallBacks, extDeviceCount);

    // We start out assuming all external devices have been removed, and none have been replaced.
    // As we find out otherwise, we remove some devices from removedDevices, and add some
    // to replacedDevices.
    removedDevices = [NSMutableArray arrayWithArray:[self externalDevices]];
    replacedDevices = [NSMutableArray array];
    replacementDevices = [NSMutableArray array];
    addedDevices = [NSMutableArray array];

    // Iterate through the new list of external devices.
    for (extDeviceIndex = 0; extDeviceIndex < extDeviceCount; extDeviceIndex++) {
        MIDIDeviceRef aDeviceRef;
        SMExternalDevice *extDevice;

        aDeviceRef = MIDIGetExternalDevice(extDeviceIndex);
        if (aDeviceRef == NULL)
            continue;

        if ((extDevice = [self externalDeviceWithDeviceRef:aDeviceRef])) {
            // This device existed previously.
            [removedDevices removeObjectIdenticalTo:extDevice];
            // It's possible that its uniqueID changed, though.
            [extDevice updateUniqueID];
            // And its ordinal may also have changed...
            [extDevice setOrdinal:extDeviceIndex];
        } else {
            SMExternalDevice *replacedDevice;

            // This MIDIDeviceRef did not previously exist, so create a new ext. device for it.
            extDevice = [[[self alloc] initWithDeviceRef:aDeviceRef] autorelease];
            [extDevice setOrdinal:extDeviceIndex];

            // If the new ext. device has the same uniqueID as an old ext. device, remember it.
            if ((replacedDevice = [self externalDeviceWithUniqueID:[extDevice uniqueID]])) {
                [replacedDevices addObject:replacedDevice];
                [replacementDevices addObject:extDevice];
                [removedDevices removeObjectIdenticalTo:replacedDevice];
            } else {
                [addedDevices addObject:extDevice];
            }
        }

        NSMapInsert(newMapTable, aDeviceRef, extDevice);
    }

    if (oldMapTable)
        NSFreeMapTable(oldMapTable);
    staticExternalDevicesMapTable = newMapTable;

    // TODO post notifications etc (see SMEndpoint version)
}

- (void)updateUniqueID;
{
    if (noErr != MIDIObjectGetIntegerProperty(deviceRef, kMIDIPropertyUniqueID, &uniqueID))
        uniqueID = 0;
}

- (NSString *)stringForProperty:(CFStringRef)property;
{
    NSString *string;

    if (noErr == MIDIObjectGetStringProperty(deviceRef, property, (CFStringRef *)&string))
        return [string autorelease];
    else
        return nil;
}

- (void)setOrdinal:(unsigned int)value;
{
    ordinal = value;
}

- (unsigned int)ordinal;
{
    return ordinal;
}

static int externalDeviceOrdinalComparator(id object1, id object2, void *context)
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

@end
