/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import CoreMIDI

@objc public class SMEndpoint: SMMIDIObject {

    // MARK: New methods

    public var endpointRef: MIDIEndpointRef {
        objectRef()
    }

    public var isVirtual: Bool {
        // We are virtual if we have no device
        deviceRef == 0
    }

    @objc public var isOwnedByThisProcess: Bool {
        isVirtual && ownerPID == getpid()
    }

    public func remove() {
        // only works on virtual endpoints owned by this process

        guard objectRef() != 0 && isOwnedByThisProcess else { return }

        _ = MIDIEndpointDispose(endpointRef)

        // This object still hangs around in the endpoint lists until CoreMIDI gets around to posting a notification.
        // We should remove it immediately.
        Self.immediatelyRemove(self)

        // Now we can forget the objectRef (not earlier!)
        clearObjectRef()
    }

    public var manufacturerName: String? {
        get {
            if !hasCachedManufacturerName {
                cachedManufacturerName = string(forProperty: kMIDIPropertyManufacturer)
                hasCachedManufacturerName = true
            }
            return cachedManufacturerName
        }
        set {
            if newValue != manufacturerName {
                setString(newValue, forProperty: kMIDIPropertyManufacturer)
                hasCachedManufacturerName = false
            }
        }
    }

    // TODO This is the same as above, consider a property wrapper
    public var modelName: String? {
        get {
            if !hasCachedModelName {
                cachedModelName = string(forProperty: kMIDIPropertyModel)
                hasCachedModelName = true
            }
            return cachedModelName
        }
        set {
            if newValue != modelName {
                setString(newValue, forProperty: kMIDIPropertyModel)
                hasCachedModelName = false
            }
        }
    }

    @objc public var displayName: String? {
        // Use kMIDIPropertyDisplayName to get the suggested display name,
        // which takes uniqueness, external devices, etc. into account.

        var unmanagedDisplayName: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(objectRef(), kMIDIPropertyDisplayName, &unmanagedDisplayName) == noErr,
           let displayName = unmanagedDisplayName?.takeUnretainedValue() as String? {
            return displayName
        }

        return name()
    }

    @objc public var connectedExternalDevices: [SMExternalDevice] {
        uniqueIDsOfConnectedThings.compactMap { uniqueID -> SMExternalDevice? in
            if let deviceRef = getDeviceRefFromConnectedUniqueID(uniqueID) {
                return SMExternalDevice.externalDevice(deviceRef: deviceRef)
            }
            else {
                return nil
            }
        }
    }

    // Returns nil if this endpoint is virtual
    public var device: SMDevice? {
        SMDevice.device(deviceRef: deviceRef)
    }

    // MARK: Internal methods to override in subclasses
    // TODO This should be a protocol or something

    public class func endpointCount(forEntity entity: MIDIEntityRef) -> Int {
        fatalError()
    }

    public class func endpointRef(at index: Int, forEntity entity: MIDIEntityRef) -> MIDIEndpointRef {
        fatalError()
    }

    // MARK: Internal methods to call from subclasses

    func setOwnedByThisProcess() {
        // We have a chicken-egg problem. When setting values of properties, we want
        // to make sure that the endpoint is owned by this process. However, there's
        // no way to tell if the endpoint is owned by this process until it gets a
        // property set on it. So we'll say that this property should be set first,
        // before any other setters are called.

        guard isVirtual else { fatalError("Endpoint is not virtual, so it can't be owned by this process") }
        ownerPID = getpid()
    }

    // MARK: SMMIDIObject overrides, public

    public override func name() -> String! {
        var name = super.name()

        // Some misguided driver authors don't provide names for their endpoints.
        // (Seems especially common when the device has only one port.)
        // If there is no name provided, try some fallbacks.
        if name == nil || name!.isEmpty {
            name = device?.name()
        }

        if name == nil || name!.isEmpty {
            name = modelName
        }

        if name == nil || name!.isEmpty {
            name = manufacturerName
        }

        if name == nil || name!.isEmpty {
            name = "<Unnamed Port>"
        }

        return name
    }

    public override func checkIfPropertySetIsAllowed() {
        if !isOwnedByThisProcess {
            // TODO This used to raise, but that's annoying, do something else
            /*
             NSString* reason = NSLocalizedStringFromTableInBundle(@"Can't set a property on an endpoint we don't own", @"SnoizeMIDI", SMBundleForObject(self), "exception if someone tries to set a property on an endpoint we don't own");
             [[NSException exceptionWithName:NSGenericException reason:reason userInfo:nil] raise];
             */
        }
    }

