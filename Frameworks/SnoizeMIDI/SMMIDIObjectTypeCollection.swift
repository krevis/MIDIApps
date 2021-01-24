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

protocol CoreMIDIObjectWrapper: Equatable, Identifiable {

    var midiClient: SMClient { get }    // TODO This should refer to a protocol too
    var midiObjectRef: MIDIObjectRef { get }

}

extension CoreMIDIObjectWrapper {

    // MARK: Identifiable default implementation

    var id: (SMClient, MIDIObjectRef) { (midiClient, midiObjectRef) } // swiftlint:disable:this identifier_name

    // MARK: Equatable default implementation

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: MIDI Property Accessors
    // TODO These should dispatch through midiClient instead of calling CoreMIDI directly

    public func string(forProperty property: CFString) -> String? {
        var unmanagedValue: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(midiObjectRef, property, &unmanagedValue) == noErr {
            return unmanagedValue?.takeUnretainedValue() as String?
        }
        else {
            return nil
        }
    }

    public func set(string: String?, forProperty property: CFString) {
        if let value = string {
            _ = MIDIObjectSetStringProperty(midiObjectRef, property, value as CFString)
        }
        else {
            _ = MIDIObjectRemoveProperty(midiObjectRef, property)
        }
    }

    public func int32(forProperty property: CFString) -> Int32? {
        var value: Int32 = 0
        if MIDIObjectGetIntegerProperty(midiObjectRef, property, &value) == noErr {
            return value
        }
        else {
            return nil
        }
    }

    public func set(int32: Int32?, forProperty property: CFString) {
        if let value = int32 {
            _ = MIDIObjectSetIntegerProperty(midiObjectRef, property, value)
        }
        else {
            _ = MIDIObjectRemoveProperty(midiObjectRef, property)
        }
    }

    public func data(forProperty property: CFString) -> Data? {
        var unmanagedValue: Unmanaged<CFData>?
        if MIDIObjectGetDataProperty(midiObjectRef, property, &unmanagedValue) == noErr {
            return unmanagedValue?.takeUnretainedValue() as Data?
        }
        else {
            return nil
        }
    }

    public func set(data: Data?, forProperty property: CFString) {
        if let value = data {
            _ = MIDIObjectSetDataProperty(midiObjectRef, property, value as CFData)
        }
        else {
            _ = MIDIObjectRemoveProperty(midiObjectRef, property)
        }
    }

    // MARK: Convenience methods

    /* TODO Add, if needed, like this:
    public var name: String? {
        get { string(forProperty: kMIDIPropertyName) }
        set { set(string: newValue, forProperty: kMIDIPropertyName) }
    }
     */

}

protocol CoreMIDIPropertyChangeHandling {

    func midiPropertyChanged(_ property: CFString)

}

class MIDIObject: CoreMIDIObjectWrapper, CoreMIDIPropertyChangeHandling {

    unowned var midiClient: SMClient
    let midiObjectRef: MIDIObjectRef

    required init(client: SMClient, midiObjectRef: MIDIObjectRef) {
        precondition(midiObjectRef != 0)

        self.midiClient = client
        self.midiObjectRef = midiObjectRef

        // Immediately fetch the object's uniqueID, since it could become
        // inaccessible later, if the object is removed from CoreMIDI
        cachedUniqueID = int32(forProperty: kMIDIPropertyUniqueID) ?? 0
    }

    private var cachedUniqueID: MIDIUniqueID?
    public var uniqueID: MIDIUniqueID {
        get {
            switch cachedUniqueID {
            case .none:
                let value = int32(forProperty: kMIDIPropertyUniqueID) ?? 0
                cachedUniqueID = value
                return value
            case .some(let value):
                return value
            }
        }
        set {
            if cachedUniqueID != .some(newValue) {
                set(int32: newValue, forProperty: kMIDIPropertyUniqueID)
                cachedUniqueID = .none
            }
        }
    }

