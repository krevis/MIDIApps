/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import CommonCrypto

extension Data {

    var md5HexHash: String {
        let digestLength = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: digestLength)

        withUnsafeBytes { (selfBufferPtr: UnsafeRawBufferPointer) -> Void in
            digest.withUnsafeMutableBufferPointer { ( digestBufferPtr: inout UnsafeMutableBufferPointer<UInt8>) -> Void in
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

}
