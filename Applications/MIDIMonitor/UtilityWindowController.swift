/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class UtilityWindowController: NSWindowController {

    override init(window: NSWindow?) {
        super.init(window: window)
        shouldCascadeWindows = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        shouldCascadeWindows = false
    }

}
