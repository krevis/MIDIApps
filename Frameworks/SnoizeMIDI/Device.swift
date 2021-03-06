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
