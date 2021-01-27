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

        // Immediately cache the object's uniqueID, since it could become
        // inaccessible later, if the object is removed from CoreMIDI
        _ = uniqueID
    }

    // MARK: Property value cache

    struct CacheKey: Hashable {
        let property: CFString
    }

    private var cachedProperties: [CacheKey: AnyPropertyCache] = [:]

    typealias CacheableValue = CoreMIDIPropertyValue & Equatable

    func cacheProperty<T: CacheableValue>(_ property: CFString, _ type: T.Type) -> CacheKey {
        let cacheKey = CacheKey(property: property)
        guard cachedProperties[cacheKey] == nil else { fatalError("Trying to cache the same property twice: \(property)") }
        let typedPropertyCache = TypedPropertyCache<T>(
            getter: { self[property] },
            setter: { self[property] = $0 }
        )
        cachedProperties[cacheKey] = AnyPropertyCache(base: typedPropertyCache)
        return cacheKey
    }

    private func withTypedPropertyCache<T: CacheableValue, Result>(_ cacheKey: CacheKey, _ perform: ((inout TypedPropertyCache<T>) -> Result)) -> Result {
        // Get the property cache, unbox it, do something with it, and box it again.
        guard let anyPropertyCache = cachedProperties[cacheKey] else { fatalError("Cache is missing for key \(cacheKey.property)") }
        guard var typedPropertyCache = anyPropertyCache.base as? TypedPropertyCache<T> else { fatalError("Cache is wrong type for key \(cacheKey.property)") }

        let result = perform(&typedPropertyCache)

        // That may have modified typedPropertyCache, which was a local copy,
        // so write it back
        cachedProperties[cacheKey] = AnyPropertyCache(base: typedPropertyCache)

        return result
    }

    subscript<T: CacheableValue>(cacheKey: CacheKey) -> T? {
        get {
            withTypedPropertyCache(cacheKey) { $0.value }
        }
        set {
            withTypedPropertyCache(cacheKey) { $0.value = newValue }
        }
    }

    func invalidateCachedProperty(_ property: CFString) {
        cachedProperties[CacheKey(property: property)]?.base.invalidate()
        // Note: That didn't need to manually write back to the cache, it modified the value in place

        // Always refetch the uniqueID immediately, since we might need it
        // in order to do lookups, and I don't trust that we will always
        // be notified of changes.
        if property == kMIDIPropertyUniqueID {
            _ = uniqueID
        }
    }

    // MARK: Specific properties

    private lazy var uniqueIDCacheKey = cacheProperty(kMIDIPropertyUniqueID, MIDIUniqueID.self)
    private let fallbackUniqueID: MIDIUniqueID = 0
    public var uniqueID: MIDIUniqueID {
        get { self[uniqueIDCacheKey] ?? fallbackUniqueID }
        set { self[uniqueIDCacheKey] = newValue }
    }

    private lazy var nameCacheKey = cacheProperty(kMIDIPropertyName, String.self)
    public var name: String? {
        get { self[nameCacheKey] }
        set { self[nameCacheKey] = newValue }
    }

    private lazy var maxSysExCacheKey = cacheProperty(kMIDIPropertyMaxSysExSpeed, Int32.self)
    private let fallbackMaxSysExSpeed: Int32 = 3125 // bytes/sec for MIDI 1.0
    public var maxSysExSpeed: Int32 {
        get { self[maxSysExCacheKey] ?? fallbackMaxSysExSpeed }
        set { self[maxSysExCacheKey] = newValue }
    }

    // MARK: Property changes

    func midiPropertyChanged(_ property: CFString) {
        invalidateCachedProperty(property)
    }

    // MARK: Internal functions for rare uses

    func invalidateCachedProperties() {
        for cacheKey in cachedProperties.keys {
            invalidateCachedProperty(cacheKey.property)
        }
    }

    func clearMIDIObjectRef() {
        // Called when this object has been removed from CoreMIDI
        // and it should no longer be used.
        midiObjectRef = 0
    }

}
