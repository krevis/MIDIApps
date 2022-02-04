/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

extension Endpoint: InputStreamSourceProviding {

    public var inputStreamSourceName: String? {
        displayName
    }

    public var inputStreamSourceUniqueID: MIDIUniqueID? {
        uniqueID
    }

    public func isEqualTo(_ other: InputStreamSourceProviding) -> Bool {
        guard let otherEndpoint = other as? Endpoint else { return false }
        // NOTE: Here be dragons. It's possible that succeded
        // if self is Source and other is Destination,
        // which isn't sensible.
        // However, we should never have a Source and a Destination
        // with the same underlying MIDIEndpointRef,
        // so we can get away without checking for that.
        return endpointRef == otherEndpoint.endpointRef
    }

    public func inputStreamSourceHash(into hasher: inout Hasher) {
        hasher.combine(endpointRef)
    }

    public var asInputStreamSource: InputStreamSource {
        InputStreamSource(provider: self)
    }

}
