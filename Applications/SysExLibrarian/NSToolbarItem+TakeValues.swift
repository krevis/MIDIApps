/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

@objc extension NSToolbarItem {

    func takeValues(itemInfo: [String: Any], target: AnyObject?) {
        if let string = itemInfo["label"] as? String {
            self.label = string
        }

        if let string = itemInfo["toolTip"] as? String {
            self.toolTip = string
        }

        if let string = itemInfo["paletteLabel"] as? String {
            self.paletteLabel = string
        }

        self.target = {
            if let string = itemInfo["target"] as? String {
                if string == "FirstResponder" {
                    return nil
                }
                else {
                    let selector = Selector(string)
                    if let nonNilTarget = target, nonNilTarget.responds(to: selector) {
                        return nonNilTarget.perform(selector)?.takeUnretainedValue()
                    }
                    else {
                        return nil
                    }
                }
            }

            return target   // default if not otherwise specified
        }()

        if let string = itemInfo["action"] as? String {
            self.action = Selector(string)
        }

        if let string = itemInfo["imageName"] as? String {
            self.image = NSImage(named: string)
        }
    }

}
