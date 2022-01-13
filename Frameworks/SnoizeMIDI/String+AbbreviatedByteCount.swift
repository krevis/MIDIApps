/*
 Copyright (c) 2005-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

public extension String {

    static func abbreviatedByteCount(_ byteCount: Int) -> String {
        if byteCount == 1 {
            return NSLocalizedString("1 byte", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "string for 1 byte")
        }
        else if byteCount < 1024 {
            let format = NSLocalizedString("%ld bytes", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "format for < 1024 bytes")
            return String.localizedStringWithFormat(format, byteCount)
        }
        else {
            let format: String
            var fractionalUnits = Double(byteCount)
            let unitFactor = Double(1024.0)
            fractionalUnits /= unitFactor
            if fractionalUnits < unitFactor {
                format = NSLocalizedString("%0.1lf KB", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "format for kilobytes")
            }
            else {
                fractionalUnits /= unitFactor
                if fractionalUnits < unitFactor {
                    format = NSLocalizedString("%0.1lf MB", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "format for megabytes")
                }
                else {
                    fractionalUnits /= unitFactor
                    if fractionalUnits < unitFactor {
                        format = NSLocalizedString("%0.1lf GB", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "format for gigabytes")
                    }
                    else {
                        fractionalUnits /= unitFactor
                        if fractionalUnits < unitFactor {
                            format = NSLocalizedString("%0.1lf TB", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "format for terabytes")
                        }
                        else {
                            fractionalUnits /= unitFactor
                            format = NSLocalizedString("%0.1lf PB", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "format for petabytes")
                        }
                    }
                }
            }

            return String.localizedStringWithFormat(format, fractionalUnits)
        }
    }

}
