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

@objc public class MIDIContext: NSObject, CoreMIDIContext {

    public convenience override init() {
        self.init(interface: RealCoreMIDIInterface())
    }

    init(interface: CoreMIDIInterface) {
        checkMainQueue()

        self.privateInterface = interface

        super.init()

        let status: OSStatus
        if #available(macOS 10.11, iOS 9.0, *) {
            status = interface.clientCreateWithBlock(name as CFString, &midiClient) { unsafeNotification in
                // We are called on an arbitrary queue, so we need to dispatch to the
                // main queue for later handling.
                // But `unsafeNotification` is only valid during this function call,
                // so extract values from it right away.
                if let ourNotification = ContextNotification.fromCoreMIDI(unsafeNotification) {
                    DispatchQueue.main.async {
                        self.handle(ourNotification)
                    }
                }
            }
        }
        else {
            status = interface.clientCreate(name as CFString, { (unsafeNotification, refCon) in
                // We assume CoreMIDI is following its documentation, calling us
                // "on the run loop which was current when MIDIClientCreate was first
                // called", which must be the main queue's run loop.
                if let refCon = refCon,
                   let ourNotification = ContextNotification.fromCoreMIDI(unsafeNotification) {
                    let context = Unmanaged<MIDIContext>.fromOpaque(refCon).takeUnretainedValue()
                    context.handle(ourNotification)
                }
            }, Unmanaged.passUnretained(self).toOpaque(), &midiClient)
        }

