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

// MARK: CoreMIDI Object Wrapper

protocol CoreMIDIObjectWrapper: AnyObject, Hashable {

    var midiContext: CoreMIDIContext { get }
    var midiObjectRef: MIDIObjectRef { get }

}

extension CoreMIDIObjectWrapper {

    // MARK: Equatable default implementation

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.midiContext.client == rhs.midiContext.client && lhs.midiObjectRef == rhs.midiObjectRef
    }

    // MARK: Hashable default implementation

    public func hash(into hasher: inout Hasher) {
        hasher.combine(midiContext.client)
        hasher.combine(midiObjectRef)
    }

}

// FUTURE: CoreMIDIObjectWrapper could conform to Identifiable, with an id
// containing the midiContext (or midiContext.client) and midiObjectRef.
// That could be a struct that we define, or a tuple (when Swift supports
// tuples being Hashable).
// (But remember that Identifiable requires macOS 10.15 or later.)

// MARK: MIDI Property Accessors

protocol CoreMIDIPropertyValue {

    static func getValue(_ midiContext: CoreMIDIContext, _ midiObjectRef: MIDIObjectRef, _ property: CFString) -> Self?
    static func setValue(_ midiContext: CoreMIDIContext, _ midiObjectRef: MIDIObjectRef, _ property: CFString, _ value: Self?)

}

extension Int32: CoreMIDIPropertyValue {

    static func getValue(_ midiContext: CoreMIDIContext, _ midiObjectRef: MIDIObjectRef, _ property: CFString) -> Self? {
        var value: Int32 = 0
        if midiContext.interface.objectGetIntegerProperty(midiObjectRef, property, &value) == noErr {
            return value
        }
        else {
            return nil
        }
    }

    static func setValue(_ midiContext: CoreMIDIContext, _ midiObjectRef: MIDIObjectRef, _ property: CFString, _ value: Self?) {
        if let someValue = value {
            _ = midiContext.interface.objectSetIntegerProperty(midiObjectRef, property, someValue)
        }
        else {
            _ = midiContext.interface.objectRemoveProperty(midiObjectRef, property)
        }
    }

}

extension String: CoreMIDIPropertyValue {

    static func getValue(_ midiContext: CoreMIDIContext, _ midiObjectRef: MIDIObjectRef, _ property: CFString) -> Self? {
        var unmanagedValue: Unmanaged<CFString>?
        if midiContext.interface.objectGetStringProperty(midiObjectRef, property, &unmanagedValue) == noErr {
            return unmanagedValue?.takeUnretainedValue() as String?
        }
        else {
            return nil
        }
    }

    static func setValue(_ midiContext: CoreMIDIContext, _ midiObjectRef: MIDIObjectRef, _ property: CFString, _ value: Self?) {
        if let someValue = value {
            _ = midiContext.interface.objectSetStringProperty(midiObjectRef, property, someValue as CFString)
        }
        else {
            _ = midiContext.interface.objectRemoveProperty(midiObjectRef, property)
        }
    }

}

extension Data: CoreMIDIPropertyValue {

    static func getValue(_ midiContext: CoreMIDIContext, _ midiObjectRef: MIDIObjectRef, _ property: CFString) -> Self? {
        var unmanagedValue: Unmanaged<CFData>?
        if midiContext.interface.objectGetDataProperty(midiObjectRef, property, &unmanagedValue) == noErr {
            return unmanagedValue?.takeUnretainedValue() as Data?
        }
        else {
            return nil
        }
    }

    static func setValue(_ midiContext: CoreMIDIContext, _ midiObjectRef: MIDIObjectRef, _ property: CFString, _ value: Self?) {
        if let someValue = value {
            _ = midiContext.interface.objectSetDataProperty(midiObjectRef, property, someValue as CFData)
        }
        else {
            _ = midiContext.interface.objectRemoveProperty(midiObjectRef, property)
        }
    }

}

extension CoreMIDIObjectWrapper {

    subscript<T: CoreMIDIPropertyValue>(property: CFString) -> T? {
        get {
            T.getValue(midiContext, midiObjectRef, property)
        }
        set {
            T.setValue(midiContext, midiObjectRef, property, newValue)
        }
    }

}

// MARK: Property Changes

protocol CoreMIDIPropertyChangeHandling {

    func midiPropertyChanged(_ property: CFString)

    func invalidateCachedProperties()

}
