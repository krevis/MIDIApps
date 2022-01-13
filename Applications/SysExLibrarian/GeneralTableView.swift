/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class GeneralTableView: NSTableView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    var shouldEditNextItemWhenEditingEnds = false

    func setSortColumn(_ column: NSTableColumn, isAscending: Bool) {
        for tableColumn in tableColumns {
            var indicatorImage: NSImage?
            if column == tableColumn {
                indicatorImage = isAscending ? Self.tableHeaderSortImage : Self.tableHeaderReverseSortImage
            }

            setIndicatorImage(indicatorImage, in: tableColumn)
        }
    }

    // MARK: NSTableView overrides

    override func textDidEndEditing(_ notification: Notification) {
        if !shouldEditNextItemWhenEditingEnds,
           let userInfo = notification.userInfo,
           let movementNumber = userInfo["NSTextMovement"] as? NSNumber,
           movementNumber.intValue == NSTextMovement.return.rawValue {

            // This is ugly, but just about the only way to do it. NSTableView is determined to select and edit something else, even the text field that it just finished editing, unless we mislead it about what key was pressed to end editing.
            let newUserInfo = NSMutableDictionary(dictionary: userInfo)
            newUserInfo["NSTextMovement"] = NSNumber(value: NSTextMovement.other.rawValue)
            let newNotification = Notification(name: notification.name, object: notification.object, userInfo: newUserInfo as? [AnyHashable: Any])
            super.textDidEndEditing(newNotification)

            // For some reason we lose firstResponder status when when we do the above.
            window?.makeFirstResponder(self)
        }
        else {
            super.textDidEndEditing(notification)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if drawsDraggingHighlight, let scrollView = enclosingScrollView {
            NSColor.selectedControlColor.set()
            scrollView.documentVisibleRect.frame(withWidth: 2.0, using: .copy)
        }
    }

    override func keyDown(with event: NSEvent) {
        // We would like to use interpretKeyEvents(), but then *all* key events would get interpreted into selectors,
        // and NSTableView does not implement the proper selectors (like moveUp: for up arrow). Instead it apparently
        // checks key codes manually in -keyDown. So, we do the same.
        // Key codes are taken from /System/Library/Frameworks/AppKit.framework/Resources/StandardKeyBinding.dict.

        var handled = false

        if let firstCharacter = event.characters?.utf16.first {
            switch firstCharacter {
            case 0x08, 0x7F: // ^H (backspace, BS) or Delete key (DEL)
                deleteBackward(self)
                handled = true
            case 0x04, 0xF728: // // ^D (forward delete emacs keybinding) or keypad delete key (which is  0xEF 0x9C 0xA8 in UTF-8)
                deleteForward(self)
                handled = true
            case 0x20:
                if let delegate = delegate as? GeneralTableViewDelegate {
                    handled = delegate.tableViewKeyDownReceivedSpace(self)
                }
            default:
                break
            }
        }

        if !handled {
            super.keyDown(with: event)
        }
    }

    override func deleteForward(_ sender: Any?) {
        deleteSelectedRows()
    }

    override func deleteBackward(_ sender: Any?) {
        deleteSelectedRows()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        // If we can't do anything useful in response to a selectAll:, then pretend that we don't even respond to it.
        if aSelector == #selector(selectAll(_:)) {
            return allowsMultipleSelection
        }
        else {
            return super.responds(to: aSelector)
        }
    }

    // MARK: Dragging

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let dataSource = dataSource as? GeneralTableViewDataSource {
            draggingOperation = dataSource.tableView(self, draggingEntered: sender)
        }
        else {
            draggingOperation = []
        }

        if draggingOperation != [] {
            drawsDraggingHighlight = true
        }

        return draggingOperation
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggingOperation
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        drawsDraggingHighlight = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let dataSource = dataSource as? GeneralTableViewDataSource {
            return dataSource.tableView(self, performDragOperation: sender)
        }
        else {
            return false
        }
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        drawsDraggingHighlight = false
    }

    // MARK: Private

    private var drawsDraggingHighlight = false {
        didSet {
            needsDisplay = true
        }
    }
    private var draggingOperation: NSDragOperation = []

    private static var tableHeaderSortImage: NSImage? {
        NSImage(named: "NSAscendingSortIndicator")
    }

    private static var tableHeaderReverseSortImage: NSImage? {
        NSImage(named: "NSDescendingSortIndicator")
    }

    private func deleteSelectedRows() {
        if let dataSource = dataSource as? GeneralTableViewDataSource {
            dataSource.tableView(self, deleteRows: selectedRowIndexes)
        }
    }

}

protocol GeneralTableViewDataSource: NSTableViewDataSource {

    func tableView(_ tableView: GeneralTableView, deleteRows: IndexSet)

    func tableView(_ tableView: GeneralTableView, draggingEntered sender: NSDraggingInfo) -> NSDragOperation

    func tableView(_ tableView: GeneralTableView, performDragOperation sender: NSDraggingInfo) -> Bool

}

protocol GeneralTableViewDelegate: NSTableViewDelegate {

    func tableViewKeyDownReceivedSpace(_ tableView: GeneralTableView) -> Bool
    // Return true if delegate handled the space key. Return false if you did nothing and want the table view to handle it.

}