    private var cachedName: String??
    public var name: String? {
        get {
            switch cachedName {
            case .none:
                let value = string(forProperty: kMIDIPropertyName)
                cachedName = .some(value)
                return value
            case .some(let value):
                return value
            }
        }
        set {
            if cachedName != .some(newValue) {
                set(string: newValue, forProperty: kMIDIPropertyName)
                cachedName = .none
            }
        }
    }

    func midiPropertyChanged(_ property: CFString) {
        switch property {
        case kMIDIPropertyUniqueID:
            cachedName = .none
        case kMIDIPropertyUniqueID:
            cachedUniqueID = .none
        default:
            break
        }
    }

}

protocol CoreMIDIObjectListable: CoreMIDIObjectWrapper {

    static var midiObjectType: MIDIObjectType { get }
    static var midiObjectCountFunction: (() -> Int) { get }
    static var midiObjectSubscriptFunction: ((Int) -> MIDIObjectRef) { get }

    init(client: SMClient, midiObjectRef: MIDIObjectRef)

}

extension CoreMIDIObjectListable {

    static func postObjectListChangedNotification() {
        NotificationCenter.default.post(name: .midiObjectListChanged, object: self)
    }

    static func postObjectsAddedNotification(_ objects: [Self]) {
        NotificationCenter.default.post(name: .midiObjectsAppeared, object: Self.self, userInfo: [SMMIDIObject.midiObjectsThatAppeared: objects])
    }

    static func postObjectRemovedNotification(_ object: Self) {
        NotificationCenter.default.post(name: .midiObjectDisappeared, object: object)
    }

}

protocol CoreMIDIObjectList {

    var midiObjectType: MIDIObjectType { get }

    func objectPropertyChanged(midiObjectRef: MIDIObjectRef, property: CFString)

    func objectWasAdded(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType)
    func objectWasRemoved(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType)

}

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

class Device: MIDIObject, CoreMIDIObjectListable {

    static let midiObjectType = MIDIObjectType.device
    static let midiObjectCountFunction = MIDIGetNumberOfDevices
    static let midiObjectSubscriptFunction = MIDIGetDevice

    override func midiPropertyChanged(_ property: CFString) {
        super.midiPropertyChanged(property)

        if property == kMIDIPropertyOffline {
            // This device just went offline or online. We need to refresh its endpoints.
            // (If it went online, we didn't previously have its endpoints in our list.)

            // TODO This is an overly blunt approach, can we do better?
            // SMSourceEndpoint.refreshAllObjects()
            // SMDestinationEndpoint.refreshAllObjects()
        }
    }

}

class ExternalDevice: MIDIObject, CoreMIDIObjectListable {

    static let midiObjectType = MIDIObjectType.externalDevice
    static let midiObjectCountFunction = MIDIGetNumberOfExternalDevices
    static let midiObjectSubscriptFunction = MIDIGetExternalDevice

    // TODO maxSysExSpeed didSet needs to also set the property on the source endpoints

}

class Endpoint: MIDIObject {

    /* TODO: a lot of stuff
        deviceRef (parent), device
        isVirtual
        isOwnedByThisProcess needs ownerPID
        remove() for virtual endpoints owned by this process, calls MIDIEndpointDispose()
        manufacturerName, modelName w/cache
        displayName (which also needs caching)
         connectedExternalDevices, uniqueIDsOfConnectedThings
     */
}

class Source: Endpoint, CoreMIDIObjectListable {

    static let midiObjectType = MIDIObjectType.source
    static let midiObjectCountFunction = MIDIGetNumberOfSources
    static let midiObjectSubscriptFunction = MIDIGetSource

    // TODO createVirtualSourceEndpoint
    // TODO endpointCount(forEntity), endpointRef(atIndex: forEntity)
}

class Destination: Endpoint, CoreMIDIObjectListable {

    static let midiObjectType = MIDIObjectType.destination
    static let midiObjectCountFunction = MIDIGetNumberOfDestinations
    static let midiObjectSubscriptFunction = MIDIGetDestination

    // TODO createVirtualDestinationEndpoint
    // TODO endpointCount(forEntity), endpointRef(atIndex: forEntity)
    // TODO sysExSpeedWorkaroundEndpoint and related

}
