/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

class SingleInputStreamSource {

    init(name: String) {
        self.name = name
    }

    var name: String

}

extension SingleInputStreamSource: InputStreamSourceProviding {

    var inputStreamSourceName: String? {
        name
    }

    var inputStreamSourceUniqueID: MIDIUniqueID? {
        nil
    }

    func isEqualTo(_ other: InputStreamSourceProviding) -> Bool {
        guard let otherSingleSource = other as? SingleInputStreamSource else { return false }
        return self === otherSingleSource
    }

    func inputStreamSourceHash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    var asInputStreamSource: InputStreamSource {
        InputStreamSource(provider: self)
    }

}
