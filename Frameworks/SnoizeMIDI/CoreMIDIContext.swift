/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import CoreMIDI

protocol CoreMIDIContext: AnyObject {

    // This protocol is used by CoreMIDIObjectWrappers to interact with
    // the rest of the MIDI system.

    // Basic functionality

    var interface: CoreMIDIInterface { get }
    var client: MIDIClientRef { get }

    func forcePropertyChanged(_ type: MIDIObjectType, _ objectRef: MIDIObjectRef, _ property: CFString)

    func generateNewUniqueID() -> MIDIUniqueID

    func allowMIDIObject(ref: MIDIObjectRef, type: MIDIObjectType) -> Bool

    // Interaction with other MIDIObject subclasses

    func postObjectsAddedNotification<T: CoreMIDIObjectListable & CoreMIDIPropertyChangeHandling>(_ objects: [T])

    func postObjectListChangedNotification(_ type: MIDIObjectType)

    func updateEndpointsForDevice(_ device: Device)

    func findObject(midiObjectRef: MIDIObjectRef) -> Device?
    func findObject(midiObjectRef: MIDIObjectRef) -> ExternalDevice?
    func findObject(midiObjectRef: MIDIObjectRef) -> Source?
    func findObject(midiObjectRef: MIDIObjectRef) -> Destination?

    func findObject(uniqueID: MIDIUniqueID) -> Source?
    func findObject(uniqueID: MIDIUniqueID) -> Destination?

    func addedVirtualSource(midiObjectRef: MIDIObjectRef) -> Source?
    func addedVirtualDestination(midiObjectRef: MIDIObjectRef) -> Destination?

}
