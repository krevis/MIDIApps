/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

    public func asInputStreamSource() -> InputStreamSource {
        InputStreamSource(provider: self)
    }

}
