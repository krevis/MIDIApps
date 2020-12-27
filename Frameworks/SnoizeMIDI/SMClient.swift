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

    @objc static public private(set) var sharedClient: SMClient? = SMClient()

    @objc static public func disposeSharedClient() {
        Self.sharedClient = nil
        // TODO After this, will the accessor create it again?
    }

    private init?(_ ignore: Bool = false) {
        let status = MIDIClientCreate(name as CFString, nil /* TODO midiNotifyProc() */, nil /* TODO UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()) */, &midiClient)
        if status != noErr {
            return nil
        }

        super.init()

        // make sure SMMIDIObject is listening for the notification below
        _ = SMMIDIObject.self.className()  // provokes +[SMMIDIObject initialize] if necessary

        NotificationCenter.default.post(name: .clientCreatedInternal, object: self)
    }

    @objc public private(set) var midiClient = MIDIClientRef()
    @objc public private(set) var name =
        (Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String) ?? ProcessInfo.processInfo.processName
    @objc public var postsExternalSetupChangeNotification = true
    @objc public private(set) var isHandlingSetupChange = false

    @objc public func forceCoreMIDIToUseNewSysExSpeed() {
        // TODO
    }

    // MARK: Internal


}

extension Notification.Name {

    static let clientCreatedInternal = Notification.Name("SMClientCreatedInternalNotification")
    // Sent when the client is created. Meant only for use by SnoizeMIDI classes. No userInfo.

    // Notifications sent as a result of CoreMIDI notifications

    // The default "something changed" kMIDIMsgSetupChanged notification from CoreMIDI:
    static let clientSetupChangedInternal = Notification.Name("SMClientSetupChangedInternalNotification")
    // Meant only for use by SnoizeMIDI classes. No userInfo.
    static public let clientSetupChanged = Notification.Name("SMClientSetupChangedNotification")
    // Public. No userInfo.

    // An object was added:
    static public let clientObjectAdded = Notification.Name("SMClientObjectAddedNotification")
    // userInfo contains:
    //   SMClientObjectAddedOrRemovedParent    NSValue (MIDIObjectRef as pointer)
    //   SMClientObjectAddedOrRemovedParentType    NSNumber (MIDIObjectType as SInt32)
    //   SMClientObjectAddedOrRemovedChild        NSValue (MIDIObjectRef as pointer)
    //   SMClientObjectAddedOrRemovedChildType    NSNumber (MIDIObjectType as SInt32)

    // An object was removed:
    static public let clientObjectRemoved = Notification.Name("SMClientObjectRemovedNotification")
    // userInfo is the same as for SMClientObjectAddedNotification above

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

    // Sent for unknown notifications from CoreMIDI:
    static public let clientUnknownChange = Notification.Name("SMClientMIDINotification")
    // userInfo contains:
    //    SMClientMIDINotificationStruct    NSValue (a pointer to a struct MIDINotification)

}

// TODO Duplicate stuff while migrating from ObjC to Swift
@objc extension NSNotification {

    static public let clientCreatedInternal = Notification.Name.clientCreatedInternal
    static public let clientSetupChangedInternal = Notification.Name.clientSetupChangedInternal
    static public let clientSetupChanged = Notification.Name.clientSetupChanged
    static public let clientObjectAdded = Notification.Name.clientObjectAdded
    static public let clientObjectRemoved = Notification.Name.clientObjectRemoved
    static public let clientObjectPropertyChanged = Notification.Name.clientObjectPropertyChanged
    static public let clientThruConnectionsChanged = Notification.Name.clientThruConnectionsChanged
    static public let clientSerialPortOwnerChanged = Notification.Name.clientSerialPortOwnerChanged
    static public let clientUnknownChange = Notification.Name.clientUnknownChange

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
