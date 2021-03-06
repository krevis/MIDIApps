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

// Infrastructure to cache CoreMIDI property values inside MIDIObject.
//
// Create a TypedCache<type> with getter and setter closures.
// Then access the value through cachedProperty.value. It will call the
// getter only once, returning the same value on subsequent gets,
// until invalidate() is called or a value is set.
//
// (When the value is set, we can't assume anything about what the setter
// actually did, so we simply invalidate the cache and read it again next time.)
//
// MIDIObject uses this to make a cache for several CoreMIDI properties,
// automatically invalidating them when CoreMIDI says the property has changed.

// A type-erased protocol and struct, so we can add multiple TypedCache structs,
// parameterized with different types, into the same collection.

protocol Cache {
    mutating func invalidate()
}

struct AnyCache {
    var base: Cache
}

// The actual cache.  Use asAnyCache to get the type-erased wrapper.

struct TypedCache<T: Equatable>: Cache {

    init(getter: @escaping () -> T?, setter: @escaping (T?) -> Void) {
        self.getter = getter
        self.setter = setter
    }

    private let getter: () -> T?
    private let setter: (T?) -> Void

    private var cachedValue: T??

    var value: T? {
        mutating get {
            if let value = cachedValue {
                return value
            }
            else {
                let value = getter()
                cachedValue = .some(value)
                return value
            }
        }
        set {
            if cachedValue != .some(newValue) {
                setter(newValue)
                cachedValue = .none
            }
        }
    }

    mutating func invalidate() {
        cachedValue = .none
    }

    var asAnyCache: AnyCache {
        AnyCache(base: self)
    }

}

// A function to get from a type-erased AnyCache to a TypedCache<T>,
// potentially modifying both in place.

extension AnyCache {

    mutating func withTypedCache<T: Equatable, Result>(_ perform: ((inout TypedCache<T>) -> Result)) -> Result {
        guard var typedCache = base as? TypedCache<T> else { fatalError("Cache is wrong type") }

        let result = perform(&typedCache)

        // We may have just modified a copy of the value in base, so write it back
        base = typedCache

        return result
    }

}
