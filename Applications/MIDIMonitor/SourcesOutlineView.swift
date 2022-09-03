/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class SourcesOutlineView: NSOutlineView {

    override func mouseDown(with event: NSEvent) {
        // Ignore all double-clicks (and triple-clicks and so on) by pretending they are single-clicks.
        var modifiedEvent: NSEvent?
        if event.clickCount > 1 {
            modifiedEvent = NSEvent.mouseEvent(with: event.type, location: event.locationInWindow, modifierFlags: event.modifierFlags, timestamp: event.timestamp, windowNumber: event.windowNumber, context: nil, eventNumber: event.eventNumber, clickCount: 1, pressure: event.pressure)
        }

        super.mouseDown(with: modifiedEvent ?? event)
    }

}
