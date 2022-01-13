/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

extension Data {

    var lowercaseHexString: String {
        // If the bytes in order are 00 01 02 03 04 05 06 07,
        // format like "0001020304050607".

        let dataLength = count
        if dataLength <= 0 {
            return ""
        }

        var formattedString = ""
        formattedString.reserveCapacity(dataLength * 2)

        let hexChars: [Character] = [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f" ]

        for byte in self {
            formattedString.append(hexChars[(Int(byte) & 0xF0) >> 4])
            formattedString.append(hexChars[(Int(byte) & 0x0F)     ])
        }

        return formattedString
    }

}
