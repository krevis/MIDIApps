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
    return [[self allExternalDevices] sortedArrayUsingFunction:midiObjectOrdinalComparator context:NULL];
}

+ (SMExternalDevice *)externalDeviceWithUniqueID:(MIDIUniqueID)aUniqueID;
{
    // TODO We may want to change this to use MIDIObjectFindByUniqueID() where it is available (10.2 and greater).
    // However, I bet it's cheaper to look at the local list of unique IDs instead of making a roundtrip to the MIDIServer.
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
    if (!(self = [super initWithObjectRef:(MIDIObjectRef)aDeviceRef]))
        return nil;

    return self;
}

- (void)dealloc
{
    [super dealloc];
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

@end
