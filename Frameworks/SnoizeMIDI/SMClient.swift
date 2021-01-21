/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

@objc public class SMClientNotification: NSObject {
    // TODO A Swift struct or enum would be nicer, but then it wouldn't be visible to ObjC
    // TODO Nest these types in SMClient? But then need API notes to rename them for ObjC?
    // TODO Does any of these really even need to be exposed as API? Very little.

    fileprivate static func fromCoreMIDINotification(_ unsafeCoreMIDINotification: UnsafePointer<MIDINotification>) -> SMClientNotification {
        switch unsafeCoreMIDINotification.pointee.messageID {
        case .msgSetupChanged:
            return SMClientSetupChangedNotification(unsafeCoreMIDINotification)
        case .msgObjectAdded:
            return SMClientObjectAddedNotification(unsafeCoreMIDINotification)
        case .msgObjectRemoved:
            return SMClientObjectRemovedNotification(unsafeCoreMIDINotification)
        case .msgPropertyChanged:
            return SMClientObjectPropertyChangedNotification(unsafeCoreMIDINotification)
        case .msgThruConnectionsChanged:
            return SMClientThruConnectionsChangedNotification(unsafeCoreMIDINotification)
        case .msgSerialPortOwnerChanged:
            return SMClientSerialPortOwnerChangedNotification(unsafeCoreMIDINotification)
        case .msgIOError:
            return SMClientIOErrorNotification(unsafeCoreMIDINotification)
        @unknown default:
            return SMClientNotification(unsafeCoreMIDINotification)
        }
    }

    fileprivate init(_ unsafeCoreMIDINotification: UnsafePointer<MIDINotification>) {
        messageSize = Int(unsafeCoreMIDINotification.pointee.messageSize)
        messageID = unsafeCoreMIDINotification.pointee.messageID
        super.init()

        // NOTE: It's tempting to copy the whole data buffer of `messageSize`
        // in order to extract data later. For instance, for unknown notifications,
        // we could just expose that data to clients, right?
        // Unfortunately, that only works if all of the types in the notification
        // are trivial or immortal, and we have no way of knowing that for arbitrary
        // notifications.
        // Things like the Unmanaged<CFString> in MIDIObjectPropertyChangeNotification
        // are a problem; to keep it around indefinitely, we would need to
        // know that it's there, to retain it initially, and to manage its retain count
        // when passing out references to it later.
    }

    @objc public let messageSize: Int
    @objc public let messageID: MIDINotificationMessageID

    fileprivate func dispatchToClient(_ client: SMClient) {
        client.unknownMIDINotification(self)
    }
}

@objc public class SMClientSetupChangedNotification: SMClientNotification {

    fileprivate override func dispatchToClient(_ client: SMClient) {
        client.setupChanged(self)
    }

}

@objc public class SMClientObjectAddedOrRemovedNotification: SMClientNotification {

    fileprivate override init(_ unsafeCoreMIDINotification: UnsafePointer<MIDINotification>) {
        let addRemoveNotification = UnsafeRawPointer(unsafeCoreMIDINotification).load(as: MIDIObjectAddRemoveNotification.self)
        parent = addRemoveNotification.parent
        parentType = addRemoveNotification.parentType
        child = addRemoveNotification.child
        childType = addRemoveNotification.childType
        super.init(unsafeCoreMIDINotification)
    }

    @objc public let parent: MIDIObjectRef
    @objc public let parentType: MIDIObjectType
    @objc public let child: MIDIObjectRef
    @objc public let childType: MIDIObjectType

    fileprivate override func dispatchToClient(_ client: SMClient) {
        fatalError()    // must be overridden
    }

}

@objc public class SMClientObjectAddedNotification: SMClientObjectAddedOrRemovedNotification {

    fileprivate override func dispatchToClient(_ client: SMClient) {
        client.objectAdded(self)
    }

}

@objc public class SMClientObjectRemovedNotification: SMClientObjectAddedOrRemovedNotification {

    fileprivate override func dispatchToClient(_ client: SMClient) {
        client.objectRemoved(self)
    }

}

@objc public class SMClientObjectPropertyChangedNotification: SMClientNotification {

    fileprivate override init(_ unsafeCoreMIDINotification: UnsafePointer<MIDINotification>) {
        let propertyChangedNotification = UnsafeRawPointer(unsafeCoreMIDINotification).load(as: MIDIObjectPropertyChangeNotification.self)
        object = propertyChangedNotification.object
        objectType = propertyChangedNotification.objectType
        propertyName = propertyChangedNotification.propertyName.takeUnretainedValue() as String
        super.init(unsafeCoreMIDINotification)
    }

    @objc public let object: MIDIObjectRef
    @objc public let objectType: MIDIObjectType
    @objc public let propertyName: String

    fileprivate override func dispatchToClient(_ client: SMClient) {
        client.objectPropertyChanged(self)
    }

}

