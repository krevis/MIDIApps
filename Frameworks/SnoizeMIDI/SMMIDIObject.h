#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


@interface SMMIDIObject : OFObject
{
    MIDIObjectRef objectRef;
    MIDIUniqueID uniqueID;
    unsigned int ordinal;

    struct {
        unsigned int hasCachedName:1;
    } flags;
    NSString *cachedName;
}

- (id)initWithObjectRef:(MIDIObjectRef)anObjectRef;

- (MIDIObjectRef)objectRef;

- (unsigned int)ordinal;
- (void)setOrdinal:(unsigned int)value;

// Specific property access

- (MIDIUniqueID)uniqueID;
- (void)setUniqueID:(MIDIUniqueID)value;
    // Does not raise on error, so check the value again afterwards if necessary

- (NSString *)name;
- (void)setName:(NSString *)value;
    // Raises an exception on error

// General property access

- (NSDictionary *)allProperties;

- (NSString *)stringForProperty:(CFStringRef)property;
    // Returns nil on error
- (void)setString:(NSString *)value forProperty:(CFStringRef)property;
    // Raises an exception on error

- (SInt32)integerForProperty:(CFStringRef)property;
    // Raises an exception on error
- (void)setInteger:(SInt32)value forProperty:(CFStringRef)property;
    // Raises an exception on error

// Other

- (void)checkIfPropertySetIsAllowed;
    // Does nothing in base class. May be overridden in subclasses to raise an exception if we shouldn't be setting values for properties of this object.

- (void)invalidateCachedProperties;
    // Call this to force this object to throw away any properties it may have cached.
    // Subclasses may want to override this.

- (void)updateUniqueID;
    // Call this if you believe this object's unique ID may have changed.

@end

// Other functions

extern int midiObjectOrdinalComparator(id object1, id object2, void *context);
    // Use for sorting arrays of MIDIObjects
