/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

extension Data {

    public func formattedAsHexDump() -> String {
        let dataLength = self.count
        if dataLength <= 0 {
            return ""
        }

        // How many hex digits are required to represent self.count?
        var lengthDigitCount = 0
        var scratchLength = dataLength
        while scratchLength > 0 {
            lengthDigitCount += 2
            scratchLength >>= 8
        }

        var formattedString = ""

        // Format the data in 16 byte lines like this:
        // <variable length index> 00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  |0123456789ABCDEF|
        // and ending in \n

        let lineLength = lengthDigitCount + 3 * 8 + 1 + 3 * 8 + 2 + 1 + 16 + 1 + 1
        formattedString.reserveCapacity((dataLength / 16) * lineLength)

        let hexChars: [Character] = [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" ]

        for dataIndex in stride(from: self.startIndex, to: self.endIndex, by: 16) {
            formattedString += String(format: "%.*lX", lengthDigitCount, dataIndex)

            for index in dataIndex ..< (dataIndex+16) {
                formattedString += " "
                if index % 8 == 0 {
                    formattedString += " "
                }

                if index < self.endIndex {
                    let byte = self[index]
                    formattedString.append(hexChars[(Int(byte) & 0xF0) >> 4])
                    formattedString.append(hexChars[(Int(byte) & 0x0F)     ])
                }
                else {
                    formattedString += "  "
                }
            }

            formattedString += "  |"

            for index in dataIndex ..< Swift.min(dataIndex+16, self.endIndex) {
                let byte = self[index]
                if isprint(Int32(byte)) != 0 {
                    formattedString.append(Character(Unicode.Scalar(byte)))
                }
                else {
                    formattedString += " "
                }
            }

            formattedString += "|\n"
        }

        return formattedString
    }

}
