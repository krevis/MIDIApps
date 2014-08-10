/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


@interface SMMIDIObject : NSObject
{
    MIDIObjectRef objectRef;
    MIDIUniqueID uniqueID;
    NSUInteger ordinal;

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

- (id)initWithObjectRef:(MIDIObjectRef)anObjectRef ordinal:(NSUInteger)anOrdinal;
- (MIDIObjectRef)objectRef;

- (NSUInteger)ordinal;
- (void)setOrdinal:(NSUInteger)value;

// Specific property access

- (MIDIUniqueID)uniqueID;
- (BOOL)setUniqueID:(MIDIUniqueID)value;
    // Returns whether or not the set succeeded

- (NSString *)name;
- (void)setName:(NSString *)value;
    // Raises an exception on error

- (BOOL)isOffline;
- (BOOL)isOnline;

- (int)maxSysExSpeed;
- (void)setMaxSysExSpeed:(int)value;
    // Maximum SysEx speed in bytes/second


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
    // Posts the notification SMMIDIObjectPropertyChangedNotification.

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

extern NSString *SMMIDIObjectPropertyChangedNotification;
// object is the object whose property changed
// userInfo contains changed property's name under key SMMIDIObjectChangedPropertyName
extern NSString *SMMIDIObjectChangedPropertyName;
