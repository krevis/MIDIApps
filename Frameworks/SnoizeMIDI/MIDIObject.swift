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

class MIDIObject: CoreMIDIObjectWrapper, CoreMIDIPropertyChangeHandling {

    unowned var midiClient: SMClient
    let midiObjectRef: MIDIObjectRef

    required init(client: SMClient, midiObjectRef: MIDIObjectRef) {
        precondition(midiObjectRef != 0)

        self.midiClient = client
        self.midiObjectRef = midiObjectRef

        // Immediately fetch the object's uniqueID, since it could become
        // inaccessible later, if the object is removed from CoreMIDI
        cachedUniqueID = self[kMIDIPropertyUniqueID] ?? 0
    }

    // MARK: Cached values of properties

    private var cachedUniqueID: MIDIUniqueID?
    public var uniqueID: MIDIUniqueID {
        get {
            if let value = cachedUniqueID {
                return value
            }
            else {
                let value: MIDIUniqueID = self[kMIDIPropertyUniqueID] ?? 0
                cachedUniqueID = .some(value)
                return value
            }
        }
        set {
            if cachedUniqueID != .some(newValue) {
                self[kMIDIPropertyUniqueID] = newValue
                cachedUniqueID = .none
            }
        }
    }

    private var cachedName: String??
    public var name: String? {
        get {
            if let value = cachedName {
                return value
            }
            else {
                let value: String? = self[kMIDIPropertyName]
                cachedName = .some(value)
                return value
            }
        }
        set {
            if cachedName != .some(newValue) {
                self[kMIDIPropertyName] = newValue
                cachedName = .none
            }
        }
    }

    func midiPropertyChanged(_ property: CFString) {
        switch property {
        case kMIDIPropertyName:
            cachedName = .none
        case kMIDIPropertyUniqueID:
            cachedUniqueID = .none
            _ = uniqueID    // refetch immediately
        default:
            break
        }
    }

}