    public override func invalidateCachedProperties() {
        super.invalidateCachedProperties()

        hasCachedDeviceRef = false
        cachedDeviceRef = 0
        hasCachedManufacturerName = false
        cachedManufacturerName = nil
        hasCachedModelName = false
        cachedModelName = nil
    }

    public override func propertyDidChange(_ propertyName: String!) {
        if propertyName == kMIDIPropertyManufacturer as String {
            hasCachedManufacturerName = false
            cachedManufacturerName = nil
        }
        else if propertyName == kMIDIPropertyModel as String {
            hasCachedModelName = false
            cachedModelName = nil
        }

        super.propertyDidChange(propertyName)
    }

    // MARK: Private

    private var hasCachedManufacturerName = false
    private var cachedManufacturerName: String?
    private var hasCachedModelName = false
    private var cachedModelName: String?

    // We set this property on the virtual endpoints that we create,
    // so we can query them to see if they're ours.
    static private let propertyOwnerPID = "SMEndpointPropertyOwnerPID"

    private var ownerPID: Int32 {
        get {
            do {
                return integer(forProperty: SMEndpoint.propertyOwnerPID as CFString)
            }
            catch {
                return 0
            }
        }
        set {
            _ = MIDIObjectSetIntegerProperty(objectRef(), SMEndpoint.propertyOwnerPID as CFString, newValue)
            // TODO This used to raise an exception on failure. Get away from that.
        }
    }

    private var uniqueIDsOfConnectedThings: [MIDIUniqueID] {
        // Connected things may be external devices, endpoints, or who knows what.

        // The property for kMIDIPropertyConnectionUniqueID may be an integer or a data object.
        // Try getting it as data first.  (The data is an array of big-endian MIDIUniqueIDs, aka Int32s.)
        var unmanagedData: Unmanaged<CFData>?
        if MIDIObjectGetDataProperty(objectRef(), kMIDIPropertyConnectionUniqueID, &unmanagedData) == noErr,
           let data = unmanagedData?.takeUnretainedValue() as Data? {
            // Make sure the data size makes sense
            guard data.count > 0, data.count % MemoryLayout<Int32>.size == 0 else { return [] }
            return data.withUnsafeBytes {
                $0.bindMemory(to: Int32.self).map { MIDIUniqueID(bigEndian: $0) }
            }
        }

        // Now try getting the property as an integer. (It is only valid if nonzero.)
        var oneUniqueID: MIDIUniqueID = 0
        if MIDIObjectGetIntegerProperty(objectRef(), kMIDIPropertyConnectionUniqueID, &oneUniqueID) == noErr && oneUniqueID != 0 {
            return [oneUniqueID]
        }

        // Give up
        return []
    }

    private func getDeviceRefFromConnectedUniqueID(_ connectedUniqueID: MIDIUniqueID) -> MIDIDeviceRef? {
        var foundDeviceRef: MIDIDeviceRef?

        var connectedObjectRef: MIDIObjectRef = 0
        var connectedObjectType: MIDIObjectType = .other
        var status = MIDIObjectFindByUniqueID(connectedUniqueID, &connectedObjectRef, &connectedObjectType)
        var done = false
        while status == noErr && !done {
            switch connectedObjectType {
            case .device, .externalDevice:
                // We've got the device
                foundDeviceRef = connectedObjectRef as MIDIDeviceRef
                done = true

            case .entity, .externalEntity:
                // Get the entity's device
                status = MIDIEntityGetDevice(connectedObjectRef as MIDIEntityRef, &connectedObjectRef)
                connectedObjectType = .device

            case .source, .destination, .externalSource, .externalDestination:
                // Get the endpoint's entity
                status = MIDIEndpointGetEntity(connectedObjectRef as MIDIEndpointRef, &connectedObjectRef)
                connectedObjectType = .entity

            default:
                // Give up
                done = true
            }
        }

        return foundDeviceRef
    }

    // TODO this should again be a property wrapper as above, although we only need a getter
    private var cachedDeviceRef: MIDIDeviceRef = 0
    private var hasCachedDeviceRef = false

    private var deviceRef: MIDIDeviceRef {
        if !hasCachedDeviceRef {
            var entityRef: MIDIEntityRef = 0
            if MIDIEndpointGetEntity(endpointRef, &entityRef) == noErr {
                var deviceRef: MIDIEntityRef = 0
                if MIDIEntityGetDevice(entityRef, &deviceRef) == noErr {
                    cachedDeviceRef = deviceRef
                }
            }
        }
        return cachedDeviceRef
    }

}
