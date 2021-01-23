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

// TODO Wrapper could be Identifiable (with id = midiObjectRef), Equatable

protocol CoreMIDIObjectWrapper {

    var midiClient: SMClient? { get }    // TODO This should refer to a protocol too
    var midiObjectRef: MIDIObjectRef { get }

}

extension CoreMIDIObjectWrapper {

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

    /* TODO Are these even useful? We cache them in MIDIObject. And I don't think it can get to these implementations.
    public var name: String? {
        get { string(forProperty: kMIDIPropertyName) }
        set { set(string: newValue, forProperty: kMIDIPropertyName) }
    }

    public var uniqueID: MIDIUniqueID? {
        get { int32(forProperty: kMIDIPropertyUniqueID) }
        set { set(int32: newValue, forProperty: kMIDIPropertyUniqueID) }
    }
 */
    // TODO More?

}

protocol CoreMIDIPropertyChangeHandling {

    func midiPropertyChanged(_ property: CFString)

}

class MIDIObject: CoreMIDIObjectWrapper, CoreMIDIPropertyChangeHandling {

    weak var midiClient: SMClient?
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

protocol CoreMIDIObjectCollectible: CoreMIDIObjectWrapper {

    static var midiObjectType: MIDIObjectType { get }
    static var midiObjectCountFunction: (() -> Int) { get }
    static var midiObjectSubscriptFunction: ((Int) -> MIDIObjectRef) { get }

    init(client: SMClient, midiObjectRef: MIDIObjectRef)

}

extension CoreMIDIObjectCollectible {

    // Default implementation of Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.midiClient == rhs.midiClient &&
            lhs.midiObjectRef == rhs.midiObjectRef
    }

}

protocol CoreMIDIObjectCollection {

    var collectibleType: CoreMIDIObjectCollectible.Type { get }

    func object(midiObjectRef: MIDIObjectRef) -> CoreMIDIObjectCollectible?

    func objectWasAdded(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType)
    func objectWasRemoved(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType)

}

class MIDIObjectCollection: CoreMIDIObjectCollection {
    // TODO Not actually a Collection, should rename
    // TODO Arguably should be MIDIObjectCollection<T: CoreMIDIObjectCollectible>.
    //      Then we could make CoreMIDIObjectWrapper conform to Equatable,
    //      and in removeObject() below, use == on the objects directly.
    //      However then SMClient needs a heterogeneous array of these things
    //      and I couldn't work out how to do that. May not be possible.

    init(client: SMClient, collectibleType: CoreMIDIObjectCollectible.Type) {
        self.client = client
        self.collectibleType = collectibleType

        // Populate our object wrappers
        let count = collectibleType.midiObjectCountFunction()
        for index in 0 ..< count {
            let objectRef = collectibleType.midiObjectSubscriptFunction(index)
            _ = addObject(objectRef)
        }
    }

    func object(midiObjectRef: MIDIObjectRef) -> CoreMIDIObjectCollectible? {
        objectMap[midiObjectRef]
    }

    func objectWasAdded(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType) {
        if let addedObject = addObject(midiObjectRef) {
            // The objects' ordering may have changed, so refresh it
            refreshOrdering()

            postObjectListChangedNotification()
            postObjectsAddedNotification([addedObject])
        }
    }

    func objectWasRemoved(midiObjectRef: MIDIObjectRef, parentObjectRef: MIDIObjectRef, parentType: MIDIObjectType) {
        if let removedObject = removeObject(midiObjectRef) {
            // TODO Does ordering need work?

            postObjectListChangedNotification()
            postObjectsRemovedNotification([removedObject])
        }
    }

    // MARK: Private

    weak var client: SMClient?
    let collectibleType: CoreMIDIObjectCollectible.Type

    var objectMap: [MIDIObjectRef: CoreMIDIObjectCollectible] = [:]
    var orderedObjects: [CoreMIDIObjectCollectible] = []

    private func addObject(_ midiObjectRef: MIDIObjectRef) -> CoreMIDIObjectCollectible? {
        guard let client = client,
              midiObjectRef != 0,
              objectMap[midiObjectRef] == nil
        else { return nil }

        let addedObject = collectibleType.init(client: client, midiObjectRef: midiObjectRef)
        objectMap[midiObjectRef] = addedObject
        orderedObjects.append(addedObject)
        return addedObject
    }

    private func removeObject(_ midiObjectRef: MIDIObjectRef) -> CoreMIDIObjectCollectible? {
        guard midiObjectRef != 0,
              let removedObject = objectMap[midiObjectRef]
        else { return nil }

        objectMap.removeValue(forKey: midiObjectRef)
        if let index = orderedObjects.firstIndex(where: { $0.midiObjectRef == midiObjectRef }) {
            orderedObjects.remove(at: index)
        }

        return removedObject
    }

    private func refreshOrdering() {
        // TODO
    }

    private func postObjectListChangedNotification() {
        // TODO
    }

    private func postObjectsAddedNotification(_ objects: [CoreMIDIObjectCollectible]) {
        // TODO
    }

    private func postObjectsRemovedNotification(_ objects: [CoreMIDIObjectCollectible]) {
        // TODO
    }

}

class Device: MIDIObject, CoreMIDIObjectCollectible {

    static let midiObjectType = MIDIObjectType.device
    static let midiObjectCountFunction = MIDIGetNumberOfDevices
    static let midiObjectSubscriptFunction = MIDIGetDevice

}

class ExternalDevice: MIDIObject, CoreMIDIObjectCollectible {

    static let midiObjectType = MIDIObjectType.externalDevice
    static let midiObjectCountFunction = MIDIGetNumberOfExternalDevices
    static let midiObjectSubscriptFunction = MIDIGetExternalDevice

}

class Endpoint: MIDIObject {

}

class Source: Endpoint, CoreMIDIObjectCollectible {

    static let midiObjectType = MIDIObjectType.source
    static let midiObjectCountFunction = MIDIGetNumberOfSources
    static let midiObjectSubscriptFunction = MIDIGetSource

}

class Destination: Endpoint, CoreMIDIObjectCollectible {

    static let midiObjectType = MIDIObjectType.destination
    static let midiObjectCountFunction = MIDIGetNumberOfDestinations
    static let midiObjectSubscriptFunction = MIDIGetDestination

}
