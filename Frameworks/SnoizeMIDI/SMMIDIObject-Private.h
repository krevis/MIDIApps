//
// Methods that are present on SMMIDIObject, but are for use only by SMMIDIObject subclasses,
// not by all clients of the SnoizeMIDI framework.
//

@interface SMMIDIObject (FrameworkPrivate)

// Sent to each subclass when the first MIDI Client is created.
+ (void)initialMIDISetup;

// Subclasses may use this method to immediately cause a new object to be created from a MIDIObjectRef
// (instead of doing it when CoreMIDI sends a notification).
// Should be sent only to SMMIDIObject subclasses, not to SMMIDIObject itself.
+ (SMMIDIObject *)immediatelyAddObjectWithObjectRef:(MIDIObjectRef)anObjectRef;

// Similarly, subclasses may use this method to immediately cause an object to be removed from the list
// of SMMIDIObjects of this subclass, instead of waiting for CoreMIDI to send a notification.
// Should be sent only to SMMIDIObject subclasses, not to SMMIDIObject itself.
+ (void)immediatelyRemoveObject:(SMMIDIObject *)object;

// Refresh all SMMIDIObjects of this subclass.
// Should be sent only to SMMIDIObject subclasses, not to SMMIDIObject itself.
+ (void)refreshAllObjects;

@end
