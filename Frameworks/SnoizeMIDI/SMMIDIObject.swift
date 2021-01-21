/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import AVFoundation
import CoreMIDI

@objc public class SMMIDIObject: NSObject {

    // Subclasses must implement these methods so all instances of their kind of MIDIObject can be found.
    // TODO This should be a protocol on some adapter class or something

    // Returns the CoreMIDI MIDIObjectType corresponding to this subclass
    public class var midiObjectType: MIDIObjectType {
        fatalError()
    }

    // Returns the number of this kind of MIDIObjectRef that are available
    public class var midiObjectCount: Int {
        fatalError()
    }

    // Returns the MIDIObjectRef with this index
    public class func midiObject(at index: Int) -> MIDIObjectRef {
        fatalError()
    }

    // TODO Maybe that all should be some kind of collection?

    // Accessors for all objects of this type
    // NOTE: All of these methods do nothing in the base class. They work for subclasses of SMMIDIObject only.

    // TODO Do these (co-variant?) return types really work? Should be static and not class?
    // https://forums.swift.org/t/is-it-just-me-or-did-we-end-up-having-partly-staticself-in-swift/22752/5
    // https://forums.swift.org/t/how-to-return-the-runtime-self-from-a-method-like-createwrapper-wrapper-self/32317/7

    public class var allObjects: [SMMIDIObject] {
        // TODO
        return []
    }

    public class var allObjectsInOrder: [SMMIDIObject] {
        // TODO
        return []
    }

    public class func findObject(uniqueID: MIDIUniqueID) -> Self? {
        // TODO
        return nil
    }

    public class func findObject(name: String) -> Self? {
        // TODO
        return nil
    }

    public class func findObject(objectRef: MIDIObjectRef) -> Self? {
        // TODO
        return nil
    }

    // Generate a new unique ID
    public class func generateNewUniqueID() -> MIDIUniqueID {
        // TODO This really should be a function on instance that generates an ID, tries to set it, repeats until it succeeds
        fatalError()
    }

    // Single object creation and accessors

    init(objectRef: MIDIObjectRef, ordinal: Int) {
        self.objectRef = objectRef
        self.ordinal = ordinal
        super.init()
    }

    public private(set) var objectRef: MIDIObjectRef

    public var ordinal: Int

    // Specific property access

    @objc public var uniqueID: MIDIUniqueID {
        // TODO
        get {
            return 0
        }
        set {
            // TODO Setter should return succeeded/failed if it even has to be public. Only used by Source/DestinationEndpoint next to generateNewUniqueID
        }
    }

    // TODO
    @objc public var name: String? {
        get {
            fatalError()
        }
        set {
            fatalError()
        }
    }

    // Maximum SysEx speed in bytes/second
    @objc public var maxSysExSpeed: Int {
        // TODO Implement get/set
        get {
            fatalError()
        }
        set {
            fatalError()
        }
    }

    // General property access

    public func string(forProperty: CFString) -> String? {
        // Returns nil on error
        // TODO
        return nil
    }

    public func setString(_ value: String?, forProperty: CFString) {
        // Raises an exception on error
        // TODO of course don't do that
    }

    public func integer(forProperty: CFString) -> Int32 {
        // Raises an exception on error
        // TODO of course don't do that
        return 0
    }

    public func setInteger(_ value: Int32, forProperty: CFString) {
        // Raises an exception on error
        // TODO of course don't do that
    }

    // Other

    // Does nothing in base class, and returns true.
    // May be overridden in subclasses to return false if we shouldn't be setting values for properties of this object.
    public var isSettingPropertyAllowed: Bool {
        return true
        // TODO This is clumsy
    }

    // Call this to force this object to throw away any properties it may have cached.
    // Subclasses may want to override this.
    public func invalidateCachedProperties() {
        // TODO
    }

    // Called when a property of this object changes. Subclasses may override (be sure to call super's implementation).
    // Posts the notification SMMIDIObjectPropertyChangedNotification.
    public func propertyDidChange(_ property: CFString) {
        // TODO
    }

