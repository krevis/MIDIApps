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

protocol CoreMIDIObjectWrapper: AnyObject, Equatable, Identifiable {

    var midiContext: CoreMIDIContext { get }
    var midiObjectRef: MIDIObjectRef { get }

}

extension CoreMIDIObjectWrapper {

    // MARK: Identifiable default implementation

    var id: (CoreMIDIContext, MIDIObjectRef) { (midiContext, midiObjectRef) } // swiftlint:disable:this identifier_name

    // MARK: Equatable default implementation

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: MIDI Property Accessors

    subscript(property: CFString) -> String? {
        get {
            var unmanagedValue: Unmanaged<CFString>?
            if midiContext.interface.objectGetStringProperty(midiObjectRef, property, &unmanagedValue) == noErr {
                return unmanagedValue?.takeUnretainedValue() as String?
            }
            else {
                return nil
            }
        }
        set {
            if let value = newValue {
                _ = midiContext.interface.objectSetStringProperty(midiObjectRef, property, value as CFString)
            }
            else {
                _ = midiContext.interface.objectRemoveProperty(midiObjectRef, property)
            }
        }
    }

    subscript(property: CFString) -> Int32? {
        get {
            var value: Int32 = 0
            if midiContext.interface.objectGetIntegerProperty(midiObjectRef, property, &value) == noErr {
                return value
            }
            else {
                return nil
            }
        }
        set {
            if let value = newValue {
                _ = midiContext.interface.objectSetIntegerProperty(midiObjectRef, property, value)
            }
            else {
                _ = midiContext.interface.objectRemoveProperty(midiObjectRef, property)
            }
        }
    }

    subscript(property: CFString) -> Data? {
        get {
            var unmanagedValue: Unmanaged<CFData>?
            if midiContext.interface.objectGetDataProperty(midiObjectRef, property, &unmanagedValue) == noErr {
                return unmanagedValue?.takeUnretainedValue() as Data?
            }
            else {
                return nil
            }
        }
        set {
            if let value = newValue {
                _ = midiContext.interface.objectSetDataProperty(midiObjectRef, property, value as CFData)
            }
            else {
                _ = midiContext.interface.objectRemoveProperty(midiObjectRef, property)
            }
        }
    }

}

protocol CoreMIDIPropertyChangeHandling {

    func midiPropertyChanged(_ property: CFString)

}