@objc public class SMClientThruConnectionsChangedNotification: SMClientNotification {

    fileprivate override func dispatchToClient(_ client: SMClient) {
        client.thruConnectionsChanged(self)
    }

}

@objc public class SMClientSerialPortOwnerChangedNotification: SMClientNotification {

    fileprivate override func dispatchToClient(_ client: SMClient) {
        client.serialPortOwnerChanged(self)
    }

}

@objc public class SMClientIOErrorNotification: SMClientNotification {

    fileprivate override init(_ unsafeCoreMIDINotification: UnsafePointer<MIDINotification>) {
        let ioErrorNotification = UnsafeRawPointer(unsafeCoreMIDINotification).load(as: MIDIIOErrorNotification.self)
        driverDevice = ioErrorNotification.driverDevice
        errorCode = ioErrorNotification.errorCode
        super.init(unsafeCoreMIDINotification)
    }

    @objc public let driverDevice: MIDIDeviceRef
    @objc public let errorCode: OSStatus

    fileprivate override func dispatchToClient(_ client: SMClient) {
        client.ioError(self)
    }

}

@objc public class SMClient: NSObject {

    @objc static public let sharedClient = SMClient()

    private init?(_ ignore: Bool = false) {
        checkMainQueue()

        let status: OSStatus
        if #available(macOS 10.11, iOS 9.0, *) {
            status = MIDIClientCreateWithBlock(name as CFString, &midiClient) { unsafeNotification in
                // Note: We can't capture `self` in here, since we aren't yet fully initialized.
                // Also note that we are called on an arbitrary queue, so we need to dispatch to the main queue for later handling.
                // But `unsafeNotification` is only valid during this function call.

                // TODO In practice this sometimes comes in on the main queue,
                // so perhaps optimize for that?
                let ourNotification = SMClientNotification.fromCoreMIDINotification(unsafeNotification)
                DispatchQueue.main.async {
                    if let client = Self.sharedClient {
                        ourNotification.dispatchToClient(client)
                    }
                }
            }
        }
        else {
            status = MIDIClientCreate(name as CFString, { (unsafeNotification, _) in
                // As above, we can't use the refCon to stash a pointer to self, because
                // when we create the client, self isn't done being initialized yet.
                // We assume CoreMIDI is following its documentation, calling us "on the run loop which
                // was current when MIDIClientCreate was first called", which must be the main queue's run loop.
                let ourNotification = SMClientNotification.fromCoreMIDINotification(unsafeNotification)
                if let client = SMClient.sharedClient {
                    ourNotification.dispatchToClient(client)
                }
            }, nil, &midiClient)
        }

        if status != noErr {
            return nil
        }

        super.init()

