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

// Subclasses must implement these methods so all instances of a their kind of MIDIObject can be found.
+ (MIDIObjectType)midiObjectType;
    // Returns the CoreMIDI MIDIObjectType corresponding to this subclass
+ (ItemCount)midiObjectCount;
    // Returns the number of this kind of MIDIObjectRef that are available
+ (MIDIObjectRef)midiObjectAtIndex:(ItemCount)index;
    // Returns the MIDIObjectRef with this index

// Accessors for all objects of this type

+ (NSArray *)allObjects;
+ (NSArray *)allObjectsInOrder;
+ (SMMIDIObject *)objectWithUniqueID:(MIDIUniqueID)aUniqueID;
+ (SMMIDIObject *)objectWithName:(NSString *)aName;
+ (SMMIDIObject *)objectWithObjectRef:(MIDIObjectRef)anObjectRef;
    // NOTE: All of these methods do nothing in the base class. They work for subclasses of SMMIDIObject only.

// Generate a new unique ID

+ (MIDIUniqueID)generateNewUniqueID;

// Single object creation and accessors

- (id)initWithObjectRef:(MIDIObjectRef)anObjectRef ordinal:(unsigned int)anOrdinal;
- (MIDIObjectRef)objectRef;

- (unsigned int)ordinal;
- (void)setOrdinal:(unsigned int)value;

// Specific property access

- (MIDIUniqueID)uniqueID;
- (BOOL)setUniqueID:(MIDIUniqueID)value;
    // Returns whether or not the set succeeded

- (NSString *)name;
- (void)setName:(NSString *)value;
    // Raises an exception on error

- (BOOL)isOffline;
- (BOOL)isOnline;

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

- (void)propertyDidChange:(NSString *)propertyName;
    // Called when a property of this object changes. Subclasses may override (be sure to call super's implementation).

@end


// Notifications

extern NSString *SMMIDIObjectsAppearedNotification;
// object is the class that has new objects
// userInfo has an array of the new objects under key SMMIDIObjectsThatAppeared
extern NSString *SMMIDIObjectsThatAppeared;

extern NSString *SMMIDIObjectDisappearedNotification;
// object is the object that disappeared

extern NSString *SMMIDIObjectWasReplacedNotification;
// object is the object that was replaced
// userInfo contains new object under key SMMIDIObjectReplacement
extern NSString *SMMIDIObjectReplacement;

extern NSString *SMMIDIObjectListChangedNotification;
// object is the class that has either gained new objects or lost old ones
// This notification is sent last, after the appeared/disappeared/wasReplaced notifications.
