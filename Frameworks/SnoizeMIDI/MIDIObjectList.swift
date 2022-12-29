/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import CoreMIDI

class MIDIObjectList<T: CoreMIDIObjectListable & CoreMIDIPropertyChangeHandling>: CoreMIDIObjectList {

    init(_ context: CoreMIDIContext) {
        self.context = context

        // Populate our object wrappers
        T.fetchMIDIObjectRefs(context).forEach {
            addObject($0)
        }
    }

    // MARK: CoreMIDIObjectList implementation

    var midiObjectType: MIDIObjectType { T.midiObjectType }

    func objectPropertyChanged(midiObjectRef: MIDIObjectRef, property: CFString) {
        if let object = objectMap[midiObjectRef] {
            object.midiPropertyChanged(property)
            object.postPropertyChangedNotification(property)
        }
    }

    func objectWasAdded(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType, preNotificationClosure: (() -> Void)?) {
        if let addedObject = addObject(midiObjectRef) {
            // The objects' ordering may have changed, so refresh it
            refreshOrdering(T.fetchMIDIObjectRefs(context))

            preNotificationClosure?()

            context.postObjectsAddedNotification([addedObject])
            context.postObjectListChangedNotification(midiObjectType)
        }
    }

    func objectWasRemoved(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType) {
        if let removedObject = removeObject(midiObjectRef) {
            removedObject.postObjectRemovedNotification()
            context.postObjectListChangedNotification(midiObjectType)
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
        for objectRef in newObjectRefs where context.allowMIDIObject(ref: objectRef, type: midiObjectType) {
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
            context.postObjectsAddedNotification(addedObjects)
        }
        removedObjects.forEach {
            $0.postObjectRemovedNotification()
        }
        for (original, replacement) in replacements {
            original.postObjectReplacedNotification(replacement: replacement)
        }
        if !addedObjects.isEmpty || !removedObjects.isEmpty || !replacements.isEmpty {
            context.postObjectListChangedNotification(midiObjectType)
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

    @discardableResult private func addObject(_ midiObjectRef: MIDIObjectRef) -> T? {
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

        objectMap[midiObjectRef] = nil
        if let index = orderedObjects.firstIndex(where: { $0 == removedObject }) {
            orderedObjects.remove(at: index)
        }

        return removedObject
    }

    private func refreshOrdering(_ objectRefs: [MIDIObjectRef]) {
        // FUTURE: This should perhaps just invalidate the ordering, so it can
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