        SMMIDIObject.midiClientCreated(self)
    }

    @objc public private(set) var midiClient = MIDIClientRef()
        // Note: This is actually a typedef to an int, not a pointer like you'd expect,
        // so this initializer just makes it 0. It's overwritten later.
    @objc public let name =
        (Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String) ?? ProcessInfo.processInfo.processName
    @objc public var postsExternalSetupChangeNotification = true    // TODO Should this be public? Seems like an internal detail
    @objc public private(set) var isHandlingSetupChange = false

    @objc public func forceCoreMIDIToUseNewSysExSpeed() {
        // The CoreMIDI client caches the last device that was given to MIDISendSysex(), along with its max sysex speed.
        // So when we change the speed, it doesn't notice and continues to use the old speed.
        // To fix this, we send a tiny sysex message to a different device.  Unfortunately we can't just use a NULL endpoint,
        // it has to be a real live endpoint.

        // TODO None of this code is marked as actually throwing -- resolve that
        do {
            if let endpoint = SMDestinationEndpoint.sysExSpeedWorkaroundEndpoint {
               let message = SMSystemExclusiveMessage(timeStamp: 0, data: Data())
                _ = SMSysExSendRequest(message: message, endpoint: endpoint)?.send()
            }
        }
        catch {
            // don't care
        }
    }

    @objc public func disconnectCoreMIDI() {
        // Disconnect from CoreMIDI. Necessary only for very special circumstances, since CoreMIDI will be unusable afterwards.
        _ = MIDIClientDispose(midiClient)
        midiClient = MIDIClientRef()
    }

    // MARK: Notifications

    private func userInfo(_ notification: SMClientNotification) -> [String: Any] {
        return [SMClient.notification: notification]
    }

    fileprivate func unknownMIDINotification(_ notification: SMClientNotification) {
        checkMainQueue()
        NotificationCenter.default.post(name: .clientUnknownNotification,
                                        object: self,
                                        userInfo: userInfo(notification))
    }

    fileprivate func setupChanged(_ notification: SMClientSetupChangedNotification) {
        checkMainQueue()
        // TODO Do we really still need this? The other notifications are more specific.
        // TODO Timing of this will be different if we are using the block-based notification,
        // which will mess up the way we fiddle with these flags. Ugh.
        if postsExternalSetupChangeNotification {
            isHandlingSetupChange = true
            NotificationCenter.default.post(name: .clientSetupChanged,
                                            object: self,
                                            userInfo: userInfo(notification))
            isHandlingSetupChange = false
        }
    }

    fileprivate func objectAdded(_ notification: SMClientObjectAddedNotification) {
        checkMainQueue()
        NotificationCenter.default.post(name: .clientObjectAdded,
                                        object: self,
                                        userInfo: userInfo(notification))
    }

    fileprivate func objectRemoved(_ notification: SMClientObjectRemovedNotification) {
        checkMainQueue()
        NotificationCenter.default.post(name: .clientObjectRemoved,
                                        object: self,
                                        userInfo: userInfo(notification))
    }

    fileprivate func objectPropertyChanged(_ notification: SMClientObjectPropertyChangedNotification) {
        checkMainQueue()
        NotificationCenter.default.post(name: .clientObjectPropertyChanged,
                                        object: self,
                                        userInfo: userInfo(notification))
    }

    fileprivate func thruConnectionsChanged(_ notification: SMClientThruConnectionsChangedNotification) {
        checkMainQueue()
        NotificationCenter.default.post(name: .clientThruConnectionsChanged,
                                        object: self,
                                        userInfo: userInfo(notification))
    }

    fileprivate func serialPortOwnerChanged(_ notification: SMClientSerialPortOwnerChangedNotification) {
        checkMainQueue()
        NotificationCenter.default.post(name: .clientSerialPortOwnerChanged,
                                        object: self,
                                        userInfo: userInfo(notification))
    }

    fileprivate func ioError(_ notification: SMClientIOErrorNotification) {
        checkMainQueue()
        NotificationCenter.default.post(name: .clientIOError,
                                        object: self,
                                        userInfo: userInfo(notification))
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

public extension Notification.Name {

    // TODO Re-evaluate all of this. Is it really useful to just repackage all CoreMIDI notifications as Notifications?

    // Notifications posted as a result of CoreMIDI notifications.
    // All have userInfo like [SMClient.notification: clientNotification],
    // where clientNotification is a SMClientNotification or subclass, as described below.

    // The default "something changed" kMIDIMsgSetupChanged notification from CoreMIDI.
    // Posted only if `postsExternalSetupChangeNotification` is true.
    // userInfo contains an SMClientNotification.
    static let clientSetupChanged = Notification.Name("SMClientSetupChangedNotification")

    // An object was added.
    // userInfo contains an SMClientObjectAddedNotification.
    static let clientObjectAdded = Notification.Name("SMClientObjectAddedNotification")

    // An object was removed.
    // userInfo contains an SMClientObjectRemovedNotification.
    static let clientObjectRemoved = Notification.Name("SMClientObjectRemovedNotification")

    // A property of an object changed.
    // userInfo contains an SMClientObjectPropertyChangedNotification.
    static let clientObjectPropertyChanged = Notification.Name("SMClientObjectPropertyChangedNotification")

    // A MIDI Thru connection changed.
    // userInfo contains an SMClientNotification.
    static let clientThruConnectionsChanged = Notification.Name("SMClientThruConnectionsChangedNotification")

    // An owner of a serial port changed.
    // userInfo contains an SMClientNotification.
    static let clientSerialPortOwnerChanged = Notification.Name("SMClientSerialPortOwnerChangedNotification")

    // An MIDI driver experienced an I/O error.
    // userInfo contains an SMClientIOErrorNotification.
    static let clientIOError = Notification.Name("SMClientIOErrorNotification")

    // An unknown notification was sent from CoreMIDI.
    // userInfo contains an SMClientNotification.
    static let clientUnknownNotification = Notification.Name("SMClientMIDINotification")

}

// TODO Duplicate stuff while migrating from ObjC to Swift
@objc public extension NSNotification {

    static let clientSetupChanged = Notification.Name.clientSetupChanged
    static let clientObjectAdded = Notification.Name.clientObjectAdded
    static let clientObjectRemoved = Notification.Name.clientObjectRemoved
    static let clientObjectPropertyChanged = Notification.Name.clientObjectPropertyChanged
    static let clientThruConnectionsChanged = Notification.Name.clientThruConnectionsChanged
    static let clientSerialPortOwnerChanged = Notification.Name.clientSerialPortOwnerChanged
    static let clientIOErrorNotification = Notification.Name.clientIOError
    static let clientUnknownNotification = Notification.Name.clientUnknownNotification

}

extension SMClient {

    // Key in Notification's userInfo dictionary.
    // Value is a SMClientNotification or subclass, as documented above.
    @objc static public let notification = "SMClientNotification"

}
