/*
 Copyright (c) 2005-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public extension String {

    static func abbreviatedByteCount(_ byteCount: Int) -> String {
        guard let bundle = Bundle(identifier: "com.snoize.SnoizeMIDI") else { fatalError() }

        if byteCount == 1 {
            return NSLocalizedString("1 byte", tableName: "SnoizeMIDI", bundle: bundle, comment: "string for 1 byte")
        }
        else if byteCount < 1024 {
            let format = NSLocalizedString("%ld bytes", tableName: "SnoizeMIDI", bundle: bundle, comment: "format for < 1024 bytes")
            return String.localizedStringWithFormat(format, byteCount)
        }
        else {
            let format: String
            var fractionalUnits = Double(byteCount)
            let unitFactor = Double(1024.0)
            fractionalUnits /= unitFactor
            if fractionalUnits < unitFactor {
                format = NSLocalizedString("%0.1lf KB", tableName: "SnoizeMIDI", bundle: bundle, comment: "format for kilobytes")
            }
            else {
                fractionalUnits /= unitFactor
                if fractionalUnits < unitFactor {
                    format = NSLocalizedString("%0.1lf MB", tableName: "SnoizeMIDI", bundle: bundle, comment: "format for megabytes")
                }
                else {
                    fractionalUnits /= unitFactor
                    if fractionalUnits < unitFactor {
                        format = NSLocalizedString("%0.1lf GB", tableName: "SnoizeMIDI", bundle: bundle, comment: "format for gigabytes")
                    }
                    else {
                        fractionalUnits /= unitFactor
                        if fractionalUnits < unitFactor {
                            format = NSLocalizedString("%0.1lf TB", tableName: "SnoizeMIDI", bundle: bundle, comment: "format for terabytes")
                        }
                        else {
                            fractionalUnits /= unitFactor
                            format = NSLocalizedString("%0.1lf PB", tableName: "SnoizeMIDI", bundle: bundle, comment: "format for petabytes")
                        }
                    }
                }
            }

            return String.localizedStringWithFormat(format, fractionalUnits)
        }
    }

}
