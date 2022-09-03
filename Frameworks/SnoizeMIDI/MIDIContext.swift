/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import CoreMIDI

public class MIDIContext: CoreMIDIContext {

    public convenience init() {
        self.init(interface: RealCoreMIDIInterface())
    }

    init(interface: CoreMIDIInterface) {
        checkMainQueue()

        self.privateInterface = interface

        let status = interface.clientCreateWithBlock(name as CFString, &client) { unsafeNotification in
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

    public var externalDevices: [ExternalDevice] {
        externalDeviceList.objects
    }

    public func forceCoreMIDIToUseNewSysExSpeed() {
        // The CoreMIDI client caches the last device that was given to MIDISendSysex(), along with its max sysex speed.
        // So when we change the speed, it doesn't notice and continues to use the old speed.
        // To fix this, we send a tiny sysex message to a different device.  Unfortunately we can't just use a NULL endpoint,
        // it has to be a real live endpoint.

        if let destination = sysExSpeedWorkaroundDestination {
            let message = SystemExclusiveMessage(timeStamp: 0, data: Data())
            SysExSendRequest(message: message, destination: destination)?.send()
        }
    }

    public func disconnect() {
        // Disconnect from CoreMIDI. Necessary only for very special circumstances, since CoreMIDI will be unusable afterwards.
        _ = interface.clientDispose(client)
        client = 0
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

    var client: MIDIClientRef = 0

    func updateEndpointsForDevice(_ device: Device) {
        // This is a very blunt approach, but reliable. Don't assume
        // anything about the source and destination lists. Just
        // refetch all of them and update our wrappers to match.
        sourceList.updateList()
        destinationList.updateList()
    }

    func forcePropertyChanged(_ type: MIDIObjectType, _ objectRef: MIDIObjectRef, _ property: CFString) {
        midiObjectList(type: type)?.objectPropertyChanged(midiObjectRef: objectRef, property: property)
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

    func allowMIDIObject(ref: MIDIObjectRef, type: MIDIObjectType) -> Bool {
        // Don't let our MIDIObjectLists create a Destination for the SysEx speed workaround virtual endpoint
        if ref == sysExSpeedWorkaroundEndpoint {
            return false
        }

        return true
    }

    func postObjectsAddedNotification<T: CoreMIDIObjectListable & CoreMIDIPropertyChangeHandling>(_ objects: [T]) {
        guard !objects.isEmpty else { return }
        NotificationCenter.default.post(name: .midiObjectsAppeared, object: self, userInfo: [MIDIContext.objectsThatAppeared: objects])
    }

    func postObjectListChangedNotification(_ type: MIDIObjectType) {
        NotificationCenter.default.post(name: .midiObjectListChanged, object: self, userInfo: [MIDIContext.objectType: type])
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
        var addedSource: Source?
        sourceList.objectWasAdded(midiObjectRef: midiObjectRef, parentObjectRef: 0, parentType: .other, preNotificationClosure: {
            // Immediately set the "owned by this process" flag on the object, before posting a notification about it,
            // so receivers of the notification can decide whether to pay attention to it
            addedSource = self.sourceList.findObject(objectRef: midiObjectRef)
            addedSource?.setOwnedByThisProcess()
        })
        return addedSource
    }

    func addedVirtualDestination(midiObjectRef: MIDIObjectRef) -> Destination? {
        var addedDestination: Destination?
        destinationList.objectWasAdded(midiObjectRef: midiObjectRef, parentObjectRef: 0, parentType: .other, preNotificationClosure: {
            // Immediately set the "owned by this process" flag on the object, before posting a notification about it,
            // so receivers of the notification can decide whether to pay attention to it
            addedDestination = self.destinationList.findObject(objectRef: midiObjectRef)
            addedDestination?.setOwnedByThisProcess()
        })
        return addedDestination
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
                parentType: parentType,
                preNotificationClosure: nil
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

    // MARK: Sysex speed workaround
    //
    // The CoreMIDI client caches the last device that was given to MIDISendSysex(), along with its max
    // sysex speed. When we change the speed, it doesn't notice, and continues to use the old speed.
    // To work around this, we send a tiny sysex message to a different device.
    // Unfortunately we can't just use a NULL endpoint, it has to be a real live endpoint.
    //
    // Create a virtual endpoint, like createVirtualDestination(), but avoid adding the Destination
    // to the object list. It isn't a normal endpoint and shouldn't be treated as one.

    private lazy var sysExSpeedWorkaroundDestination: Destination? = {
        var newEndpointRef: MIDIEndpointRef = 0
        guard interface.destinationCreateWithBlock(client, "Workaround" as CFString, &newEndpointRef, { _, _ in }) == noErr else { return nil }
        sysExSpeedWorkaroundEndpoint = newEndpointRef

        let destination = Destination(context: self, objectRef: newEndpointRef)
        destination.setPrivateToThisProcess()
        destination.setOwnedByThisProcess()
        while destination.uniqueID == 0 {
            destination.uniqueID = generateNewUniqueID()
        }
        destination.manufacturer = "Snoize"
        destination.model = "Workaround"

        return destination
    }()

    private var sysExSpeedWorkaroundEndpoint: MIDIObjectRef = 0

}

private func checkMainQueue() {
    dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
}

// MARK: Notifications

public extension Notification.Name {

    // notification.object is the MIDIContext
    // notification.userInfo has an array of the new objects under key MIDIContext.objectsThatAppeared
    static let midiObjectsAppeared = Notification.Name("SMMIDIObjectsAppearedNotification")

    // notification.object is the object that disappeared
    static let midiObjectDisappeared = Notification.Name("SMMIDIObjectDisappearedNotification")

    // notification.object is the object that was replaced
    // notification.userInfo contains new object under key MIDIContext.objectReplacement
    static let midiObjectWasReplaced = Notification.Name("SMMIDIObjectWasReplacedNotification")

    // notification.object is the MIDIContext
    // notification.userInfo contains the type of MIDI object that changed (MIDIObjectType)
    // under key MIDIContext.objectType
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
    static let objectType = "SMMIDIObjectType"

}

extension CoreMIDIObjectListable {

    func postObjectRemovedNotification() {
        NotificationCenter.default.post(name: .midiObjectDisappeared, object: self)
    }

    func postObjectReplacedNotification(replacement: Self) {
        NotificationCenter.default.post(name: .midiObjectWasReplaced, object: self, userInfo: [MIDIContext.objectReplacement: replacement])
    }

    func postPropertyChangedNotification(_ property: CFString) {
        NotificationCenter.default.post(name: .midiObjectPropertyChanged, object: self, userInfo: [MIDIContext.changedProperty: property])
    }

}
