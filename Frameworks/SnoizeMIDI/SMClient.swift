/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

@objc public class SMClient: NSObject {

    @objc static public let sharedClient = SMClient()

    private init?(_ ignore: Bool = false) {
        if #available(OSX 10.11, *) {
            let status = MIDIClientCreateWithBlock(name as CFString, &midiClient) { (notification: UnsafePointer<MIDINotification>) in
                // Note: We can't pass `self` here since we aren't yet fully initialized.
                Self.sharedClient?.handleMIDINotification(notification)
            }

            if status != noErr {
                return nil
            }
        }
        else {
            // TODO For 10.9 and 10.10, implement some kind of wrapper, following the pattern of MIDIClientCreateWithBlock?
            //      It will almost certainly need to be implemented in ObjC.
            //        let status = MIDIClientCreate(name as CFString, nil /*  midiNotifyProc() */, nil /*  UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()) */, &midiClient)

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
            if let endpoint = SMDestinationEndpoint.sysExSpeedWorkaround(),
               let message = SMSystemExclusiveMessage(timeStamp: 0, data: Data()) {
                SMSysExSendRequest(message: message, endpoint: endpoint).send()
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

    // MARK: Internal

    private func handleMIDINotification(_ unsafeNotification: UnsafePointer<MIDINotification>) {
        let notification = unsafeNotification.pointee
        switch notification.messageID {
        case .msgSetupChanged:
            midiSetupChanged()

        case .msgObjectAdded:
            unsafeNotification.withMemoryRebound(to: MIDIObjectAddRemoveNotification.self, capacity: 1) {
                midiObjectAddedOrRemoved($0.pointee, name: .clientObjectAdded)
            }

        case .msgObjectRemoved:
            unsafeNotification.withMemoryRebound(to: MIDIObjectAddRemoveNotification.self, capacity: 1) {
                midiObjectAddedOrRemoved($0.pointee, name: .clientObjectRemoved)
            }

        case .msgPropertyChanged:
            unsafeNotification.withMemoryRebound(to: MIDIObjectPropertyChangeNotification.self, capacity: 1) {
                midiObjectPropertyChanged($0.pointee)
            }

        case .msgThruConnectionsChanged:
            NotificationCenter.default.post(name: .clientThruConnectionsChanged,
                                            object: self,
                                            userInfo: [SMClient.midiNotificationStruct: NSValue(pointer: unsafeNotification)])

        case .msgSerialPortOwnerChanged:
            NotificationCenter.default.post(name: .clientSerialPortOwnerChanged,
                                            object: self,
                                            userInfo: [SMClient.midiNotificationStruct: NSValue(pointer: unsafeNotification)])

        case .msgIOError:
            unsafeNotification.withMemoryRebound(to: MIDIIOErrorNotification.self, capacity: 1) {
                NotificationCenter.default.post(name: .clientMIDIIOError,
                                                object: self,
                                                userInfo: [SMClient.midiNotificationStruct: NSValue(pointer: $0)])
            }

        default:
            NotificationCenter.default.post(name: .clientUnknownNotification,
                                            object: self,
                                            userInfo: [SMClient.midiNotificationStruct: NSValue(pointer: unsafeNotification)])
        }
    }

    private func midiSetupChanged() {
        if postsExternalSetupChangeNotification {
            isHandlingSetupChange = true
            NotificationCenter.default.post(name: .clientSetupChanged, object: self)
            isHandlingSetupChange = false
        }
    }

    private func midiObjectAddedOrRemoved(_ notification: MIDIObjectAddRemoveNotification, name: Notification.Name) {
        let userInfo: [String: Any] = [
            SMClient.objectAddedOrRemovedParent: NSNumber(value: notification.parent),
            SMClient.objectAddedOrRemovedParentType: NSNumber(value: notification.parentType.rawValue),
            SMClient.objectAddedOrRemovedChild: NSNumber(value: notification.child),
            SMClient.objectAddedOrRemovedChildType: NSNumber(value: notification.childType.rawValue)
        ]
        NotificationCenter.default.post(name: name, object: self, userInfo: userInfo)
    }

    private func midiObjectPropertyChanged(_ notification: MIDIObjectPropertyChangeNotification) {
        let userInfo: [String: Any] = [
            SMClient.propertyChangedObject: NSNumber(value: notification.object),
            SMClient.propertyChangedType: NSNumber(value: notification.objectType.rawValue),
            SMClient.propertyChangedName: notification.propertyName.takeUnretainedValue()
        ]
        NotificationCenter.default.post(name: .clientObjectPropertyChanged, object: self, userInfo: userInfo)
    }

}

extension Notification.Name {

    // TODO Re-evaluate all of this. Is it really useful to just repackage the CoreMIDI notification in a dictionary? Doubtful.

    // Notifications sent as a result of CoreMIDI notifications

    // The default "something changed" kMIDIMsgSetupChanged notification from CoreMIDI.
    // No userInfo.
    // Posted only if `postsExternalSetupChangeNotification` is true.
    static public let clientSetupChanged = Notification.Name("SMClientSetupChangedNotification")

    // An object was added or removed:
    static public let clientObjectAdded = Notification.Name("SMClientObjectAddedNotification")
    static public let clientObjectRemoved = Notification.Name("SMClientObjectRemovedNotification")
    // userInfo contains:
    //   SMClientObjectAddedOrRemovedParent    NSValue (MIDIObjectRef as pointer)
    //   SMClientObjectAddedOrRemovedParentType    NSNumber (MIDIObjectType as SInt32)
    //   SMClientObjectAddedOrRemovedChild        NSValue (MIDIObjectRef as pointer)
    //   SMClientObjectAddedOrRemovedChildType    NSNumber (MIDIObjectType as SInt32)

    // A property of an object changed:
    static public let clientObjectPropertyChanged = Notification.Name("SMClientObjectPropertyChangedNotification")
    // userInfo contains:
    //   SMClientObjectPropertyChangedObject        NSValue (MIDIObjectRef as pointer)
    //   SMClientObjectPropertyChangedType        NSNumber (MIDIObjectType as SInt32)
    //   SMClientObjectPropertyChangedName        NSString

    // A MIDI Thru connection changed:
    static public let clientThruConnectionsChanged = Notification.Name("SMClientThruConnectionsChangedNotification")
    // userInfo contains:
    //    SMClientMIDINotificationStruct    NSValue (a pointer to a struct MIDINotification)

    // An owner of a serial port changed:
    static public let clientSerialPortOwnerChanged = Notification.Name("SMClientSerialPortOwnerChangedNotification")
    // userInfo contains:
    //    SMClientMIDINotificationStruct    NSValue (a pointer to a struct MIDINotification)

    // An MIDI driver experienced an I/O error:
    static public let clientMIDIIOError = Notification.Name("SMClientMIDIIOErrorNotification")
    // userInfo contains:
    //    SMClientMIDINotificationStruct    NSValue (a pointer to a struct MIDIIOErrorNotification)

    // Sent for unknown notifications from CoreMIDI:
    static public let clientUnknownNotification = Notification.Name("SMClientMIDINotification")
    // userInfo contains:
    //    SMClientMIDINotificationStruct    NSValue (a pointer to a struct MIDINotification)

}

// TODO Duplicate stuff while migrating from ObjC to Swift
@objc extension NSNotification {

    static public let clientSetupChanged = Notification.Name.clientSetupChanged
    static public let clientObjectAdded = Notification.Name.clientObjectAdded
    static public let clientObjectRemoved = Notification.Name.clientObjectRemoved
    static public let clientObjectPropertyChanged = Notification.Name.clientObjectPropertyChanged
    static public let clientThruConnectionsChanged = Notification.Name.clientThruConnectionsChanged
    static public let clientSerialPortOwnerChanged = Notification.Name.clientSerialPortOwnerChanged
    static public let clientMIDIIOErrorNotification = Notification.Name.clientMIDIIOError
    static public let clientUnknownNotification = Notification.Name.clientUnknownNotification

}

extension SMClient {

    @objc static public let objectAddedOrRemovedParent = "SMClientObjectAddedOrRemovedParent"
    @objc static public let objectAddedOrRemovedParentType = "SMClientObjectAddedOrRemovedParentType"
    @objc static public let objectAddedOrRemovedChild = "SMClientObjectAddedOrRemovedChild"
    @objc static public let objectAddedOrRemovedChildType = "SMClientObjectAddedOrRemovedChildType"

    @objc static public let propertyChangedObject = "SMClientObjectPropertyChangedObject"
    @objc static public let propertyChangedType = "SMClientObjectPropertyChangedType"
    @objc static public let propertyChangedName = "SMClientObjectPropertyChangedName"

    @objc static public let midiNotificationStruct = "SMClientMIDINotificationStruct"

}
