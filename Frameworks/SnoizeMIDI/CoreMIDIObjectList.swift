/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import CoreMIDI

protocol CoreMIDIObjectListable: CoreMIDIObjectWrapper {

    static var midiObjectType: MIDIObjectType { get }
    static func midiObjectCount(_ context: CoreMIDIContext) -> Int
    static func midiObjectSubscript(_ context: CoreMIDIContext, _ index: Int) -> MIDIObjectRef

    init(context: CoreMIDIContext, objectRef: MIDIObjectRef)

    var uniqueID: MIDIUniqueID { get } // So list can look up object by uniqueID

}

extension CoreMIDIObjectListable {

    static func fetchMIDIObjectRefs(_ context: CoreMIDIContext) -> [MIDIObjectRef] {
        var objectRefs: [MIDIObjectRef] = []

        let count = midiObjectCount(context)
        for index in 0 ..< count {
            let objectRef = midiObjectSubscript(context, index)
            if objectRef != 0 {
                objectRefs.append(objectRef)
            }
        }

        return objectRefs
    }

}

protocol CoreMIDIObjectList {

    var midiObjectType: MIDIObjectType { get }

    func objectPropertyChanged(midiObjectRef: MIDIObjectRef, property: CFString)

    func objectWasAdded(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType, preNotificationClosure: (() -> Void)?)
    func objectWasRemoved(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType)

    func updateList()

}
