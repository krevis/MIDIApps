/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import CommonCrypto

extension Data {

    // swiftlint:disable redundant_void_return
    // (Yes, I can remove the four instances of `-> Void` below, but then that produces a real warning.
    //  SwiftLint is being overly sensitive.)

    var md5HexHash: String {
        let digestLength = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: digestLength)

        withUnsafeBytes { (selfBufferPtr: UnsafeRawBufferPointer) -> Void in
            digest.withUnsafeMutableBufferPointer { ( digestBufferPtr: inout UnsafeMutableBufferPointer<UInt8>) -> Void in
                // Note: This generates a warning about MD5 being deprecated because it's cryptographically broken.
                // We aren't using it for cryptography, though.
                // Sadly, there is STILL no way to silence deprecation warnings in Swift:
                // https://forums.swift.org/t/swift-should-allow-for-suppression-of-warnings-especially-those-that-come-from-objective-c/19216/72
                CC_MD5(selfBufferPtr.baseAddress, CC_LONG(self.count), digestBufferPtr.baseAddress)
            }
        }

        var result = ""
        for index in 0 ..< digestLength {
            result += String(format: "%02x", digest[index])
        }

        return result
    }

    var sha1HexHash: String {
        let digestLength = Int(CC_SHA1_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: digestLength)

        withUnsafeBytes { (selfBufferPtr: UnsafeRawBufferPointer) -> Void in
            digest.withUnsafeMutableBufferPointer { ( digestBufferPtr: inout UnsafeMutableBufferPointer<UInt8>) -> Void in
                CC_SHA1(selfBufferPtr.baseAddress, CC_LONG(self.count), digestBufferPtr.baseAddress)
            }
        }

        var result = ""
        for index in 0 ..< digestLength {
            result += String(format: "%02x", digest[index])
        }

        return result
    }

    // swiftlint:enable redundant_void_return

}
