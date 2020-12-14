//
//  SMMNonHighlightingCells.swift
//  MIDIMonitor
//
//  Created by Kurt Revis on 12/13/20.
//

import Cocoa

class SMMNonHighlightingButtonCell: NSButtonCell {

    override func highlightColor(withFrame cellFrame: NSRect, in controlView: NSView) -> NSColor? {
        guard let tableView = controlView as? NSTableView else { return super.highlightColor(withFrame: cellFrame, in: controlView) }
        return tableView.backgroundColor
    }

}

class SMMNonHighlightingTextFieldCell: NSTextFieldCell {

    override func highlightColor(withFrame cellFrame: NSRect, in controlView: NSView) -> NSColor? {
        guard let tableView = controlView as? NSTableView else { return super.highlightColor(withFrame: cellFrame, in: controlView) }
        return tableView.backgroundColor
    }

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        return .light
        // == the background is a light color, and content drawn over it (the text) should be dark
    }

}
