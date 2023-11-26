/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

protocol FastAnimatingWindowDelegate: NSWindowDelegate {
    func windowDidSaveFrame(window: FastAnimatingWindow, usingName name: NSWindow.FrameAutosaveName)
}

class FastAnimatingWindow: NSWindow {

    private var animationResizeTimeScaleFactor = 0.75

    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval {
        return super.animationResizeTime(newFrame) * animationResizeTimeScaleFactor
    }

    override func saveFrame(usingName name: NSWindow.FrameAutosaveName) {
        super.saveFrame(usingName: name)
        (delegate as? FastAnimatingWindowDelegate)?.windowDidSaveFrame(window: self, usingName: name)
    }

}
