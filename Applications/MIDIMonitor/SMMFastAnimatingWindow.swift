//
//  SMMFastAnimatingWindow.swift
//  MIDIMonitor
//
//  Created by Kurt Revis on 12/13/20.
//

import Cocoa

class SMMFastAnimatingWindow: NSWindow {

    private var animationResizeTimeScaleFactor = 0.75

    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval {
        return super.animationResizeTime(newFrame) * animationResizeTimeScaleFactor
    }

}