        if status != noErr {
            // Cause `connectedToCoreMIDI` to be false, and a fatal error
            // to happen on subsequent CoreMIDI calls from this context.
            // We expect our creator to check `connectedToCoreMIDI` after
            // initializing.
            // (Or we could make this initializer failable, but
            // that turns out to be surprisingly tricky, since we need to
            // pass `self` into the CoreMIDI client notification closures.)
            self.privateInterface = nil
        }
    }

    // MARK: CoreMIDI connection and interface

    private var privateInterface: CoreMIDIInterface?

    // MARK: Public API

    public var connectedToCoreMIDI: Bool {
        privateInterface != nil
    }

    public let name =
        (Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String) ?? ProcessInfo.processInfo.processName

    public var sources: [Source] {
        sourceList.objects
    }

    public func findSource(uniqueID: MIDIUniqueID) -> Source? {
        sourceList.objects.first { $0.uniqueID == uniqueID }
    }

    public func findSource(name: String) -> Source? {
        sourceList.objects.first { $0.name == name }
    }

    public var destinations: [Destination] {
        destinationList.objects
    }

    public func findDestination(uniqueID: MIDIUniqueID) -> Destination? {
        destinationList.objects.first { $0.uniqueID == uniqueID }
    }

    public func findDestination(name: String) -> Destination? {
        destinationList.objects.first { $0.name == name }
    }

    public func forceCoreMIDIToUseNewSysExSpeed() {
        // The CoreMIDI client caches the last device that was given to MIDISendSysex(), along with its max sysex speed.
        // So when we change the speed, it doesn't notice and continues to use the old speed.
        // To fix this, we send a tiny sysex message to a different device.  Unfortunately we can't just use a NULL endpoint,
        // it has to be a real live endpoint.

        // TODO Implement
        //  if let endpoint = Destination.sysExSpeedWorkaroundEndpoint {
        //      let message = SMSystemExclusiveMessage(timeStamp: 0, data: Data())
        //          _ = SMSysExSendRequest(message: message, endpoint: endpoint)?.send()
        //      }
        //  }
    }

    @objc public func disconnect() {
        // Disconnect from CoreMIDI. Necessary only for very special circumstances, since CoreMIDI will be unusable afterwards.
        _ = interface.clientDispose(midiClient)
        midiClient = 0
        privateInterface = nil
    }

    // MARK: CoreMIDIContext

    var interface: CoreMIDIInterface {
        // Bottleneck to detect whether we expect CoreMIDI calls to work
        if let interface = privateInterface {
            return interface
        }
        else {
            fatalError("CoreMIDI client creation failed earlier, so calls to CoreMIDI cannot succeed. Check `connectedToCoreMIDI` after creating the MIDIContext to see whether it's actually usable.")
        }
    }

    var midiClient: MIDIClientRef = 0

    func updateEndpointsForDevice(_ device: Device) {
        // This is a very blunt approach, but reliable. Don't assume
        // anything about the source and destination lists. Just
        // refetch all of them and update our wrappers to match.
        sourceList.updateList()
        destinationList.updateList()
    }

    func generateNewUniqueID() -> MIDIUniqueID {
        // Return a random MIDIUniqueID which isn't currently in use
        while true {
            let proposedUniqueID: MIDIUniqueID = Int32.random(in: .min ... .max)
            if proposedUniqueID != 0 /* zero is special */ {
                var objectRef: MIDIObjectRef = 0
                var objectType: MIDIObjectType = .other
                if interface.objectFindByUniqueID(proposedUniqueID, &objectRef, &objectType) == kMIDIObjectNotFound {
                    return proposedUniqueID
                }
            }
        }
    }

    func findObject(midiObjectRef: MIDIObjectRef) -> Device? {
        deviceList.findObject(objectRef: midiObjectRef)
    }

    func findObject(midiObjectRef: MIDIObjectRef) -> ExternalDevice? {
        externalDeviceList.findObject(objectRef: midiObjectRef)
    }

    func findObject(midiObjectRef: MIDIObjectRef) -> Source? {
        sourceList.findObject(objectRef: midiObjectRef)
    }

    func findObject(midiObjectRef: MIDIObjectRef) -> Destination? {
        destinationList.findObject(objectRef: midiObjectRef)
    }

    func findObject(uniqueID: MIDIUniqueID) -> Source? {
        sourceList.findObject(uniqueID: uniqueID)
    }

    func findObject(uniqueID: MIDIUniqueID) -> Destination? {
        destinationList.findObject(uniqueID: uniqueID)
    }

    func addedVirtualSource(midiObjectRef: MIDIObjectRef) -> Source? {
        sourceList.objectWasAdded(midiObjectRef: midiObjectRef, parentObjectRef: 0, parentType: .other)
        return sourceList.findObject(objectRef: midiObjectRef)
    }

    func removedVirtualSource(_ source: Source) {
        sourceList.objectWasRemoved(midiObjectRef: source.midiObjectRef, parentObjectRef: 0, parentType: .other)
    }

    func addedVirtualDestination(midiObjectRef: MIDIObjectRef) -> Destination? {
        destinationList.objectWasAdded(midiObjectRef: midiObjectRef, parentObjectRef: 0, parentType: .other)
        return destinationList.findObject(objectRef: midiObjectRef)
    }

    func removedVirtualDestination(_ destination: Destination) {
        destinationList.objectWasRemoved(midiObjectRef: destination.midiObjectRef, parentObjectRef: 0, parentType: .other)
    }

    func forcePropertyChanged(_ type: MIDIObjectType, _ objectRef: MIDIObjectRef, _ property: CFString) {
        midiObjectList(type: type)?.objectPropertyChanged(midiObjectRef: objectRef, property: property)
    }

    // MARK: Notifications

    private enum ContextNotification {

        case added(object: MIDIObjectRef, objectType: MIDIObjectType, parent: MIDIObjectRef, parentType: MIDIObjectType)
        case removed(object: MIDIObjectRef, objectType: MIDIObjectType, parent: MIDIObjectRef, parentType: MIDIObjectType)
        case propertyChanged(object: MIDIObjectRef, objectType: MIDIObjectType, property: CFString)

        static func fromCoreMIDI(_ unsafeCoreMIDINotification: UnsafePointer<MIDINotification>) -> Self? {
            switch unsafeCoreMIDINotification.pointee.messageID {
            case .msgObjectAdded:
                let addRemoveNotification = UnsafeRawPointer(unsafeCoreMIDINotification).load(as: MIDIObjectAddRemoveNotification.self)
                return .added(object: addRemoveNotification.child, objectType: addRemoveNotification.childType, parent: addRemoveNotification.parent, parentType: addRemoveNotification.parentType)

            case .msgObjectRemoved:
                let addRemoveNotification = UnsafeRawPointer(unsafeCoreMIDINotification).load(as: MIDIObjectAddRemoveNotification.self)
                return .removed(object: addRemoveNotification.child, objectType: addRemoveNotification.childType, parent: addRemoveNotification.parent, parentType: addRemoveNotification.parentType)

            case .msgPropertyChanged:
                let propertyChangedNotification = UnsafeRawPointer(unsafeCoreMIDINotification).load(as: MIDIObjectPropertyChangeNotification.self)
                return .propertyChanged(object: propertyChangedNotification.object, objectType: propertyChangedNotification.objectType, property: propertyChangedNotification.propertyName.takeUnretainedValue())

            default:
                return nil
            }
        }

    }

    private func handle(_ notification: ContextNotification) {
        checkMainQueue()
        switch notification {
        case .added(let object, let objectType, let parent, let parentType):
            midiObjectList(type: objectType)?.objectWasAdded(
                midiObjectRef: object,
                parentObjectRef: parent,
                parentType: parentType
            )

        case .removed(let object, let objectType, let parent, let parentType):
            midiObjectList(type: objectType)?.objectWasRemoved(
                midiObjectRef: object,
                parentObjectRef: parent,
                parentType: parentType
            )

        case .propertyChanged(let object, let objectType, let property):
            midiObjectList(type: objectType)?.objectPropertyChanged(
                midiObjectRef: object,
                property: property
            )
        }
    }

    // MARK: Object lists

    private lazy var deviceList = MIDIObjectList<Device>(self)
    private lazy var externalDeviceList = MIDIObjectList<ExternalDevice>(self)
    private lazy var sourceList = MIDIObjectList<Source>(self)
    private lazy var destinationList = MIDIObjectList<Destination>(self)

    private lazy var midiObjectListsByType: [MIDIObjectType: CoreMIDIObjectList] = {
        let lists: [CoreMIDIObjectList] = [deviceList, externalDeviceList, sourceList, destinationList]
        return Dictionary(uniqueKeysWithValues: lists.map({ ($0.midiObjectType, $0) }))
    }()

    private func midiObjectList(type: MIDIObjectType) -> CoreMIDIObjectList? {
        midiObjectListsByType[type]
    }

}

