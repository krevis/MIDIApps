/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

// InputStreamSource is a type-erasing wrapper struct
// that represents one of many possible sources that a
// InputStream could listen to.
//
// Depending on the stream, these could be wrappers
// around Source, Destination, or SingleInputStreamSource.
//
// We represent the selected input sources as
// Set<InputStreamSource>, so InputStreamSource needs to
// be Hashable (and thus Equatable), even if the underlying
// objects aren't.
//
// https://khawerkhaliq.com/blog/swift-protocols-equatable-part-one/
// https://khawerkhaliq.com/blog/swift-protocols-equatable-part-two/

public protocol InputStreamSourceProviding {

    var inputStreamSourceName: String? { get }
    var inputStreamSourceUniqueID: MIDIUniqueID? { get }

    func isEqualTo(_ other: InputStreamSourceProviding) -> Bool
    func inputStreamSourceHash(into hasher: inout Hasher)

    var asInputStreamSource: InputStreamSource { get }

}

public struct InputStreamSource: Hashable {

    init(provider: InputStreamSourceProviding) {
        self.provider = provider
    }

    public let provider: InputStreamSourceProviding

    public var name: String? {
        provider.inputStreamSourceName
    }
    public var uniqueID: MIDIUniqueID? {
        provider.inputStreamSourceUniqueID
    }

    // MARK: Equatable

    public static func == (lhs: InputStreamSource, rhs: InputStreamSource) -> Bool {
        lhs.provider.isEqualTo(rhs.provider)
    }

    // MARK: Hashable

    public func hash(into hasher: inout Hasher) {
        provider.inputStreamSourceHash(into: &hasher)
    }
}
