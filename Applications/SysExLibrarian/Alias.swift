/*
 Copyright (c) 2018-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

struct Alias {

    init(data: Data) {
        bookmarkData = data
    }

    init?(aliasRecordData: Data) {
        if let cfBookmarkData = CFURLCreateBookmarkDataFromAliasRecord(kCFAllocatorDefault, aliasRecordData as CFData) {
            self.init(data: cfBookmarkData.takeRetainedValue() as Data)
        }
        else {
            return nil
        }
    }

    init?(path: String) {
        do {
            let url = URL(fileURLWithPath: path)
            let bookmarkData = try url.bookmarkData()
            self.init(data: bookmarkData)
        }
        catch {
            return nil
        }
    }

    var data: Data {
        bookmarkData
    }

    mutating func path() -> String? {
        path(allowingMountingUI: true)
    }

    mutating func path(allowingMountingUI: Bool) -> String? {
        do {
            let options: URL.BookmarkResolutionOptions = allowingMountingUI ? [] : [.withoutUI, .withoutMounting]
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: options, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if url.isFileURL {
                if isStale {
                    // Try to replace stale data with fresh data
                    do {
                        bookmarkData = try url.bookmarkData()
                    }
                    catch {
                    }
                }

                return url.path
            }
        }
        catch {
            // no URL could be resolved from the bookmarkData
        }

        return nil
    }

    // MARK: Private

    private var bookmarkData: Data

}
