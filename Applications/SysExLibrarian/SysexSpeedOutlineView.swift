/*
 Copyright (c) 2006-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

class SysexSpeedOutlineView: NSOutlineView {

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
