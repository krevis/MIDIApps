/*
 Copyright (c) 2006-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

extension FileManager {

    func uniqueFilename(from originalPath: String) -> String {
        let originalPathAsNSString = NSString(string: originalPath)
        let originalPathWithoutExtension = originalPathAsNSString.deletingPathExtension
        let originalPathExtension = originalPathAsNSString.pathExtension

        var testPath = originalPath
        var suffix = 0

        while fileExists(atPath: testPath) {
            suffix += 1
            let suffixedPath = originalPathWithoutExtension.appending("-\(suffix)")
            if let suffixedExtensionedPath = NSString(string: suffixedPath).appendingPathExtension(originalPathExtension) {
                testPath = suffixedExtensionedPath
            }
            else {
                // Something went wrong appending the extension. Weird.
                // Give up and return the original path; using it will cause an error.
                return originalPath
            }
        }

        return testPath
    }

}
