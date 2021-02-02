//
//  Data+Hashing.swift
//  SysExLibrarian
//
//  Created by Kurt Revis on 1/29/21.
//

import Foundation
import CommonCrypto

// TODO Extend Data not NSData
@objc extension NSData {

    var md5HexHash: String {
        var digest = [UInt8](repeating: 0, count: 16)

        digest.withUnsafeMutableBufferPointer { ( digestBufferPtr: inout UnsafeMutableBufferPointer<UInt8>) -> Void in
            CC_MD5(self.bytes, CC_LONG(self.length), digestBufferPtr.baseAddress)
        }

        var result = ""
        for index in 0 ..< 16 {
            result += String(format: "%02x", digest[index])
        }

        return result
    }

    var sha1HexHash: String {
        var digest = [UInt8](repeating: 0, count: 16)

        digest.withUnsafeMutableBufferPointer { ( digestBufferPtr: inout UnsafeMutableBufferPointer<UInt8>) -> Void in
            CC_SHA1(self.bytes, CC_LONG(self.length), digestBufferPtr.baseAddress)
        }

        var result = ""
        for index in 0 ..< 16 {
            result += String(format: "%02x", digest[index])
        }

        return result
    }

}
