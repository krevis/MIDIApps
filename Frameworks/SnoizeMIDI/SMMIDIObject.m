#import "SMMIDIObject.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface SMMIDIObject (Private)

- (void)updateUniqueID;

@end


@implementation SMMIDIObject

- (id)initWithObjectRef:(MIDIObjectRef)anObjectRef;
{
    if (!(self = [super init]))
        return nil;

    OBPRECONDITION(anObjectRef != NULL);
    objectRef = anObjectRef;

    // Save the object's uniqueID, since it could become inaccessible later (if the object goes away).
    [self updateUniqueID];

    // Nothing has been cached yet
    flags.hasCachedName = NO;
    
    return self;
}

- (MIDIObjectRef)objectRef;
{
    return objectRef;
}

- (unsigned int)ordinal;
{
    return ordinal;
}

- (void)setOrdinal:(unsigned int)value;
{
    ordinal = value;
}

int midiObjectOrdinalComparator(id object1, id object2, void *context)
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

//
// Specific property access
//

- (MIDIUniqueID)uniqueID;
{
    return uniqueID;
}

- (void)setUniqueID:(MIDIUniqueID)value;
{
    OSStatus status;

    if (value == uniqueID)
        return;

    [self checkIfPropertySetIsAllowed];

    status = MIDIObjectSetIntegerProperty(objectRef, kMIDIPropertyUniqueID, value);
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
        // Make sure we read it back from the MIDIServer next time, just in case our change did not stick
    }
}

//
// General property access
//

- (id)allProperties;
{
    id propertyList;

    if (noErr != MIDIObjectGetProperties(objectRef, (CFPropertyListRef *)&propertyList, NO /* not deep */))
        propertyList = nil;

    return [propertyList autorelease];
}

- (NSString *)stringForProperty:(CFStringRef)property;
{
    NSString *string;

    if (noErr == MIDIObjectGetStringProperty(objectRef, property, (CFStringRef *)&string))
        return [string autorelease];
    else
        return nil;
}

- (void)setString:(NSString *)value forProperty:(CFStringRef)property;
{
    OSStatus status;

    [self checkIfPropertySetIsAllowed];

    status = MIDIObjectSetStringProperty(objectRef, property, (CFStringRef)value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't set object's property '%@' to '%@' (error %ld)", @"SnoizeMIDI", [self bundle], "exception with property, value string, and OSStatus if setting object's property fails"), property, value, status];
    }
}

- (SInt32)integerForProperty:(CFStringRef)property;
{
    OSStatus status;
    SInt32 value;

    status = MIDIObjectGetIntegerProperty(objectRef, property, &value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't get object's property '%@' (error %ld)", @"SnoizeMIDI", [self bundle], "exception with property and OSStatus if getting object's property fails"), property, status];
    }

    return value;
}

- (void)setInteger:(SInt32)value forProperty:(CFStringRef)property;
{
    OSStatus status;

    [self checkIfPropertySetIsAllowed];

    status = MIDIObjectSetIntegerProperty(objectRef, property, value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't set object's property '%@' to %ld (error %ld)", @"SnoizeMIDI", [self bundle], "exception with property, SInt32, and OSStatus if setting object's property fails"), property, status];
    }
}

//
// Other
//

- (void)checkIfPropertySetIsAllowed;
{
    // Do nothing in base class
}

- (void)invalidateCachedProperties;
{
    flags.hasCachedName = NO;
}

- (void)updateUniqueID;
{
    if (noErr != MIDIObjectGetIntegerProperty(objectRef, kMIDIPropertyUniqueID, &uniqueID))
        uniqueID = 0;
}

@end