private func checkMainQueue() {
    if #available(macOS 10.12, iOS 10.0, *) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
    }
    else {
        assert(Thread.isMainThread)
    }
}

// MARK: Notifications

public extension Notification.Name {

    // notification.object is the class that has new objects (e.g. Source or Destination)
    // notification.userInfo has an array of the new objects under key MIDIContext.objectsThatAppeared
    static let midiObjectsAppeared = Notification.Name("SMMIDIObjectsAppearedNotification")

    // notification.object is the object that disappeared
    static let midiObjectDisappeared = Notification.Name("SMMIDIObjectDisappearedNotification")

    // notification.object is the object that was replaced
    // notification.userInfo contains new object under key MIDIContext.objectReplacement
    static let midiObjectWasReplaced = Notification.Name("SMMIDIObjectWasReplacedNotification")

    // notification.object is the class that has either gained new objects or lost old ones
    // This notification is sent last, after the appeared/disappeared/wasReplaced notifications.
    static let midiObjectListChanged = Notification.Name("SMMIDIObjectListChangedNotification")

    // notification.object is the object whose property changed
    // notification.userInfo contains the changed property under key MIDIContext.changedProperty
    // (the raw CoreMIDI property name, e.g. kMIDIPropertyName, kMIDIPropertyMaxSysExSpeed)
    static let midiObjectPropertyChanged = Notification.Name("SMMIDIObjectPropertyChangedNotification")

}

public extension MIDIContext {

    // Keys in userInfo dictionary for notifications
    static let objectsThatAppeared = "SMMIDIObjectsThatAppeared"
    static let objectReplacement = "SMMIDIObjectReplacement"
    static let changedProperty = "SMMIDIObjectChangedPropertyName"

}

extension CoreMIDIObjectListable {

    // TODO: All of these static notifications are bad, nobody should be
    // observing notifications from a class anymore

    static func postObjectsAddedNotification(_ objects: [Self]) {
        guard !objects.isEmpty else { return }
        NotificationCenter.default.post(name: .midiObjectsAppeared, object: self, userInfo: [MIDIContext.objectsThatAppeared: objects])
    }

    static func postObjectRemovedNotification(_ object: Self) {
        NotificationCenter.default.post(name: .midiObjectDisappeared, object: object)
    }

    static func postObjectReplacedNotification(original: Self, replacement: Self) {
        NotificationCenter.default.post(name: .midiObjectWasReplaced, object: original, userInfo: [MIDIContext.objectReplacement: replacement])
    }

    static func postObjectListChangedNotification() {
        NotificationCenter.default.post(name: .midiObjectListChanged, object: self)
    }

    static func postObjectPropertyChangedNotification(_ object: Self, _ property: CFString) {
        NotificationCenter.default.post(name: .midiObjectPropertyChanged, object: self, userInfo: [MIDIContext.changedProperty: property])
    }

}
