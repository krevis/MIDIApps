/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class FastAnimatingWindow: NSWindow {

    private var animationResizeTimeScaleFactor = 0.75

    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval {
        return super.animationResizeTime(newFrame) * animationResizeTimeScaleFactor
    }

}
