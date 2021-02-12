/*
 Copyright (c) 2018-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

// TODO This probably could be a struct.

@objc class Alias: NSObject {

    @objc init(data: Data) {
        bookmarkData = data
        super.init()
    }

    @objc convenience init?(aliasRecordData: Data) {
        if let cfBookmarkData = CFURLCreateBookmarkDataFromAliasRecord(kCFAllocatorDefault, aliasRecordData as CFData) {
            self.init(data: cfBookmarkData.takeRetainedValue() as Data)
        }
        else {
            return nil
        }
    }

    @objc convenience init?(path: String) {
        do {
            let url = URL(fileURLWithPath: path)
            let bookmarkData = try url.bookmarkData()
            self.init(data: bookmarkData)
        }
        catch {
            return nil
        }
    }

    @objc var data: Data {
        bookmarkData
    }

    @objc var path: String? {
        path(allowingUI: true)
    }

    @objc func path(allowingUI: Bool) -> String? {
        do {
            let options: URL.BookmarkResolutionOptions = allowingUI ? [] : .withoutUI
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
