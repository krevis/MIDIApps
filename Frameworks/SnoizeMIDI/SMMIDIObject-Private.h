/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


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

// Post a notification stating that the list of available objects of this kind of SMMIDIObject has changed.
// Should be sent only to SMMIDIObject subclasses, not to SMMIDIObject itself.
+ (void)postObjectListChangedNotification;

// Post a notification stating that an object of this kind of SMMIDIObject has been added.
// Should be sent only to SMMIDIObject subclasses, not to SMMIDIObject itself.
+ (void)postObjectsAddedNotificationWithObjects:(NSArray*)objects;

@end
