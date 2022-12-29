/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class ValidatingButton: NSButton, NSValidatedUserInterfaceItem {

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didUpdateNotification, object: nil)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(self.windowDidUpdate(_:)), name: NSWindow.didUpdateNotification, object: window)
        }

        originalKeyEquivalent = keyEquivalent
    }

    // MARK: Private

    private var originalKeyEquivalent = ""

    @objc private func windowDidUpdate(_ notification: Notification) {
        var shouldBeEnabled = false

        if let action,
           let validator = NSApp.target(forAction: action, to: target, from: self) {
            let validatorObject = validator as AnyObject
            if validatorObject.responds(to: action) {
                if validatorObject.responds(to: #selector(validateUserInterfaceItem(_:))) {
                    shouldBeEnabled = validatorObject.validateUserInterfaceItem(self)
                }
                else {
                    shouldBeEnabled = true
                }
            }
        }

        isEnabled = shouldBeEnabled
        keyEquivalent = shouldBeEnabled ? originalKeyEquivalent : ""
    }
}
