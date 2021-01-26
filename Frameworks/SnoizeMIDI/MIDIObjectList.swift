/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import CoreMIDI

class MIDIObjectList<T: CoreMIDIObjectListable & CoreMIDIPropertyChangeHandling>: CoreMIDIObjectList {

    init(_ context: CoreMIDIContext) {
        self.context = context

        // Populate our object wrappers
        T.fetchMIDIObjectRefs(context).forEach {
            _ = addObject($0)
        }
    }

    // MARK: CoreMIDIObjectList implementation

    var midiObjectType: MIDIObjectType { T.midiObjectType }

    func objectPropertyChanged(midiObjectRef: MIDIObjectRef, property: CFString) {
        if let object = objectMap[midiObjectRef] {
            object.midiPropertyChanged(property)
            T.postObjectPropertyChangedNotification(object, property)
        }
    }

    func objectWasAdded(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType) {
        if let addedObject = addObject(midiObjectRef) {
            // The objects' ordering may have changed, so refresh it
            refreshOrdering(T.fetchMIDIObjectRefs(context))

            T.postObjectsAddedNotification([addedObject])
            T.postObjectListChangedNotification()
        }
    }

    func objectWasRemoved(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType) {
        if let removedObject = removeObject(midiObjectRef) {
            T.postObjectRemovedNotification(removedObject)
            T.postObjectListChangedNotification()
        }
    }

    func updateList() {
        // We start out assuming all objects have been removed, none have been replaced.
        // As we find out otherwise, we remove some endpoints from removedObjects,
        // and add some to addedObjects and replacements.

        var removedObjects: [T] = orderedObjects
        var addedObjects: [T] = []
        var replacements: [(original: T, replacement: T)] = []

        func objectWasNotRemoved(_ object: T) {
            if let index = removedObjects.firstIndex(where: { $0 == object }) {
                removedObjects.remove(at: index)
            }
        }

        var newObjectMap: [MIDIObjectRef: T] = [:]

        let newObjectRefs = T.fetchMIDIObjectRefs(context)
        for objectRef in newObjectRefs {
            if let existing = objectMap[objectRef] {
                // This objectRef has an existing wrapper object.
                objectWasNotRemoved(existing)

                // It's possible that any of its properties changed, though
                // (including the uniqueID).
                existing.invalidateCachedProperties()

                newObjectMap[objectRef] = existing
            }
            else {
                // This objectRef does not have an existing wrapper; make one.
                if let new = createObject(objectRef) {
                    // If the new object has the same uniqueID as an old object,
                    // that's a replacement that needs a special notification.
                    if let original = findObject(uniqueID: new.uniqueID) {
                        objectWasNotRemoved(original)
                        replacements.append((original: original, replacement: new))
                    }
                    else {
                        addedObjects.append(new)
                    }

                    newObjectMap[objectRef] = new
                }
            }
        }

        objectMap = newObjectMap
        refreshOrdering(newObjectRefs)

        // Everything is in place, so post notifications depending on what changed.

        if !addedObjects.isEmpty {
            T.postObjectsAddedNotification(addedObjects)
        }
        removedObjects.forEach {
            T.postObjectRemovedNotification($0)
        }
        for (original, replacement) in replacements {
            T.postObjectReplacedNotification(original: original, replacement: replacement)
        }
        if !addedObjects.isEmpty || !removedObjects.isEmpty || !replacements.isEmpty {
            T.postObjectListChangedNotification()
        }
    }

    // MARK: Additional API

    var objects: [T] {
        orderedObjects
    }

    func findObject(objectRef: MIDIObjectRef) -> T? {
        objectMap[objectRef]
    }

    func findObject(uniqueID: MIDIUniqueID) -> T? {
        objectMap.values.first { $0.uniqueID == uniqueID }
    }

    // MARK: Private

    private unowned let context: CoreMIDIContext

    private var objectMap: [MIDIObjectRef: T] = [:]
    private var orderedObjects: [T] = []

    private func createObject(_ midiObjectRef: MIDIObjectRef) -> T? {
        guard midiObjectRef != 0,
              objectMap[midiObjectRef] == nil
        else { return nil }

        return T.init(context: context, objectRef: midiObjectRef)
    }

    private func addObject(_ midiObjectRef: MIDIObjectRef) -> T? {
        let possibleObject = createObject(midiObjectRef)

        if let addedObject = possibleObject {
            objectMap[midiObjectRef] = addedObject
            orderedObjects.append(addedObject)
        }

        return possibleObject
    }

    private func removeObject(_ midiObjectRef: MIDIObjectRef) -> T? {
        guard midiObjectRef != 0,
              let removedObject = objectMap[midiObjectRef]
        else { return nil }

        objectMap.removeValue(forKey: midiObjectRef)
        if let index = orderedObjects.firstIndex(where: { $0 == removedObject }) {
            orderedObjects.remove(at: index)
        }

        return removedObject
    }

    private func refreshOrdering(_ objectRefs: [MIDIObjectRef]) {
        // TODO This should perhaps just invalidate the ordering, so it can
        // be recomputed it the next time somebody asks for it

        var newOrdering: [T] = []
        for objectRef in objectRefs {
            if let object = objectMap[objectRef] {
                newOrdering.append(object)
            }
            else {
                // We don't have this object yet. Perhaps it's being added and
                // we'll be notified about it later.
            }
        }

        // Similarly, it's possible there are objects in objectMap which
        // are no longer returned by CoreMIDI, but we haven't been notified
        // that they disappeared, yet. That's fine.

        orderedObjects = newOrdering
    }

}
