/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class DisclosureButton: NSButton {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        image = NSImage(named: "DisclosureArrowRight")
        alternateImage = NSImage(named: "DisclosureArrowDown")

        if let buttonCell = cell as? NSButtonCell {
            buttonCell.highlightsBy = .pushInCellMask
        }
    }

}
