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

    init(client: SMClient) {
        self.client = client

        // Populate our object wrappers
        let count = T.midiObjectCountFunction()
        for index in 0 ..< count {
            let objectRef = T.midiObjectSubscriptFunction(index)
            _ = addObject(objectRef)
        }
    }

    // MARK: CoreMIDIObjectList implementation

    var midiObjectType: MIDIObjectType { T.midiObjectType }

    func objectPropertyChanged(midiObjectRef: MIDIObjectRef, property: CFString) {
        objectMap[midiObjectRef]?.midiPropertyChanged(property)
    }

    func objectWasAdded(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType) {
        if let addedObject = addObject(midiObjectRef) {
            // The objects' ordering may have changed, so refresh it
            refreshOrdering()

            T.postObjectListChangedNotification()
            T.postObjectsAddedNotification([addedObject])
            // TODO This is *objects* added but we only know one object
        }
    }

    func objectWasRemoved(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType) {
        if let removedObject = removeObject(midiObjectRef) {
            // TODO Does ordering need work?

            T.postObjectListChangedNotification()
            T.postObjectRemovedNotification(removedObject)
        }
    }

    // MARK: Private

    private weak var client: SMClient?
    private var objectMap: [MIDIObjectRef: T] = [:]
    private var orderedObjects: [T] = []    // TODO This will need to be exposed somehow

    private func addObject(_ midiObjectRef: MIDIObjectRef) -> T? {
        guard let client = client,
              midiObjectRef != 0,
              objectMap[midiObjectRef] == nil
        else { return nil }

        let addedObject = T.init(client: client, midiObjectRef: midiObjectRef)
        objectMap[midiObjectRef] = addedObject
        orderedObjects.append(addedObject)
        return addedObject
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

    private func refreshOrdering() {
        // TODO This should perhaps just invalidate the ordering, so it can
        // be recomputed it the next time somebody asks for it

        var newOrdering: [T] = []
        let count = T.midiObjectCountFunction()
        for index in 0 ..< count {
            let objectRef = T.midiObjectSubscriptFunction(index)
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
