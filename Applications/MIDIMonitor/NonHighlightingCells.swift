/*
 Copyright (c) 2001-2022, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class NonHighlightingButtonCell: NSButtonCell {

    override func highlightColor(withFrame cellFrame: NSRect, in controlView: NSView) -> NSColor? {
        guard let tableView = controlView as? NSTableView else { return super.highlightColor(withFrame: cellFrame, in: controlView) }
        return tableView.backgroundColor
    }

}

class NonHighlightingTextFieldCell: NSTextFieldCell {

    override func highlightColor(withFrame cellFrame: NSRect, in controlView: NSView) -> NSColor? {
        guard let tableView = controlView as? NSTableView else { return super.highlightColor(withFrame: cellFrame, in: controlView) }
        return tableView.backgroundColor
    }

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        return .light
        // == the background is a light color, and content drawn over it (the text) should be dark
    }

}
