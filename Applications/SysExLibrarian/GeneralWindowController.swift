/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class GeneralWindowController: NSWindowController {

    override init(window: NSWindow?) {
        super.init(window: window)

        windowFrameAutosaveName = self.windowNibName ?? ""
        shouldCascadeWindows = false

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(willUndoOrRedo(_:)), name: .NSUndoManagerWillUndoChange, object: undoManager)
        center.addObserver(self, selector: #selector(willUndoOrRedo(_:)), name: .NSUndoManagerWillRedoChange, object: undoManager)
        center.addObserver(self, selector: #selector(didUndoOrRedo(_:)), name: .NSUndoManagerDidUndoChange, object: undoManager)
        center.addObserver(self, selector: #selector(didUndoOrRedo(_:)), name: .NSUndoManagerDidRedoChange, object: undoManager)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        undoManager?.removeAllActions(withTarget: self)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        if let nibName = windowNibName {
            window?.setFrameAutosaveName(nibName)
        }
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Make sure that we are the window's delegate (it might not have been set in the nib)
        window?.delegate = self
    }

    // Window utility methods

    func finishEditingInWindow() {
        guard let window else { return }
        if window.makeFirstResponder(firstResponderWhenNotEditing) {
            // Validation turned out OK
        }
        else {
            // Validation of the field didn't work, but we need to end editing NOW regardless
            window.endEditing(for: nil)
        }
    }

    var firstResponderWhenNotEditing: NSResponder? {
        window
    }

    // Undo-related

    override var undoManager: UndoManager? {
        // Override NSResponder method
        privateUndoManager
    }

    @objc func willUndoOrRedo(_ notification: Notification) {
        // If we're going to undo, anything can happen, and we really need to stop editing first
        finishEditingInWindow()

        // More can be done by subclasses
    }

    @objc func didUndoOrRedo(_ notification: Notification) {
        // Can be overridden by subclasses if they want to.
        // You definitely want to resynchronize your UI here. Just about anything could have happened.
    }

    // MARK: Private

    let privateUndoManager = UndoManager()

}

extension GeneralWindowController: NSUserInterfaceValidations {

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        // Override in subclasses as necessary
        true
    }

}

extension GeneralWindowController: NSWindowDelegate {

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        // Make sure our undo manager gets used, not the window's default one.
        privateUndoManager
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        finishEditingInWindow()

        // It is possible that something caused by -finishEditingInWindow has caused a sheet to open; we shouldn't close the window in that case, because it really confuses the app (and makes it impossible to quit).
        // (Also: As of 10.1.3, we can get here if someone option-clicks on the close button of a different window, even if this window has a sheet up at the time.)
        if window?.attachedSheet != nil {
            return false
        }

        return true
    }

    func windowDidResize(_ notification: Notification) {
        autosaveCurrentWindowFrame()
    }

    func windowDidMove(_ notification: Notification) {
        autosaveCurrentWindowFrame()
    }

}

extension GeneralWindowController /* Private */ {

    // Window stuff

    private func autosaveCurrentWindowFrame() {
        // Work around an AppKit bug: the frame that gets saved in NSUserDefaults is the window's old position, not the new one.
        // We get notified after the window has been moved/resized and the defaults changed.
        if let window {
            window.saveFrame(usingName: window.frameAutosaveName)
        }
    }

}
