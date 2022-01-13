/*
 Copyright (c) 2006-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class SysExSpeedOutlineView: NSOutlineView {

    override func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
        // Do nothing.  We don't want a selection.
        // (But we do need to be able to track the slider cells in the table. That's why
        //  we can't just use the NSOutlineView delegate methods to reject any selection --
        //  if we do, then tracking doesn't work.)

        // Even though we do this, cells will still highlight if you click on them.
        // NonHighlightingTextFieldCell fixes that.
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
