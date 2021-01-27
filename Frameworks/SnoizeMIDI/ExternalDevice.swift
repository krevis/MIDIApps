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
