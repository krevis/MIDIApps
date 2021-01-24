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

    subscript(property: CFString) -> String? {
        get {
            var unmanagedValue: Unmanaged<CFString>?
            if MIDIObjectGetStringProperty(midiObjectRef, property, &unmanagedValue) == noErr {
                return unmanagedValue?.takeUnretainedValue() as String?
            }
            else {
                return nil
            }
        }
        set {
            if let value = newValue {
                _ = MIDIObjectSetStringProperty(midiObjectRef, property, value as CFString)
            }
            else {
                _ = MIDIObjectRemoveProperty(midiObjectRef, property)
            }
        }
    }

    subscript(property: CFString) -> Int32? {
        get {
            var value: Int32 = 0
            if MIDIObjectGetIntegerProperty(midiObjectRef, property, &value) == noErr {
                return value
            }
            else {
                return nil
            }
        }
        set {
            if let value = newValue {
                _ = MIDIObjectSetIntegerProperty(midiObjectRef, property, value)
            }
            else {
                _ = MIDIObjectRemoveProperty(midiObjectRef, property)
            }
        }
    }

    subscript(property: CFString) -> Data? {
        get {
            var unmanagedValue: Unmanaged<CFData>?
            if MIDIObjectGetDataProperty(midiObjectRef, property, &unmanagedValue) == noErr {
                return unmanagedValue?.takeUnretainedValue() as Data?
            }
            else {
                return nil
            }
        }
        set {
            if let value = newValue {
                _ = MIDIObjectSetDataProperty(midiObjectRef, property, value as CFData)
            }
            else {
                _ = MIDIObjectRemoveProperty(midiObjectRef, property)
            }
        }
    }

}

protocol CoreMIDIPropertyChangeHandling {

    func midiPropertyChanged(_ property: CFString)

}
