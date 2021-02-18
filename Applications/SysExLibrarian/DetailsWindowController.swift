/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa
import SnoizeMIDI

class DetailsWindowController: GeneralWindowController {

    static func showWindow(forEntry entry: LibraryEntry) {
        var controller = controllers.first(where: { $0.entry == entry })
        if controller == nil {
            let newController = DetailsWindowController(entry: entry)
            controllers.append(newController)
            controller = newController
        }

        controller?.showWindow(nil)
    }

    init(entry: LibraryEntry) {
        self.entry = entry
        self.cachedMessages = entry.messages

        super.init(window: nil)
        shouldCascadeWindows = true

        NotificationCenter.default.addObserver(self, selector: #selector(self.entryWillBeRemoved(_:)), name: .libraryEntryWillBeRemoved, object: entry)
        NotificationCenter.default.addObserver(self, selector: #selector(self.entryNameDidChange(_:)), name: .libraryEntryNameDidChange, object: entry)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var windowNibName: NSNib.Name? {
        return "Details"
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        synchronizeTitle()

        messagesTableView.reloadData()
        if cachedMessages.count > 0 {
            messagesTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        synchronizeMessageDataDisplay()
    }

    // MARK: Actions

    @IBAction override func selectAll(_ sender: Any?) {
        // Forward to the text view, even if it isn't the first responder
        textView.selectAll(sender)
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        Self.controllers.removeAll { $0 == self }
    }

    // MARK: Private

    static private var controllers: [DetailsWindowController] = []
    private let entry: LibraryEntry
    private let cachedMessages: [SystemExclusiveMessage]

    @IBOutlet private var messagesTableView: NSTableView!
    @IBOutlet private var textView: NSTextView!

    private func synchronizeMessageDataDisplay() {
        var formatted = ""

        let selectedRow = messagesTableView.selectedRow
        if selectedRow >= 0 {
            let data = cachedMessages[selectedRow].receivedDataWithStartByte
            formatted = data.formattedAsHexDump()
                + "\nMD5 checksum:   \(data.md5HexHash)"
                + "\nSHA-1 checksum: \(data.sha1HexHash)"
        }

        textView.string = formatted
    }

    private func synchronizeTitle() {
        window?.title = entry.name ?? ""
        window?.representedFilename = entry.path ?? ""
    }

    @objc private func entryWillBeRemoved(_ notification: Notification) {
        close()
    }

    @objc private func entryNameDidChange(_ notification: Notification) {
        synchronizeTitle()
    }

}

extension DetailsWindowController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        cachedMessages.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < cachedMessages.count else { return nil }
        let message = cachedMessages[row]

        switch tableColumn?.identifier.rawValue {
        case "index":
            return row + 1
        case "manufacturer":
            return message.manufacturerName
        case "sizeDecimal":
            return MessageFormatter.formatLength(message.receivedDataWithStartByteLength, usingOption: .decimal)
        case "sizeHex":
            return MessageFormatter.formatLength(message.receivedDataWithStartByteLength, usingOption: .hexadecimal)
        case "sizeAbbreviated":
            return String.abbreviatedByteCount(message.receivedDataWithStartByteLength)
        default:
            return nil
        }
    }

}

extension DetailsWindowController: NSTableViewDelegate {

    func tableViewSelectionDidChange(_ notification: Notification) {
        synchronizeMessageDataDisplay()
    }

}

private let minMessagesViewHeight = CGFloat(32.0)
private let minTextViewHeight = CGFloat(32.0)

extension DetailsWindowController: NSSplitViewDelegate {

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        proposedMinimumPosition + minMessagesViewHeight
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        proposedMaximumPosition - minTextViewHeight
    }

    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        splitView.adjustSubviews()

        guard splitView.subviews.count >= 2 else { return }
        let view1 = splitView.subviews[0]
        let view2 = splitView.subviews[1]
        let v1Frame = view1.frame
        let v2Frame = view2.frame
        let dividerThickness = splitView.dividerThickness
        let boundsHeight = splitView.bounds.size.height

        if v1Frame.size.height < minMessagesViewHeight {
            view1.frame = CGRect(x: v1Frame.origin.x,
                                 y: 0,
                                 width: v1Frame.size.width,
                                 height: minMessagesViewHeight
            )
            view2.frame = CGRect(x: v2Frame.origin.x,
                                 y: minMessagesViewHeight + dividerThickness,
                                 width: v2Frame.size.height,
                                 height: boundsHeight - (dividerThickness + minMessagesViewHeight)
            )
        }
        else if v2Frame.size.height < minTextViewHeight {
            view1.frame = CGRect(x: v1Frame.origin.x,
                                 y: 0,
                                 width: v1Frame.size.width,
                                 height: boundsHeight - (dividerThickness + minTextViewHeight)
            )
            view2.frame = CGRect(x: v2Frame.origin.x,
                                 y: boundsHeight - minTextViewHeight,
                                 width: v2Frame.size.height,
                                 height: minTextViewHeight
            )
        }
    }

}
