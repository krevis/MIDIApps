/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
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
