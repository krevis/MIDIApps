/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import CoreMIDI

public class Device: MIDIObject, CoreMIDIObjectListable {

    static let midiObjectType = MIDIObjectType.device
    static func midiObjectCount(_ context: CoreMIDIContext) -> Int {
        context.interface.getNumberOfDevices()
    }
    static func midiObjectSubscript(_ context: CoreMIDIContext, _ index: Int) -> MIDIObjectRef {
        context.interface.getDevice(index)
    }

    override func midiPropertyChanged(_ property: CFString) {
        super.midiPropertyChanged(property)

        if property == kMIDIPropertyOffline {
            // This device just went offline or online. If it went online,
            // its sources might now appear in MIDIGetNumberOfSources/GetSourceAtIndex,
            // and this is the only way we'll find out. (Same thing for destinations.)
            // Similarly, if it went offline, its sources/destinations won't be
            // in the list anymore.
            midiContext.updateEndpointsForDevice(self)
        }

        if property == kMIDIPropertyName {
            // This may affect the displayName of associated sources and destinations.
            let interface = midiContext.interface
            for entityIndex in 0 ..< interface.deviceGetNumberOfEntities(midiObjectRef) {
                let entityRef = interface.deviceGetEntity(midiObjectRef, entityIndex)

                for index in 0 ..< interface.entityGetNumberOfSources(entityRef) {
                    let sourceRef = interface.entityGetSource(entityRef, index)
                    midiContext.forcePropertyChanged(.source, sourceRef, kMIDIPropertyDisplayName)
                }

                for index in 0 ..< interface.entityGetNumberOfDestinations(entityRef) {
                    let destinationRef = interface.entityGetDestination(entityRef, index)
                    midiContext.forcePropertyChanged(.destination, destinationRef, kMIDIPropertyDisplayName)
                }
            }
        }
    }

}