    //
    // Methods that are present on SMMIDIObject, but are for use only by SMMIDIObject subclasses,
    // not by all clients of the SnoizeMIDI framework.
    // TODO Move elsewhere
    //

    internal func clearObjectRef() {
        // TODO
    }

    internal class func midiClientCreated(_ client: SMClient) {
        // TODO
    }

    // Sent to each subclass when the first MIDI Client is created.
    internal class func initialMIDISetup() {
        // TODO
    }

    // Subclasses may use this method to immediately cause a new object to be created from a MIDIObjectRef
    // (instead of doing it when CoreMIDI sends a notification).
    // Should be sent only to SMMIDIObject subclasses, not to SMMIDIObject itself.
    internal class func immediatelyAddObject(objectRef: MIDIObjectRef) -> SMMIDIObject? {
        // TODO should return Self?
        return nil
    }

    // Similarly, subclasses may use this method to immediately cause an object to be removed from the list
    // of SMMIDIObjects of this subclass, instead of waiting for CoreMIDI to send a notification.
    // Should be sent only to SMMIDIObject subclasses, not to SMMIDIObject itself.
    internal class func immediatelyRemoveObject(_ object: SMMIDIObject) {
        // TODO
    }

    // Refresh all SMMIDIObjects of this subclass.
    // Should be sent only to SMMIDIObject subclasses, not to SMMIDIObject itself.
    internal class func refreshAllObjects() {
        // TODO
    }

    // Post a notification stating that the list of available objects of this kind of SMMIDIObject has changed.
    // Should be sent only to SMMIDIObject subclasses, not to SMMIDIObject itself.
    internal class func postObjectListChangedNotification() {
        // TODO
    }

    // Post a notification stating that an object of this kind of SMMIDIObject has been added.
    // Should be sent only to SMMIDIObject subclasses, not to SMMIDIObject itself.
    internal class func postObjectsAddedNotification(_ objects: [SMMIDIObject]) {
        // TODO
    }

    // MARK: Private

    private var cachedName: String??


}

public extension Notification.Name {

    // object is the class that has new objects
    // userInfo has an array of the new objects under key SMMIDIObjectsThatAppeared
    static let midiObjectsAppeared = Notification.Name("SMMIDIObjectsAppearedNotification")

    // object is the object that disappeared
    static let midiObjectDisappeared = Notification.Name("SMMIDIObjectDisappearedNotification")

    // object is the object that was replaced
    // userInfo contains new object under key SMMIDIObjectReplacement
    static let midiObjectWasReplaced = Notification.Name("SMMIDIObjectWasReplacedNotification")

    // object is the class that has either gained new objects or lost old ones
    // This notification is sent last, after the appeared/disappeared/wasReplaced notifications.
    static let midiObjectListChanged = Notification.Name("SMMIDIObjectListChangedNotification")

    // object is the object whose property changed
    // userInfo contains changed property's name under key SMMIDIObjectChangedPropertyName
    static let midiObjectPropertyChanged = Notification.Name("SMMIDIObjectPropertyChangedNotification")

}

@objc public extension SMMIDIObject {

    // Keys in userInfo dictionary for notifications
    static let midiObjectsThatAppeared = "SMMIDIObjectsThatAppeared"
    static let midiObjectReplacement = "SMMIDIObjectReplacement"
    static let midiObjectChangedProperty = "SMMIDIObjectChangedPropertyName"

}

// TODO Duplicate stuff while migrating from ObjC to Swift
@objc public extension NSNotification {

    static let midiObjectsAppeared = Notification.Name.midiObjectsAppeared
    static let midiObjectDisappeared = Notification.Name.midiObjectDisappeared
    static let midiObjectWasReplaced = Notification.Name.midiObjectWasReplaced
    static let midiObjectListChanged = Notification.Name.midiObjectListChanged
    static let midiObjectPropertyChanged = Notification.Name.midiObjectPropertyChanged

}
