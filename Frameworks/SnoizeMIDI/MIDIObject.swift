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

public class MIDIObject: CoreMIDIObjectWrapper, CoreMIDIPropertyChangeHandling {

    unowned var midiContext: CoreMIDIContext
    private(set) var midiObjectRef: MIDIObjectRef

    required init(context: CoreMIDIContext, objectRef: MIDIObjectRef) {
        precondition(objectRef != 0)

        self.midiContext = context
        self.midiObjectRef = objectRef

        cacheInt32Property(kMIDIPropertyUniqueID)
        cacheStringProperty(kMIDIPropertyName)
        cacheInt32Property(kMIDIPropertyMaxSysExSpeed)

        // Immediately cache the object's uniqueID, since it could become
        // inaccessible later, if the object is removed from CoreMIDI
        _ = uniqueID
    }

    // MARK: Property value cache

    private var cachedInt32Properties: [CFString: CachedProperty<Int32>] = [:]
    func cacheInt32Property(_ property: CFString) {
        let cachedProperty = CachedProperty<Int32>(getter: { self[property] }, setter: { self[property] = $0 })
        cachedInt32Properties[property] = cachedProperty
    }

    private var cachedStringProperties: [CFString: CachedProperty<String>] = [:]
    func cacheStringProperty(_ property: CFString) {
        let cachedProperty = CachedProperty<String>(getter: { self[property] }, setter: { self[property] = $0 })
        cachedStringProperties[property] = cachedProperty
    }

    private var cachedDataProperties: [CFString: CachedProperty<Data>] = [:]
    func cacheDataProperty(_ property: CFString) {
        let cachedProperty = CachedProperty<Data>(getter: { self[property] }, setter: { self[property] = $0 })
        cachedDataProperties[property] = cachedProperty
    }

    func getCachedProperty(_ property: CFString) -> Int32? {
        cachedInt32Properties[property]?.value
    }
    func setCachedProperty(_ property: CFString, _ value: Int32?) {
        cachedInt32Properties[property]?.value = value
    }
    func getCachedProperty(_ property: CFString) -> String? {
        cachedStringProperties[property]?.value
    }
    func setCachedProperty(_ property: CFString, _ value: String?) {
        cachedStringProperties[property]?.value = value
    }
    func getCachedProperty(_ property: CFString) -> Data? {
        cachedDataProperties[property]?.value
    }
    func setCachedProperty(_ property: CFString, _ value: Data?) {
        cachedDataProperties[property]?.value = value
    }

    func invalidateCachedProperty(_ property: CFString) {
        // TODO would be nice to only do one lookup not 3
        cachedInt32Properties[property]?.invalidate()
        cachedDataProperties[property]?.invalidate()
        cachedStringProperties[property]?.invalidate()

        // Always refetch the uniqueID immediately, since we might need it
        // in order to do lookups, and I don't trust that we will always
        // be notified of changes.
        if property == kMIDIPropertyUniqueID {
            _ = uniqueID
        }
    }

    // MARK: Specific properties

    private let fallbackUniqueID: MIDIUniqueID = 0
    public var uniqueID: MIDIUniqueID {
        get { getCachedProperty(kMIDIPropertyUniqueID) ?? fallbackUniqueID  }
        set { setCachedProperty(kMIDIPropertyUniqueID, newValue) }
    }

    public var name: String? {
        get { getCachedProperty(kMIDIPropertyName) }
        set { setCachedProperty(kMIDIPropertyName, newValue) }
    }

    private let fallbackMaxSysExSpeed: Int32 = 3125 // bytes/sec for MIDI 1.0
    public var maxSysExSpeed: Int32 {
        get { getCachedProperty(kMIDIPropertyMaxSysExSpeed) ?? fallbackUniqueID  }
        set { setCachedProperty(kMIDIPropertyMaxSysExSpeed, newValue) }
    }

    // MARK: Property changes

    func midiPropertyChanged(_ property: CFString) {
        invalidateCachedProperty(property)
    }

    // MARK: Internal functions for rare uses

    func invalidateCachedProperties() {
        for propertyName in cachedInt32Properties.keys {
            invalidateCachedProperty(propertyName)
        }
        for propertyName in cachedStringProperties.keys {
            invalidateCachedProperty(propertyName)
        }
        for propertyName in cachedDataProperties.keys {
            invalidateCachedProperty(propertyName)
        }
    }

    func clearMIDIObjectRef() {
        // Called when this object has been removed from CoreMIDI
        // and it should no longer be used.
        midiObjectRef = 0
    }

}
