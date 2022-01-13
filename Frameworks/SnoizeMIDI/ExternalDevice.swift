/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import CoreMIDI

public class ExternalDevice: MIDIObject, CoreMIDIObjectListable {

    static let midiObjectType = MIDIObjectType.externalDevice
    static func midiObjectCount(_ context: CoreMIDIContext) -> Int {
        context.interface.getNumberOfExternalDevices()
    }
    static func midiObjectSubscript(_ context: CoreMIDIContext, _ index: Int) -> MIDIObjectRef {
        context.interface.getExternalDevice(index)
    }

    public override var maxSysExSpeed: Int32 {
        didSet {
            // Also set the speed on this device's source endpoints (which we get to via its entities).
            // This is how MIDISendSysex() determines what speed to use, surprisingly.

            let interface = midiContext.interface
            for entityIndex in 0 ..< interface.deviceGetNumberOfEntities(midiObjectRef) {
                let entityRef = interface.deviceGetEntity(midiObjectRef, entityIndex)
                for sourceIndex in 0 ..< interface.entityGetNumberOfSources(entityRef) {
                    let sourceEndpointRef = interface.entityGetSource(entityRef, sourceIndex)
                    _ = interface.objectSetIntegerProperty(sourceEndpointRef, kMIDIPropertyMaxSysExSpeed, Int32(maxSysExSpeed))
                    // ignore errors, nothing we can do anyway
                }
            }
        }
    }

    override func midiPropertyChanged(_ property: CFString) {
        super.midiPropertyChanged(property)

        if property == kMIDIPropertyName {
            // When the name changes, this might affect the displayName of
            // connected Source and Destination endpoints, so we have to
            // invalidate that property too. CoreMIDI doesn't do it for us.

            let interface = midiContext.interface
            for entityIndex in 0 ..< interface.deviceGetNumberOfEntities(midiObjectRef) {
                let entityRef = interface.deviceGetEntity(midiObjectRef, entityIndex)

                // Each entity in this external device has "external" source and
                // destination endpoints, each of which may have a connection to a
                // real endpoint of the opposite type.

                for index in 0 ..< interface.entityGetNumberOfSources(entityRef) {
                    let endpointRef = interface.entityGetSource(entityRef, index)
                    let tempSource = Source(context: midiContext, objectRef: endpointRef)
                    let uniqueIDs = tempSource.uniqueIDsOfConnectedThings
                    for uniqueID in uniqueIDs {
                        if let destination: Destination = midiContext.findObject(uniqueID: uniqueID) {
                            midiContext.forcePropertyChanged(.destination, destination.midiObjectRef, kMIDIPropertyDisplayName)
                        }
                    }
                }
                for index in 0 ..< interface.entityGetNumberOfDestinations(entityRef) {
                    let endpointRef = interface.entityGetDestination(entityRef, index)

                    let tempDestination = Destination(context: midiContext, objectRef: endpointRef)
                    let uniqueIDs = tempDestination.uniqueIDsOfConnectedThings
                    for uniqueID in uniqueIDs {
                        if let source: Source = midiContext.findObject(uniqueID: uniqueID) {
                            midiContext.forcePropertyChanged(.source, source.midiObjectRef, kMIDIPropertyDisplayName)
                        }
                    }
                }
            }
        }
    }

}
