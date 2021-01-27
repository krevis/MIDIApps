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

public class Endpoint: MIDIObject {

    required init(context: CoreMIDIContext, objectRef: MIDIObjectRef) {
        super.init(context: context, objectRef: objectRef)
        cacheStringProperty(kMIDIPropertyManufacturer)
        cacheStringProperty(kMIDIPropertyModel)
        cacheStringProperty(kMIDIPropertyDisplayName)
    }

    public var manufacturer: String? {
        get { getCachedProperty(kMIDIPropertyManufacturer) }
        set { setCachedProperty(kMIDIPropertyManufacturer, newValue) }
    }

    public var model: String? {
        get { getCachedProperty(kMIDIPropertyModel) }
        set { setCachedProperty(kMIDIPropertyModel, newValue) }
    }

    public var displayName: String? {
        get { getCachedProperty(kMIDIPropertyDisplayName) }
        set { setCachedProperty(kMIDIPropertyDisplayName, newValue) }
    }

    public var device: Device? {
        midiContext.findObject(midiObjectRef: deviceRef)
    }

    public var isVirtual: Bool {
        deviceRef == 0
    }

    public var isOwnedByThisProcess: Bool {
        isVirtual && ownerPID == getpid()
    }

    public var connectedExternalDevices: [ExternalDevice] {
        uniqueIDsOfConnectedThings.compactMap { uniqueID -> ExternalDevice? in
            if let deviceRef = deviceRefFromConnectedUniqueID(uniqueID) {
                return midiContext.findObject(midiObjectRef: deviceRef)
            }
            else {
                return nil
            }
        }
    }

    public var endpointRef: MIDIEndpointRef {
        midiObjectRef
    }

    // MARK: Internal

    func setOwnedByThisProcess() {
        // We have a chicken-egg problem. When setting values of properties, we want
        // to make sure that the endpoint is owned by this process. However, there's
        // no way to tell if the endpoint is owned by this process until it gets a
        // property set on it. So we'll say that this property should be set first,
        // before any other setters are called.

        guard isVirtual else { fatalError("Endpoint is not virtual, so it can't be owned by this process") }
        ownerPID = getpid()
    }

    // MARK: Private

    // We set this property on the virtual endpoints that we create,
    // so we can query them to see if they're ours.
    private let propertyOwnerPID = "SMEndpointPropertyOwnerPID"
    private var ownerPID: Int32 {
        get { self[propertyOwnerPID as CFString] ?? 0 }
        set { self[propertyOwnerPID as CFString] = newValue }
    }

    private var cachedDeviceRef: MIDIDeviceRef?
    private var deviceRef: MIDIDeviceRef {
        switch cachedDeviceRef {
        case .none:
            let value: MIDIDeviceRef = {
                var entityRef: MIDIEntityRef = 0
                var deviceRef: MIDIDeviceRef = 0
                if midiContext.interface.endpointGetEntity(endpointRef, &entityRef) == noErr,
                   midiContext.interface.entityGetDevice(entityRef, &deviceRef) == noErr {
                    return deviceRef
                }
                else {
                    return 0
                }
            }()
            cachedDeviceRef = .some(value)
            return value
        case .some(let value):
            return value
        }
    }

    var uniqueIDsOfConnectedThings: [MIDIUniqueID] {
        // Connected things may be external devices, endpoints, or who knows what.

        // The property for kMIDIPropertyConnectionUniqueID may be an integer or a data object.
        // Try getting it as data first.  (The data is an array of big-endian MIDIUniqueIDs, aka Int32s.)
        if let data: Data = self[kMIDIPropertyConnectionUniqueID] {
            // Make sure the data size makes sense
            guard data.count > 0, data.count % MemoryLayout<Int32>.size == 0 else { return [] }
            return data.withUnsafeBytes {
                $0.bindMemory(to: Int32.self).map { MIDIUniqueID(bigEndian: $0) }
            }
        }

        // Now try getting the property as an integer. (It is only valid if nonzero.)
        if let oneUniqueID: MIDIUniqueID = self[kMIDIPropertyConnectionUniqueID],
           oneUniqueID != 0 {
            return [oneUniqueID]
        }

        // Give up
        return []
    }

    private func deviceRefFromConnectedUniqueID(_ connectedUniqueID: MIDIUniqueID) -> MIDIDeviceRef? {
        var foundDeviceRef: MIDIDeviceRef?

        var connectedObjectRef: MIDIObjectRef = 0
        var connectedObjectType: MIDIObjectType = .other
        var status = midiContext.interface.objectFindByUniqueID(connectedUniqueID, &connectedObjectRef, &connectedObjectType)
        var done = false
        while status == noErr && !done {
            switch connectedObjectType {
            case .device, .externalDevice:
                // We've got the device
                foundDeviceRef = connectedObjectRef as MIDIDeviceRef
                done = true

            case .entity, .externalEntity:
                // Get the entity's device
                status = midiContext.interface.entityGetDevice(connectedObjectRef as MIDIEntityRef, &connectedObjectRef)
                connectedObjectType = .device

            case .source, .destination, .externalSource, .externalDestination:
                // Get the endpoint's entity
                status = midiContext.interface.endpointGetEntity(connectedObjectRef as MIDIEndpointRef, &connectedObjectRef)
                connectedObjectType = .entity

            default:
                // Give up
                done = true
            }
        }

        return foundDeviceRef
    }

}
