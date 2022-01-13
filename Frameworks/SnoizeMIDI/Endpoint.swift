/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import CoreMIDI

public class Endpoint: MIDIObject {

    required init(context: CoreMIDIContext, objectRef: MIDIObjectRef) {
        super.init(context: context, objectRef: objectRef)
    }

    private lazy var cachedManufacturer = cacheProperty(kMIDIPropertyManufacturer, String.self)
    public var manufacturer: String? {
        get { self[cachedManufacturer] }
        set { self[cachedManufacturer] = newValue }
    }

    private lazy var cachedModel = cacheProperty(kMIDIPropertyModel, String.self)
    public var model: String? {
        get { self[cachedModel] }
        set { self[cachedModel] = newValue }
    }

    private lazy var cachedDisplayName = cacheProperty(kMIDIPropertyDisplayName, String.self)
    public var displayName: String? {
        get { self[cachedDisplayName] }
        set { self[cachedDisplayName] = newValue }
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

    func setPrivateToThisProcess() {
        self[kMIDIPropertyPrivate as CFString] = Int32(1)
    }

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
    private static let propertyOwnerPID = "SMEndpointPropertyOwnerPID"
    private var ownerPID: Int32 {
        get { self[Endpoint.propertyOwnerPID as CFString] ?? 0 }
        set { self[Endpoint.propertyOwnerPID as CFString] = newValue }
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
