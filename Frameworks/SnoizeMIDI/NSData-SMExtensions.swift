//
//  NSData-SMExtensions.swift
//  SnoizeMIDI
//
//  Created by Kurt Revis on 12/28/20.
//

import Foundation

@objc extension NSData {

    public var lowercaseHexString: String {     // TODO Doesn't need to be @objc or public, only used in SMMessage
        // If the bytes in order are 00 01 02 03 04 05 06 07,
        // format like "0001020304050607".

        let dataLength = count
        if dataLength <= 0 {
            return ""
        }

        var formattedString = ""
        formattedString.reserveCapacity(dataLength * 2)

        for dataIndex in 0 ..< dataLength {
            let hexChars: [Character] = [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f" ]

            let byte = self[dataIndex]
            formattedString.append(hexChars[(Int(byte) & 0xF0) >> 4])
            formattedString.append(hexChars[(Int(byte) & 0x0F)     ])
        }

        return formattedString
    }

}
